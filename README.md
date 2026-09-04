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
| `skills/grill-to-waves/SKILL.md` | The seven-stage pipeline (Stage 0 tracker → Stage 6 stop). |
| `skills/grill-to-waves/SESSIONS.md` | Write surfaces, the collision rule, ownership, resume. The protocol both skills share. |
| `skills/grill-to-waves/TRACKERS.md` | The five tracker operations for GitHub (`gh`), GitLab (`glab`) and local markdown. |
| `skills/grill-to-waves/DEFAULTS.md` | Model/effort ladder, scout tiering, and the junction-safe worktree teardown. |
| `skills/orchestrate/SKILL.md` | Wave dispatch, verification, merge gate, closing upward, team shape. |
| `agents/executor-{opus,sonnet}-{medium,high,xhigh}.md` | Six ticket executors, one per model/effort pairing. |
| `agents/scout-{sonnet-medium,sonnet-high,opus-high}.md` | Three read-only scouts: locate, sweep, judge. |

The tracker is the state store — specs, tickets and the map are issues, and the repo keeps a durable
docs mirror of each spec. Nothing depends on a local file that a context clear would lose.

## Install

### 1. Install the required plugin first

The pipeline calls three skills from [mattpocock/skills](https://github.com/mattpocock/skills), so
install that plugin before the first run. In Claude Code:

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

### 2. Install the skills and agents

```powershell
# Windows / PowerShell
irm https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.ps1 | iex
```

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.sh | bash
```

Or from a clone, which is also how you get the flags:

```bash
git clone https://github.com/jefrykurniaone/grill-to-waves.git
cd grill-to-waves
./install.sh                       # or  ./install.ps1
```

| Flag | Effect |
|---|---|
| `--target claude\|codex\|both\|auto` (`-Target`) | Which host to install for. `auto` (default) does Claude Code, and Codex too when `~/.codex` exists. |
| `--project PATH` (`-Project`) | Install into `PATH/.claude` instead of the home directory. Claude Code only — Codex has no project skill scope. |
| `--no-backup` (`-NoBackup`) | Do not move a replaced directory to `<target>/backups/<name>-<timestamp>` first. |
| `--ref REF` (`-Ref`) | Branch, tag or commit to fetch when running without a local checkout. |

Where it lands:

```
~/.claude/skills/grill-to-waves/     ~/.codex/skills/grill-to-waves/
~/.claude/skills/orchestrate/        ~/.codex/skills/orchestrate/
~/.claude/agents/*.md                ~/.codex/skills/grill-to-waves/agents/*.md
```

Restart the session afterwards so the host re-reads its skill and agent directories.

## Use

```
/grill-to-waves <the idea, in whatever shape it is in>
```

It stops at Stage 6 and prints the launch lines, solo first:

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
- **A host with subagent dispatch** for the parallel path — Claude Code. On Codex the skills still
  run: the session executes tickets itself, one at a time, with the agent definitions read as role
  briefs (see the *Hosts without subagent dispatch* section of `skills/orchestrate/SKILL.md`).
- **[mattpocock/skills](https://github.com/mattpocock/skills)**, required — `grilling` and
  `domain-modeling` for Stage 1, `setup-matt-pocock-skills` for the Stage 0 tracker record. Install
  step 1 above.
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
- **Two agent sessions never share one working copy.** They contend on the tree, the dev server and
  the dev database at once. Splitting a run means one developer per clone.
- **Nothing is true until it is on the tracker.** Sessions share no context window, so a fact that
  was never posted did not happen.

## License

MIT — see [LICENSE](./LICENSE).
