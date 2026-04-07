#!/usr/bin/env python3
"""
Hermeer Decrypt Daemon — encryption/decryption for the HermeerSync pipeline.

Watches iCloud HermeerSync/ for .hermeer.enc files, decrypts to ~/.hermeer-local/.
Watches ~/.hermeer-local/depth/ for new .md files, encrypts back to iCloud.
Handles plaintext .md files written directly to iCloud — encrypts in place
and copies plaintext to local mirror.

File format (.hermeer.enc):
  Bytes 0-7:    Magic "HERMEER1"
  Bytes 8-39:   Salt (32 bytes)
  Bytes 40-51:  Nonce (12 bytes)
  Bytes 52..N:  Ciphertext
  Last 16:      AES-GCM auth tag

Key derivation: PBKDF2-SHA256, 600,000 iterations, 32-byte output.

Passphrase storage: macOS Keychain (service: com.hermeerapp.encryption,
account: hermeer-passphrase).

Usage:
  # First time — save passphrase to Keychain:
  python3 hermeer-decrypt-daemon.py --passphrase 'YOUR_PASS' --save-to-keychain

  # Normal run — reads passphrase from Keychain:
  python3 hermeer-decrypt-daemon.py

  # Health check (for daemon-health.sh):
  python3 hermeer-decrypt-daemon.py --check

  # Manual passphrase without saving:
  python3 hermeer-decrypt-daemon.py --passphrase 'YOUR_PASS'
"""

import sys
import os
import signal
import argparse
import subprocess
import logging
import time
import tempfile
from pathlib import Path
from datetime import datetime
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# ── Constants ─────────────────────────────────────────────────────────────────

MAGIC = b"HERMEER1"
SALT_LEN = 32
NONCE_LEN = 12
TAG_LEN = 16
HEADER_LEN = len(MAGIC) + SALT_LEN + NONCE_LEN  # 52
PBKDF2_ITERATIONS = 600_000

KEYCHAIN_SERVICE = "com.hermeerapp.encryption"
KEYCHAIN_ACCOUNT = "hermeer-passphrase"

ICLOUD_DIR = (
    Path.home()
    / "Library"
    / "Mobile Documents"
    / "com~apple~CloudDocs"
    / "HermeerSync"
)
LOCAL_DIR = Path.home() / ".hermeer-local"
LOG_FILE = LOCAL_DIR / "logs" / "decrypt-daemon.log"

# ── Logging ───────────────────────────────────────────────────────────────────

LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

logger = logging.getLogger("hermeer-decrypt")
logger.setLevel(logging.DEBUG)

file_handler = logging.FileHandler(LOG_FILE)
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(
    logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
)
logger.addHandler(file_handler)

# Console handler only when running interactively (not under launchd)
# The plist's StandardOutPath redirects stdout to the same log file,
# so adding a StreamHandler would duplicate every line.
if sys.stdout.isatty():
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    )
    logger.addHandler(console_handler)

# ── Keychain ──────────────────────────────────────────────────────────────────


def read_keychain() -> str:
    """Read passphrase from macOS Keychain. Raises RuntimeError on failure."""
    try:
        result = subprocess.run(
            [
                "security", "find-generic-password",
                "-s", KEYCHAIN_SERVICE,
                "-a", KEYCHAIN_ACCOUNT,
                "-w",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"Keychain read failed (rc={result.returncode}): "
                f"{result.stderr.strip()}"
            )
        return result.stdout.strip()
    except FileNotFoundError:
        raise RuntimeError("'security' CLI not found — not running on macOS?")


def save_keychain(passphrase: str) -> None:
    """Save passphrase to macOS Keychain. Overwrites if already present."""
    # Delete existing entry (ignore errors if not present)
    subprocess.run(
        [
            "security", "delete-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT,
        ],
        capture_output=True,
        timeout=10,
    )
    result = subprocess.run(
        [
            "security", "add-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT,
            "-w", passphrase,
        ],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Keychain save failed (rc={result.returncode}): "
            f"{result.stderr.strip()}"
        )


# ── Crypto ────────────────────────────────────────────────────────────────────


def derive_key(passphrase: str, salt: bytes) -> bytes:
    """Derive a 256-bit AES key from passphrase + salt using PBKDF2-SHA256."""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=PBKDF2_ITERATIONS,
    )
    return kdf.derive(passphrase.encode("utf-8"))


