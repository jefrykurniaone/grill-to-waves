# Orchestration defaults

The model, effort and worktree rules both skills read. It travels with the skill, so a repository
needs no per-machine setup to run the pipeline. Where a repository or a user's own memory file states
something narrower, that wins — this file is the floor, not a ceiling.

## Model and effort

- **Executors: three tiers, chosen by how far a wrong decision travels. Never the small/cheap tier.**
  The mid tier (Sonnet) for tickets whose decisions were all made upstream; the frontier model (Opus)
  for tickets that decide things inside a bounded blast radius; the top tier (Fable) for the hardest
  tickets, where a wrong decision is irreversible, run-wide or adversarial — see *The Fable tier*
  below. Follow the ticket's `executor:` label where one exists.
- **Executor reasoning effort: `medium`, `high` or `xhigh`. Never `low`.** Follow the ticket's
  `effort:` label; default `high` when unlabelled. Two things set the level at ticketing time — how
  much the executor must *explore* before it can edit, and how many *decisions* it makes alone.
- **The orchestrator and the verifier run on the most capable model available — Fable, or Opus if
  Fable is unavailable.** Verification of executor output is the orchestrator's job, never left to the
  executor that produced it. Executor and orchestrator may be the same model; they are never the same
  context, and the orchestrator reads the diff itself.

### The effort ladder

| Level | Use when | Typical pairing |
|---|---|---|
| `medium` | The target is fully specified upstream and the exploration is narrow: the files are named or trivially found, the edit is mechanical, and no decision is left to make — a rename, a dead column removed at enumerated sites, a copy change, a docs mirror, a restyle onto a settled component. | Sonnet `medium` |
| `high` | **The default.** Judgment inside a bounded scope: a new surface on an existing seam, a route or form change, a multi-file feature whose decisions were made upstream but whose *placement* needs reading breadth, any ticket that must discover its own call sites. | Sonnet `high` when the decisions were all made upstream; Opus `high` when the executor decides anything a later ticket builds on |
| `xhigh` | Judgment *is* the work, and a wrong decision propagates or loses data: anything touching money, capacity, stored enums, migrations that need a correctness argument, concurrency or row locks, a component seam several surfaces will compose, security boundaries, adversarial verification of subtle behaviour. | Opus `xhigh` while the blast radius stays bounded; Fable `xhigh` when the wrong decision would be irreversible, run-wide or adversarial (Sonnet `xhigh` is legal but rarely the right call) |

Two axes, read together: **exploration need** (must the agent sweep many files, naming conventions or
runtime behaviour before editing?) and **task complexity** (how many decisions does it make alone,
and how far do they propagate?). Low on both → `medium`. High on either → `high`. Decisions that
propagate or can lose data → `xhigh`, regardless of exploration. Never pick a level to save tokens on
a ticket where the decisions are the deliverable; never pick `xhigh` for a mechanical edit — it does
not make a rename more correct.

### The Fable tier

Fable exists for one class of ticket: judgment is the work **and** a wrong decision escapes the net the
pipeline otherwise relies on — the gate, the orchestrator's verification, one hand-back. Grade a ticket
`executor:fable effort:xhigh` when any of these holds:

- **Irreversible once landed.** A data migration or backfill, a rewrite of stored values, a destructive
  schema change — anything a reset of the branch does not undo because it ran against data.
- **Run-wide.** A seam, contract, type or stored enum that several specs or later waves compose. A wrong
  call is rebuilt by every downstream ticket, and the gate passes on each of them.
- **Adversarial.** A security boundary (authentication, authorisation, tenancy, secrets) or a
  concurrency argument (a race, a lock order, an idempotency key) that the test suite cannot prove and
  a reviewer must reason about.

Everything else that is judgment-heavy stays Opus `xhigh`: a money rule inside one module, a stored
enum consumed inside one spec, a lock on one table, an additive migration the gate proves. Exploration
breadth alone never earns Fable — a large sweep is Opus at most.

Rules that follow:

- **Fable is `xhigh` only.** There is no `executor-fable-medium` or `executor-fable-high`: a ticket
  whose decisions do not carry that weight does not need the tier, whatever its size.
