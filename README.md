# grill-to-waves

A two-skill delivery pipeline for coding agents, plus the executor and scout agent definitions it
dispatches.

- **`/grill-to-waves`** plans: it grills the idea, writes one spec per shippable slice, tickets each
  spec, proves the specs write-disjoint, publishes an execution map — then stops.
- **`/orchestrate`** executes that map: it dispatches ticket executors as subagents, verifies their
  work itself, merges a whole wave under one gate, and closes the specs and the map.

Planning and execution are deliberately separate sessions. The pipeline ends at a published map so
that execution starts on a fresh context window with the plan as its only input.

## What it gives you

| Piece | What it is |
|---|---|
| `CONTEXT.md` | Canonical distinction between executor tier and reasoning effort. |
| `skills/grill-to-waves/SKILL.md` | The seven-stage pipeline (Stage 0 tracker → Stage 6 stop). |
| `skills/grill-to-waves/SESSIONS.md` | Write surfaces, the collision rule, ownership, resume. The protocol both skills share. |
| `skills/grill-to-waves/TRACKERS.md` | The five tracker operations for GitHub (`gh`), GitLab (`glab`) and local markdown. |
| `skills/grill-to-waves/DEFAULTS.md` | Model/effort ladder, both Fable tiers, scout tiering, and the junction-safe worktree teardown. |
| `skills/orchestrate/SKILL.md` | Wave dispatch, verification, merge gate, closing upward, team shape. |
| `agents/executor-{fable-five-one,fable,opus,sonnet}-{medium,high,xhigh}.md` | Twelve ticket executors, one per tier/effort pairing. |
| `agents/scout-{sonnet-medium,sonnet-high,opus-medium,opus-high}.md` | Four read-only scouts: locate, sweep, focused judgment, broad analysis. |
| `agents/codex/*.toml` | The same sixteen agents as Codex CLI custom agents — same names, same bodies, Codex models per the `Hosts` table in `DEFAULTS.md`. |
| `skills/*/agents/openai.yaml` | Codex skill metadata: user-invocation only, the equivalent of `disable-model-invocation`. Claude Code ignores it. |

The tracker is the state store — specs, tickets and the map are issues, and the repo keeps a durable
docs mirror of each spec. Nothing depends on a local file that a context clear would lose.

## Install

### 1. Install the Matt Pocock skill collection first

