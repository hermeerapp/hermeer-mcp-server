#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerReadTools } from "./read-tools.js";
import { registerWriteTools } from "./write-tools.js";
import { resolveBase } from "./utils.js";

const base = resolveBase();

const server = new McpServer({
  name: "hermeer",
  version: "1.0.0",
});

registerReadTools(server, base);
registerWriteTools(server, base);

const transport = new StdioServerTransport();
await server.connect(transport);
