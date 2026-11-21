#!/usr/bin/env node
// Custom Claude Code statusline
// Layout: model │ ctx tokens (%) │ 5h │ 7d
//
// Reads the statusLine hook JSON from stdin. Every lookup is defensive: any
// missing field (or absent rate_limits for non-subscribers) drops that segment
// rather than breaking the line.

// --- ANSI helpers -----------------------------------------------------------
const RESET = '\x1b[0m';
const DIM = '\x1b[2m';

// Color a usage percentage: green < 50, yellow 50-79, red >= 80.
function pctColor(pct) {
  if (pct >= 80) return '\x1b[31m';      // red
  if (pct >= 50) return '\x1b[33m';      // yellow
  return '\x1b[32m';                     // green
}

function paint(code, text) {
  return `${code}${text}${RESET}`;
}

// Compact "time until reset" from a Unix epoch (seconds). e.g. 3d4h / 2h13m / 45m.
function fmtResetIn(resetsAt) {
  if (resetsAt == null) return '';
  let s = Math.floor(resetsAt - Date.now() / 1000);
  if (s <= 0) return 'now';
  const d = Math.floor(s / 86400); s -= d * 86400;
  const h = Math.floor(s / 3600); s -= h * 3600;
  const m = Math.floor(s / 60);
  if (d > 0) return `${d}d${h}h`;
  if (h > 0) return `${h}h${m}m`;
  return `${m}m`;
}

// Build a rate-limit segment: colored "label: NN%" + dim "↻<reset>". null if absent.
function limitSeg(label, lim) {
  const pct = lim?.used_percentage;
  if (pct == null) return null;
  const v = Math.round(pct);
  let seg = paint(pctColor(v), `${label}: ${v}%`);
  const reset = fmtResetIn(lim.resets_at);
  if (reset) seg += paint(DIM, ` ↻ ${reset}`);
  return seg;
}

const THOUSAND = 1000;
const MILLION = 1000000;

function fmtTokens(n) {
  if (n >= MILLION) return `${(n / MILLION).toFixed(1).replace(/\.0$/, '')}M`;
  if (n >= THOUSAND) return `${Math.round(n / THOUSAND)}k`;
  return `${n}`;
}

function usedPercentage(ctx) {
  if (ctx.used_percentage != null) return ctx.used_percentage;
  if (ctx.remaining_percentage != null) return 100 - ctx.remaining_percentage;
  return null;
}

function usedTokens(ctx, pct) {
  const u = ctx.current_usage;
  if (u) {
    return (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
  }
  if (pct == null || !ctx.context_window_size) return null;
  return Math.round((pct / 100) * ctx.context_window_size);
}

function contextSeg(ctx) {
  if (!ctx) return null;
  const pct = usedPercentage(ctx);
  if (pct == null) return null;
  const v = Math.max(0, Math.min(100, Math.round(pct)));
  const tokens = usedTokens(ctx, pct);
  if (tokens == null) return paint(pctColor(v), `ctx: ${v}%`);
  return paint(pctColor(v), `ctx: ${fmtTokens(tokens)} (${v}%)`);
}

// --- main --------------------------------------------------------------------
function render(data) {
  const segments = [];

  // model — display name (+ reasoning effort level, when present)
  // strip Claude Code's " (1M context)" suffix so the 1m Opus variant reads
  // uniformly with every other model: just "<name> (<effort>)"
  const model = (data.model?.display_name || 'Claude').replace(/\s*\(1M context\)/i, '');
  const effort = data.effort?.level;
  const modelLabel = effort ? `${model} (${effort})` : model;
  segments.push(paint(DIM, modelLabel));

  // ctx — tokens used, plus used percentage
  const ctxSeg = contextSeg(data.context_window);
  if (ctxSeg) segments.push(ctxSeg);

  // 5h / 7d subscription rate limits (absent for non-subscribers)
  const s5 = limitSeg('5h', data.rate_limits?.five_hour);
  if (s5) segments.push(s5);
  const s7 = limitSeg('7d', data.rate_limits?.seven_day);
  if (s7) segments.push(s7);

  const sep = paint(DIM, ' │ ');
  return segments.join(sep);
}

function main() {
  let input = '';
  const t = setTimeout(() => process.exit(0), 3000); // stdin guard (#775)
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', c => (input += c));
  process.stdin.on('end', () => {
    clearTimeout(t);
    try {
      // Strip a leading UTF-8 BOM / surrounding whitespace before parsing —
      // some shells prepend a BOM when piping (harmless under Claude Code, which
      // pipes raw, but makes the parser robust either way).
      const clean = input.replace(/^\uFEFF/, '').trim();
      process.stdout.write(render(JSON.parse(clean)));
    } catch (e) {
      // never break the statusline on parse/render errors
    }
  });
}

module.exports = { render };
if (require.main === module) main();