- **Name every Fable ticket in the map**, with the clause above that earned it. A wave normally holds
  one or two at most; a run where most tickets grade Fable has been split too coarsely, or its specs
  have left their decisions to the executors.
- **Fable tickets sit early.** They are usually the seam others build on, so they belong in the wave
  that blocks the tickets composing them, never after those tickets.
- **Fallback.** Where `executor-fable-xhigh` is missing or Fable is not available on the account,
  dispatch `executor-opus-xhigh` with the same brief, keep the label, and record the substitution in
  the ticket's closing comment and the wave report.
- **Fable is never a scout.** Locating and sweeping are breadth, not judgment; a judgement that needs
  Fable is made in the orchestrator session, which already runs on it.

### Scouts

Read-only sub-agents (fact-finding, code location, analysis) follow the same tiering. Always pass the
model and effort explicitly rather than inheriting:

- **Locate a known symbol or file** (one grep, one read, cite `path:line`): `scout-sonnet-medium`.
- **Sweep many locations or naming conventions** (map a directory, list every caller, find where
  something lives when the name is unknown): `scout-sonnet-high`.
- **Analyse, judge or audit inside the sub-agent** (root-cause analysis, security sweep, reviewing a
  diff for defects): `scout-opus-high`.
- **Adversarially verify subtle behaviour** (prove a race, a data-loss path, a money rule): do it in
  the orchestrator session, or dispatch an `executor-fable-xhigh` brief that writes nothing
  (`executor-opus-xhigh` where Fable is unavailable).

### How effort is applied

Effort is fixed in the agent definition, never passed per call: Claude Code's `Agent` tool has a
`model` override but no effort parameter, and Codex's `spawn_agent` selects a custom agent whose file
pins `model_reasoning_effort`. The definitions this repo installs are `executor-fable-xhigh` and
`executor-{sonnet,opus}-{medium,high,xhigh}` (full tools) and `scout-sonnet-medium`,
`scout-sonnet-high`, `scout-opus-high` (read-only) — one set per host, same names, same bodies.
Dispatch the agent named `executor-<model>-<effort>` matching the ticket's labels. If
`executor-fable-xhigh` is missing or the top-tier model is unavailable, dispatch `executor-opus-xhigh`
instead; if any other agent is missing, fall back to the host's general agent with the mapped model
set and the effort level stated in the prompt. Either substitution is said in the wave report.

### Hosts

The tier names in the labels (`fable`, `opus`, `sonnet`) and in the agent names are **tiers, not
vendors**: top, frontier, mid. Each host maps them to its own models, and the labels stay the same so
a map planned on one host executes on the other.

| | Claude Code | Codex CLI |
|---|---|---|
| Top tier (`fable`) | Fable (`model: fable`) at `xhigh` | GPT-6 Astra (`gpt-6-astra`) at `xhigh` — the highest effort the Codex config reference documents; Astra also offers `max` and `ultra` at runtime |
| Frontier tier (`opus`) | Opus at `medium` / `high` / `xhigh` | GPT-5.6 Sol (`gpt-5.6-sol`) at the same effort |
| Mid tier (`sonnet`) | Sonnet at `medium` / `high` / `xhigh` | GPT-5.6 Terra (`gpt-5.6-terra`) at the same effort |
| Narrow locator scout (`scout-sonnet-medium`) | Sonnet `medium` | GPT-5.6 Luna (`gpt-5.6-luna`) `medium` — the one place the small tier is used, because a one-grep locate is exactly the "fast, narrowly scoped" work Luna is positioned for; set `gpt-5.6-terra` in its file to keep every scout on the mid tier |
| Never | Haiku | GPT-5.6 Luna or GPT-5.4-mini as an executor |
| Agent definitions | `~/.claude/agents/<name>.md` — YAML frontmatter `model`, `effort`, `tools` | `~/.codex/agents/<name>.toml` (or `.codex/agents/` in a project) — `model`, `model_reasoning_effort`, `sandbox_mode`, `developer_instructions` |
| Dispatch | `Agent` tool with `subagent_type: <name>` | `spawn_agent` naming the custom agent; `wait_agent` to collect; `followup_task` for rework on the same executor |
| Message a running executor | `SendMessage` | `send_message` |
| In-flight ceiling | the map's (default three, hard maximum five) | the map's, and never above `agents.max_concurrent_threads_per_session` in `~/.codex/config.toml` |
| Skill invocation | a slash command: the skill name after `/` | a skill mention: the skill name after `$` |
| Agent directory in the repo | `.claude/` — `worktrees/<row>/<ticket>` and `scratch/` under it | `.codex/` — the same two paths under it, inside the workspace so a `workspace-write` sandbox can write there |
| Required grill skills | the `mattpocock-skills` plugin, invoked as `mattpocock-skills:<name>` | `$grilling` and `$domain-modeling`, installed as skills under `~/.agents/skills/` |
| Read-only scouts | by tool list in the frontmatter | by `sandbox_mode = "read-only"` |