def encrypt(plaintext: bytes, passphrase: str) -> bytes:
    """
    Encrypt plaintext → HERMEER1 binary format.

    Returns the full .hermeer.enc file contents.
    """
    salt = os.urandom(SALT_LEN)
    nonce = os.urandom(NONCE_LEN)
    key = derive_key(passphrase, salt)
    aesgcm = AESGCM(key)
    # AESGCM.encrypt returns ciphertext + tag concatenated
    ct_and_tag = aesgcm.encrypt(nonce, plaintext, None)
    return MAGIC + salt + nonce + ct_and_tag


def decrypt(data: bytes, passphrase: str) -> bytes:
    """
    Decrypt HERMEER1 binary format → plaintext.

    Raises ValueError on bad magic or authentication failure.
    """
    if len(data) < HEADER_LEN + TAG_LEN:
        raise ValueError(f"File too short ({len(data)} bytes)")
    if data[:8] != MAGIC:
        raise ValueError(f"Bad magic: {data[:8]!r} (expected {MAGIC!r})")

    salt = data[8:40]
    nonce = data[40:52]
    ct_and_tag = data[52:]  # ciphertext + 16-byte tag

    key = derive_key(passphrase, salt)
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ct_and_tag, None)


# ── File helpers ──────────────────────────────────────────────────────────────


def enc_to_md_name(name: str) -> str:
    """Convert 'foo.hermeer.enc' → 'foo.md'."""
    if name.endswith(".hermeer.enc"):
        return name[: -len(".hermeer.enc")] + ".md"
    return name


def md_to_enc_name(name: str) -> str:
    """Convert 'foo.md' → 'foo.hermeer.enc'."""
    if name.endswith(".md"):
        return name[: -len(".md")] + ".hermeer.enc"
    return name


def relative_path(filepath: Path, base: Path) -> Path:
    """Return the relative path of filepath under base."""
    return filepath.relative_to(base)


