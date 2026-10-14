// Stand-in for the CLIs the installers call: gh, glab, claude, codex, npx and markitdown-mcp.
//
//   node stub-cli.js NAME [arguments]
//
// The tests put one wrapper per name on PATH, each running this script with its own name. Every
// call appends one line, the name and its arguments joined by spaces, to the file G2W_STUB_LOG
// names, so a test reads back exactly what the installer ran. The answers:
//
//   gh | glab auth status   0 when the name is in G2W_STUB_SIGNED_IN, 1 otherwise
//   claude mcp add          1 and Claude Code's "already exists" message when the server is in
//                           G2W_STUB_CLAUDE_SERVERS, 0 otherwise
//   claude mcp get NAME     0 when NAME is in G2W_STUB_CLAUDE_SERVERS, 1 otherwise
//   codex mcp get NAME      0 when NAME is in G2W_STUB_CODEX_SERVERS, 1 otherwise
//   anything else           0
//
// Each of the three variables is a space-separated list of names.
'use strict';

const fs = require('fs');

const [name, ...args] = process.argv.slice(2);
fs.appendFileSync(process.env.G2W_STUB_LOG, [name, ...args].join(' ') + '\n');

function listed(variable, value) {
  return (process.env[variable] || '').split(/\s+/).includes(value);
}

// The server in `claude mcp add [options] <name> ...`: the first word that is neither an option nor
// an option's value. Every option the installers pass takes a value.
function addedServer(words) {
  for (let i = 0; i < words.length; i++) {
    if (words[i] === '--') return undefined;
    if (!words[i].startsWith('-')) return words[i];
    i++;
  }
  return undefined;
}

const call = args.slice(0, 2).join(' ');
let code = 0;
if ((name === 'gh' || name === 'glab') && call === 'auth status') {
  code = listed('G2W_STUB_SIGNED_IN', name) ? 0 : 1;
} else if (name === 'claude' && call === 'mcp add') {
  const server = addedServer(args.slice(2));
  if (listed('G2W_STUB_CLAUDE_SERVERS', server)) {
    console.error(`MCP server ${server} already exists in user config`);
    code = 1;
  }
} else if (name === 'claude' && call === 'mcp get') {
  code = listed('G2W_STUB_CLAUDE_SERVERS', args[2]) ? 0 : 1;
} else if (name === 'codex' && call === 'mcp get') {
  code = listed('G2W_STUB_CODEX_SERVERS', args[2]) ? 0 : 1;
}
process.exit(code);