Install the complete [mattpocock/skills](https://github.com/mattpocock/skills) collection on both
hosts. The pipeline directly requires three of them: one for repository setup in Stage 0 and two for
grilling in Stage 1.

**Claude Code** — the plugin:

```
/plugin marketplace add mattpocock/skills
/plugin install mattpocock-skills@mattpocock
```

The marketplace is named `mattpocock`, not `skills`. Outside the session the same operations are
`claude plugin marketplace add mattpocock/skills` and
`claude plugin install mattpocock-skills@mattpocock`; an install needs a restart to apply.

| Skill | Used by |
|---|---|
| `grilling` | Stage 1 — the grill itself. |
| `domain-modeling` | Stage 1, whenever vocabulary is in play. |
| `setup-matt-pocock-skills` | Stage 0 — records the tracker choice in `docs/agents/issue-tracker.md`, run once per repo. |

**Codex CLI** — run this from the project where you will use the pipeline (Node.js/npm is required):

```bash
npx skills@latest add mattpocock/skills --skill '*' -a codex
```

Choose **project scope** if prompted. This installs the full collection under the project's
`.agents/skills/` directory, matching the collection provided by the Claude Code plugin. Restart
Codex afterwards. Run `$setup-matt-pocock-skills` once in each repository before its first
`$grill-to-waves` run. The installer verifies the three pipeline requirements—`$grilling`,
`$domain-modeling`, and `$setup-matt-pocock-skills`—and prints the full-collection command when one
is missing.

### 2. Install the skills and agents

```powershell
# Windows / PowerShell
irm https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.ps1 | iex
```

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.sh | bash
```

With no arguments, either installer asks whether to install for Claude Code, Codex CLI, or both.
Use `-Target` / `--target` to skip the prompt in automation.

Or from a clone, which is also how you get the flags:

```bash
git clone https://github.com/jefrykurniaone/grill-to-waves.git
cd grill-to-waves
./install.sh                       # or  ./install.ps1
```

| Flag | Effect |
|---|---|
| `--target claude\|codex\|both\|auto` (`-Target`) | Skip the prompt and choose a host. `auto` does Claude Code, and Codex too when `~/.codex` exists. |
| `--project PATH` (`-Project`) | Install into the project instead of the home directory: `PATH/.claude` for Claude Code; `PATH/.agents/skills` and `PATH/.codex/agents` for Codex. |
| `--no-backup` (`-NoBackup`) | Do not move a replaced directory or file to `<backups>/<name>-<timestamp>` first (`~/.claude/backups`, `~/.codex/backups`). |
| `--ref REF` (`-Ref`) | Branch, tag or commit to fetch when running without a local checkout. |

Where it lands:

```
Claude Code                          Codex CLI
~/.claude/skills/grill-to-waves/     ~/.agents/skills/grill-to-waves/
~/.claude/skills/orchestrate/        ~/.agents/skills/orchestrate/
~/.claude/agents/*.md                ~/.codex/agents/*.toml
```

Restart the session afterwards so the host re-reads its skill and agent directories.

### Codex CLI specifics

Codex reads skills from `~/.agents/skills/` (the agent-skills standard; `~/.codex/skills/` is its
legacy root and the installer warns if a copy is there too) and custom agents from
`~/.codex/agents/*.toml`. Subagents are on by default (`agents.enabled`); the installer warns if
`~/.codex/config.toml` turns them off, and prints `agents.max_concurrent_threads_per_session` when
it is set, because a map's in-flight ceiling must stay under it.

The skill text in this repo is written in Claude Code's vocabulary. For Codex the installer
rewrites, and only rewrites: `/orchestrate`, `/grill-to-waves`, and `/setup-matt-pocock-skills` to
Codex `$` mentions; `.claude/worktrees` and `.claude/scratch` to `.codex/…`; the two grill-skill
names to `$grilling` and `$domain-modeling`; and it drops the `disable-model-invocation` line, whose
Codex equivalent is each skill's `agents/openai.yaml` (`allow_implicit_invocation: false`).

The tier names in the labels and agent names are tiers, not vendors. The Codex agents pin these
models; edit the `.toml` to re-map:

| Tier (label) | Claude Code | Codex CLI |
|---|---|---|
| highest (`executor:fable-five-one`) | Fable 5.1 (`claude-fable-5-1`) at `medium` / `high` / `xhigh` | `gpt-6-astra` at the same effort |
| Fable (`executor:fable`) | Fable 5 (`claude-fable-5`) at `medium` / `high` / `xhigh` | `gpt-5.6-sol` at the same effort |
| frontier (`executor:opus`) | Opus at `medium` / `high` / `xhigh` | `gpt-5.6-terra` at the same effort |
| mid (`executor:sonnet`) | Sonnet at `medium` / `high` / `xhigh` | `gpt-5.6-luna` at the same effort |
| `scout-sonnet-*` | Sonnet at `medium` / `high` | `gpt-5.6-luna` at the same effort |
| `scout-opus-*` | Opus at `medium` / `high` | `gpt-5.6-terra` at the same effort |

Read-only scouts are read-only by `sandbox_mode = "read-only"`. Codex subagents share the parent's
working directory, so the orchestrator names each executor's worktree path in its brief; an executor
whose sandbox has no network reports its branch and the orchestrator pushes and opens the review
request itself. The full table, including dispatch tool names, is the `Hosts` section of
`skills/grill-to-waves/DEFAULTS.md`.

## Use

```
/grill-to-waves <the idea, in whatever shape it is in>      # Claude Code
$grill-to-waves <the idea, in whatever shape it is in>      # Codex CLI
```

It stops at Stage 6 and prints the launch lines, solo first (on Codex the prefix is `$`):

```
/orchestrate map <map> + check      # read-only preflight, writes nothing
/orchestrate map <map>              # one session, wave by wave
/orchestrate map <map> + all        # one session, every wave, no stop between
```

Run those in a **new** session. `+ check` is the cheap way to see what a run would do.

A team splits a map by spec instead — one developer per clone, never two sessions in one working
copy:

```
/orchestrate map <map> + spec <spec-a> + team
/orchestrate map <map> + tail        # the serial owner, once every row is closed
```

## Requirements

- **A git repository with a remote**, and an issue tracker CLI for it: `gh` (GitHub) or `glab`
  (GitLab). With no remote, the pipeline falls back to local markdown under `.scratch/`.
- **A host with subagent dispatch** for the parallel path — Claude Code's `Agent` tool, or Codex
  CLI's `spawn_agent` with the custom agents this repo installs. A host without one still runs the
  skills: the session executes tickets itself, one at a time, with the agent definitions read as
  role briefs (see *Hosts without subagent dispatch* in `skills/orchestrate/SKILL.md`).
- **[mattpocock/skills](https://github.com/mattpocock/skills)**, required — `grilling` and
  `domain-modeling` for Stage 1, and `setup-matt-pocock-skills` for the Stage 0 tracker record on
  both hosts. Install step 1 above.
- **Playwright MCP**, optional, for runtime verification of `runtime: dev-server` tickets. Without it
  the orchestrator falls back to scripted Playwright or plain HTTP, and says which it used.

Per-repository conventions — the completion gate, the seams, the hard rules an executor brief has to
carry — are read from the repository's own `CLAUDE.md` or `AGENTS.md`, and override `DEFAULTS.md`
where they differ. Recording the tracker choice in `docs/agents/issue-tracker.md` keeps Stage 0 from
re-detecting it every run.

## Design notes

- **The spec is the unit of splitting.** Tickets carry a write surface; specs are proved disjoint at
  planning time, or fused when they collide. Disjoint writes prove non-collision, never independence —
  serial merges plus a whole-gate re-run after each merge is the only net.
- **The orchestrator verifies; the executor does not self-certify.** An executor's account of its own
  work is a claim. The orchestrator reads the diff, runs the gate, and measures rather than eyeballs.
- **Executor tier and effort are separate axes.** Consequence and reach choose Sonnet, Opus, Fable or
  Fable 5.1; exploration and unresolved decisions choose `medium`, `high` or `xhigh`. Fable covers
  failure that would be irreversible, run-wide or adversarial; Fable 5.1 is the explicit escalation
  when Fable at higher effort is known or expected to fall short. Fallback preserves effort.
- **Two agent sessions never share one working copy.** They contend on the tree, the dev server and
  the dev database at once. Splitting a run means one developer per clone.
- **Nothing is true until it is on the tracker.** Sessions share no context window, so a fact that
  was never posted did not happen.

## License

MIT — see [LICENSE](./LICENSE).