def write_atomic(dest: Path, data: bytes, *, match_mtime: Optional[float] = None) -> None:
    """Write data to dest atomically via temp file + rename.

    If match_mtime is provided, set the destination's mtime to that value
    after writing. This prevents feedback loops where the poll sees the
    newly-written file as 'newer' and re-syncs in the opposite direction.
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=dest.parent, suffix=".tmp")
    try:
        os.write(fd, data)
        os.close(fd)
        fd = -1  # Mark as closed
        os.rename(tmp, dest)
        if match_mtime is not None:
            os.utime(dest, (match_mtime, match_mtime))
    except Exception:
        if fd >= 0:
            try:
                os.close(fd)
            except OSError:
                pass
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


# ── Watchers ──────────────────────────────────────────────────────────────────

# Track files we just wrote to prevent feedback loops
_recently_written: set[str] = set()


class ICloudHandler(FileSystemEventHandler):
    """
    Watches iCloud HermeerSync/ for:
    - .hermeer.enc files → decrypt to local mirror
    - .md files → encrypt in place, copy plaintext to local mirror
    """

    def __init__(self, passphrase: str):
        super().__init__()
        self.passphrase = passphrase

    def on_created(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def on_modified(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def _handle(self, filepath_str: str):
        filepath = Path(filepath_str)

        # Skip temp files, hidden files, .icloud placeholders
        if filepath.name.startswith(".") or filepath.name.endswith(".tmp"):
            return

        # Skip files we just wrote (feedback loop prevention)
        abs_str = str(filepath.resolve())
        if abs_str in _recently_written:
            _recently_written.discard(abs_str)
            return

        try:
            if filepath.suffix == ".enc" and filepath.name.endswith(".hermeer.enc"):
                self._handle_enc(filepath)
            elif filepath.suffix == ".md":
                self._handle_plaintext_md(filepath)
        except Exception as e:
            logger.error(f"Error handling {filepath}: {e}")

    def _handle_enc(self, filepath: Path):
        """Decrypt .hermeer.enc → local mirror as .md."""
        try:
            rel = relative_path(filepath, ICLOUD_DIR)
        except ValueError:
            return

        data = filepath.read_bytes()
        try:
            plaintext = decrypt(data, self.passphrase)
        except Exception as e:
            logger.error(f"Decrypt failed for {rel}: {e}")
            return

        # Write plaintext to local mirror
        local_name = enc_to_md_name(rel.name)
        local_path = LOCAL_DIR / rel.parent / local_name
        _recently_written.add(str(local_path.resolve()))
        write_atomic(local_path, plaintext)
        logger.info(f"Decrypted: {rel} → {local_path.relative_to(LOCAL_DIR)}")

    def _handle_plaintext_md(self, filepath: Path):
        """
        Plaintext .md in iCloud — encrypt in place and copy plaintext
        to local mirror.
        """
        try:
            rel = relative_path(filepath, ICLOUD_DIR)
        except ValueError:
            return

        # Skip state/ and bridge/ — those stay plaintext
        top_dir = rel.parts[0] if len(rel.parts) > 1 else ""
        if top_dir in ("state", "bridge"):
            return

        plaintext = filepath.read_bytes()
        if len(plaintext) == 0:
            return

        # Copy plaintext to local mirror
        local_path = LOCAL_DIR / rel
        _recently_written.add(str(local_path.resolve()))
        write_atomic(local_path, plaintext)

        # Encrypt in place in iCloud
        enc_data = encrypt(plaintext, self.passphrase)
        enc_name = md_to_enc_name(filepath.name)
        enc_path = filepath.parent / enc_name
        _recently_written.add(str(enc_path.resolve()))
        write_atomic(enc_path, enc_data)

        # Remove the original plaintext from iCloud
        try:
            filepath.unlink()
        except OSError as e:
            logger.warning(f"Could not remove plaintext {rel}: {e}")

        logger.info(
            f"Encrypted in-place: {rel} → {enc_name} "
            f"(plaintext → {local_path.relative_to(LOCAL_DIR)})"
        )


class LocalDepthHandler(FileSystemEventHandler):
    """
    Watches ~/.hermeer-local/depth/ for new .md files written by
    depth commands. Encrypts and writes to iCloud.
    """

    def __init__(self, passphrase: str):
        super().__init__()
        self.passphrase = passphrase

    def on_created(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def on_modified(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def _handle(self, filepath_str: str):
        filepath = Path(filepath_str)

        if filepath.name.startswith(".") or filepath.name.endswith(".tmp"):
            return
        if filepath.suffix != ".md":
            return

        abs_str = str(filepath.resolve())
        if abs_str in _recently_written:
            _recently_written.discard(abs_str)
            return

        try:
            rel = relative_path(filepath, LOCAL_DIR)
        except ValueError:
            return

        try:
            plaintext = filepath.read_bytes()
            if len(plaintext) == 0:
                return

            enc_data = encrypt(plaintext, self.passphrase)
            enc_name = md_to_enc_name(rel.name)
            icloud_path = ICLOUD_DIR / rel.parent / enc_name
            _recently_written.add(str(icloud_path.resolve()))
            write_atomic(icloud_path, enc_data)
            logger.info(
                f"Encrypted depth file: {rel} → "
                f"{icloud_path.relative_to(ICLOUD_DIR)}"
            )
        except Exception as e:
            logger.error(f"Error encrypting {filepath}: {e}")


# ── Health check ──────────────────────────────────────────────────────────────


def run_check(passphrase: str) -> bool:
    """
    Verify that the daemon can:
    1. Read passphrase from Keychain (or use provided one)
    2. Access both directories
    3. Round-trip encrypt/decrypt a test payload
    """
    ok = True

    # 1. Passphrase
    print(f"Passphrase: {'available' if passphrase else 'MISSING'}")
    if not passphrase:
        ok = False

    # 2. Directories
    for label, path in [("iCloud", ICLOUD_DIR), ("Local", LOCAL_DIR)]:
        exists = path.is_dir()
        print(f"{label} dir ({path}): {'OK' if exists else 'MISSING'}")
        if not exists:
            ok = False

    # 3. Round-trip
    if passphrase:
        test_payload = b"Hermeer encryption test payload. If you can read this, decryption works."
        try:
            enc = encrypt(test_payload, passphrase)
            dec = decrypt(enc, passphrase)
            match = dec == test_payload
            print(f"Encrypt/decrypt round-trip: {'OK' if match else 'MISMATCH'}")
            if not match:
                ok = False
        except Exception as e:
            print(f"Encrypt/decrypt round-trip: FAILED ({e})")
            ok = False

        # Verify file format structure
        try:
            assert enc[:8] == MAGIC, "Bad magic"
            assert len(enc) == HEADER_LEN + len(test_payload) + TAG_LEN, "Bad length"
            print(f"File format verification: OK ({len(enc)} bytes)")
        except Exception as e:
            print(f"File format verification: FAILED ({e})")
            ok = False

    # 4. Log file
    log_writable = os.access(LOG_FILE.parent, os.W_OK)
    print(f"Log directory writable: {'OK' if log_writable else 'NO'}")
    if not log_writable:
        ok = False

    print(f"\nOverall: {'PASS' if ok else 'FAIL'}")
    return ok


# ── Initial sync ─────────────────────────────────────────────────────────────


def initial_sync(passphrase: str) -> None:
    """
    On startup, walk iCloud dir and:
    - Decrypt any .hermeer.enc files that are newer than their local mirror
    - Copy any plaintext .md files that are missing or older locally
    This ensures ~/.hermeer-local/ is a complete mirror regardless of
    whether entries were created before or after encryption was enabled.
    """
    if not ICLOUD_DIR.is_dir():
        logger.warning(f"iCloud dir not found: {ICLOUD_DIR}")
        return

    count = 0

    # Decrypt .hermeer.enc files
    for enc_file in ICLOUD_DIR.rglob("*.hermeer.enc"):
        try:
            rel = relative_path(enc_file, ICLOUD_DIR)
        except ValueError:
            continue

        enc_mtime = enc_file.stat().st_mtime
        local_name = enc_to_md_name(rel.name)
        local_path = LOCAL_DIR / rel.parent / local_name

        if local_path.exists():
            if local_path.stat().st_mtime >= enc_mtime:
                continue

        try:
            data = enc_file.read_bytes()
            plaintext = decrypt(data, passphrase)
            write_atomic(local_path, plaintext, match_mtime=enc_mtime)
            count += 1
        except Exception as e:
            logger.error(f"Initial sync decrypt failed for {rel}: {e}")

    # Copy plaintext .md files (pre-encryption entries)
    skip_dirs = {"bridge", "HermeerSync"}
    for md_file in ICLOUD_DIR.rglob("*.md"):
        try:
            rel = relative_path(md_file, ICLOUD_DIR)
        except ValueError:
            continue

        # Skip directories we don't need to mirror
        if rel.parts and rel.parts[0] in skip_dirs:
            continue

        md_mtime = md_file.stat().st_mtime
        local_path = LOCAL_DIR / rel

        if local_path.exists():
            if local_path.stat().st_mtime >= md_mtime:
                continue

        try:
            data = md_file.read_bytes()
            write_atomic(local_path, data, match_mtime=md_mtime)
            count += 1
        except Exception as e:
            logger.error(f"Initial sync copy failed for {rel}: {e}")

    if count:
        logger.info(f"Initial sync: synced {count} files")
    else:
        logger.info("Initial sync: all files up to date")


# ── Main ──────────────────────────────────────────────────────────────────────


def poll_for_missed_files(passphrase: str) -> None:
    """
    Periodic fallback for FSEvents misses over iCloud.
    Scans for .hermeer.enc files in iCloud that are newer than their local mirror.
    Also checks local depth/ for .md files not yet encrypted to iCloud.
    Uses content comparison to avoid unnecessary re-syncs.
    """
    if not ICLOUD_DIR.is_dir():
        return

    synced = 0

    # iCloud → local: decrypt any .hermeer.enc newer than local copy
    for enc_file in ICLOUD_DIR.rglob("*.hermeer.enc"):
        try:
            rel = relative_path(enc_file, ICLOUD_DIR)
        except ValueError:
            continue
        enc_mtime = enc_file.stat().st_mtime
        local_name = enc_to_md_name(rel.name)
        local_path = LOCAL_DIR / rel.parent / local_name
        if local_path.exists() and local_path.stat().st_mtime >= enc_mtime:
            continue
        try:
            data = enc_file.read_bytes()
            plaintext = decrypt(data, passphrase)
            # Content comparison: if local already has identical content, just align mtime
            if local_path.exists() and local_path.read_bytes() == plaintext:
                os.utime(local_path, (enc_mtime, enc_mtime))
                continue
            _recently_written.add(str(local_path))
            write_atomic(local_path, plaintext, match_mtime=enc_mtime)
            synced += 1
        except Exception:
            pass  # Don't spam logs on every poll cycle

    # local depth/ → iCloud: encrypt any .md not yet in iCloud
    local_depth = LOCAL_DIR / "depth"
    if local_depth.is_dir():
        for md_file in local_depth.rglob("*.md"):
            try:
                rel = relative_path(md_file, local_depth)
            except ValueError:
                continue
            md_mtime = md_file.stat().st_mtime
            enc_name = rel.name.replace(".md", ".hermeer.enc")
            enc_path = ICLOUD_DIR / "depth" / rel.parent / enc_name
            if enc_path.exists() and enc_path.stat().st_mtime >= md_mtime:
                continue
            try:
                plaintext = md_file.read_bytes()
                # Content comparison: if encrypted version decrypts to same content, just align mtime
                if enc_path.exists():
                    try:
                        existing_plaintext = decrypt(enc_path.read_bytes(), passphrase)
                        if existing_plaintext == plaintext:
                            os.utime(enc_path, (md_mtime, md_mtime))
                            continue
                    except Exception:
                        pass  # Decrypt failed — re-encrypt
                ciphertext = encrypt(plaintext, passphrase)
                _recently_written.add(str(enc_path))
                write_atomic(enc_path, ciphertext, match_mtime=md_mtime)
                synced += 1
            except Exception:
                pass

    if synced > 0:
        logger.info(f"Periodic poll: synced {synced} missed file(s)")


def main():
    parser = argparse.ArgumentParser(
        description="Hermeer encryption/decryption daemon for HermeerSync pipeline."
    )
    parser.add_argument(
        "--passphrase",
        help="Passphrase for encryption/decryption (default: read from Keychain)",
    )
    parser.add_argument(
        "--save-to-keychain",
        action="store_true",
        help="Save the provided passphrase to macOS Keychain",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Run health check and exit",
    )
    args = parser.parse_args()

    # ── Resolve passphrase ────────────────────────────────────────────────

    passphrase = args.passphrase

    if args.save_to_keychain:
        if not passphrase:
            print("Error: --save-to-keychain requires --passphrase", file=sys.stderr)
            sys.exit(1)
        try:
            save_keychain(passphrase)
            print(f"Passphrase saved to Keychain ({KEYCHAIN_SERVICE})")
        except RuntimeError as e:
            print(f"Error saving to Keychain: {e}", file=sys.stderr)
            sys.exit(1)
        # If only saving, exit unless also running daemon
        if not args.check:
            print("Passphrase stored. Run without --save-to-keychain to start daemon.")
            return

    if not passphrase:
        try:
            passphrase = read_keychain()
        except RuntimeError as e:
            print(f"Error reading Keychain: {e}", file=sys.stderr)
            print(
                "Run with --passphrase 'PASS' --save-to-keychain first.",
                file=sys.stderr,
            )
            sys.exit(1)

    # ── Health check mode ─────────────────────────────────────────────────

    if args.check:
        success = run_check(passphrase)
        sys.exit(0 if success else 1)

    # ── Ensure local dir exists ───────────────────────────────────────────

    LOCAL_DIR.mkdir(parents=True, exist_ok=True)
    (LOCAL_DIR / "depth").mkdir(parents=True, exist_ok=True)

    logger.info("Hermeer decrypt daemon starting")
    logger.info(f"iCloud: {ICLOUD_DIR}")
    logger.info(f"Local:  {LOCAL_DIR}")

    # ── Initial sync ─────────────────────────────────────────────────────

    initial_sync(passphrase)

    # ── Set up watchers ───────────────────────────────────────────────────

    observer = Observer()

    # Watch iCloud for .hermeer.enc and plaintext .md
    icloud_handler = ICloudHandler(passphrase)
    if ICLOUD_DIR.is_dir():
        observer.schedule(icloud_handler, str(ICLOUD_DIR), recursive=True)
        logger.info("Watching iCloud for encrypted files")
    else:
        logger.warning(f"iCloud dir not found, skipping watch: {ICLOUD_DIR}")

    # Watch local depth/ for .md files to encrypt back
    local_depth = LOCAL_DIR / "depth"
    local_handler = LocalDepthHandler(passphrase)
    observer.schedule(local_handler, str(local_depth), recursive=True)
    logger.info("Watching local depth/ for files to encrypt")

    # ── Graceful shutdown ─────────────────────────────────────────────────

    running = True

    def shutdown(signum, frame):
        nonlocal running
        sig_name = signal.Signals(signum).name
        logger.info(f"Received {sig_name}, shutting down")
        running = False

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    # ── Run ───────────────────────────────────────────────────────────────

    observer.start()
    logger.info("Daemon running (PID %d)", os.getpid())

    # Periodic poll interval — catches files FSEvents misses over iCloud
    POLL_INTERVAL = 300  # seconds
    last_poll = time.time()

    try:
        while running:
            time.sleep(1)
            now = time.time()
            if now - last_poll >= POLL_INTERVAL:
                last_poll = now
                try:
                    poll_for_missed_files(passphrase)
                except Exception as e:
                    logger.error(f"Periodic poll error: {e}")
    finally:
        observer.stop()
        observer.join()
        logger.info("Daemon stopped")


if __name__ == "__main__":
    main()