The skill text in this repo is written in Claude Code's vocabulary; the installer rewrites the
invocation prefix, the agent directory and the grill-skill names when it installs for Codex, and
nothing else. Codex sub-agents share the parent's working directory, so an executor brief on Codex
names the worktree's absolute path and tells the executor to work only there. A Codex executor in a
`workspace-write` sandbox may have no network: when it cannot push or open the review request, the
orchestrator does both from the executor's branch, and the ticket's record says so.

## Worktree teardown — the junction trap

Applies wherever a worktree's dependency tree is a link (a Windows junction, or a symlink) to the main
tree's copy rather than its own installed copy — what `deps: shared` means in a ticket's surface block.

**The trap.** A build inside the worktree can write *further* links back into the main tree — a
Next.js/Turbopack build writes `<worktree>/.next/node_modules/` filled with junctions to the main
tree's server externals (`@prisma/client-<hash>`, `pg-<hash>` observed). A recursive delete, including
`git worktree remove --force`, follows those links and **empties the targets in the main tree**.
Unlinking only the top-level `node_modules` link is not enough; the ones under the build cache remain.
Symptoms land everywhere at once: `Cannot find module '@prisma/client'`, unrelated test files failing,
`Module not found` mid-build, a broken dev server. Some packages survive, so spot-checking one package
proves nothing.

**Teardown procedure — every time, never skipped.** Unlink every reparse point / symlink inside the
worktree **deepest first**, confirm none remain, and only then remove the worktree.

PowerShell (Windows):

```powershell
$wt = "<repo>\.claude\worktrees\<row>\<ticket>"
$links = Get-ChildItem -Path $wt -Recurse -Force -Attributes ReparsePoint |
    Sort-Object { $_.FullName.Length } -Descending
foreach ($l in $links) { (Get-Item -LiteralPath $l.FullName -Force).Delete() }
if (-not (Get-ChildItem -Path $wt -Recurse -Force -Attributes ReparsePoint)) {
    git worktree remove $wt --force
}
git branch -D <branch>
```

POSIX (macOS, Linux):

```bash
wt="<repo>/.claude/worktrees/<row>/<ticket>"
find "$wt" -depth -type l -delete
[ -z "$(find "$wt" -type l -print -quit)" ] && git worktree remove "$wt" --force
git branch -D <branch>
```

`.Delete()` on the `DirectoryInfo` unlinks without following the link, which is the whole point;
`Remove-Item -Recurse` and `rm -rf` do follow. Clear a build cache with
`[System.IO.Directory]::Delete((Resolve-Path .next).Path, $true)` on Windows.

**Repair if it already happened:** reinstall in the **main** tree and re-run the code generator
(`npm install`, whose `postinstall` usually covers it), then restart any dev server that was running
while the gutting happened.

**Executor briefs must say:** never run an install or a code generator inside a `deps: shared`
worktree — a generator that writes into the shared dependency tree clears it first, emptying it for
every tree at once. A ticket that changes the schema or a dependency gets `deps: own`: a full copy of
the dependency tree, never the link.

## Verification gate before each completion gate

Before judging the main tree green, confirm the generated database client (Prisma or equivalent) is
present where the repo has one. Missing → repair it before anything else, because every downstream
failure it causes is misattributed.
