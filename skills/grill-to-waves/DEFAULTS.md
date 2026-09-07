# Orchestration defaults

The model, effort and worktree rules both skills read. It travels with the skill, so a repository
needs no per-machine setup to run the pipeline. Where a repository or a user's own memory file states
something narrower, that wins — this file is the floor, not a ceiling.

## Model and effort

- **Executors: four tiers, chosen by the consequence and reach of an incorrect implementation.** The
  mid tier (Sonnet) for bounded work whose decisions were all made upstream; the frontier tier (Opus)
  for judgment inside a bounded blast radius; the Fable tier where failure is irreversible, run-wide
  or adversarial; and the highest tier (Fable 5.1) for demanding long-horizon work known or expected
  to exceed Fable even at higher effort. Follow the ticket's `executor:` label where one exists.
- **Executor reasoning effort: `medium`, `high` or `xhigh`. Never `low`.** Follow the ticket's
  `effort:` label; default `high` when unlabelled. Two things set the level at ticketing time — how
  much the executor must *explore* before it can edit, and how many *decisions* it makes alone. Tier
  and effort are independent: risk selects the tier; workload selects the effort.
- **The orchestrator and the verifier run on the most capable model available — Fable 5.1, then
  Fable, then Opus.** Verification of executor output is the orchestrator's job, never left to the
  executor that produced it. Executor and orchestrator may be the same model; they are never the same
  context, and the orchestrator reads the diff itself.

### The effort ladder

| Level | Use when | Typical pairing |
|---|---|---|
| `medium` | The target is fully specified upstream and the exploration is narrow: the files are named or trivially found, the edit is mechanical, and no decision is left to make — a rename, a dead column removed at enumerated sites, a copy change, a docs mirror, a restyle onto a settled component. | Usually Sonnet `medium`; any tier, including Fable 5.1, may be `medium` when its tier criteria hold but its work is fully specified |
| `high` | **The default.** Judgment inside a bounded scope: a new surface on an existing seam, a route or form change, a multi-file feature whose invariant was settled upstream but whose *placement* needs reading breadth, any ticket that must discover its own call sites. | Sonnet `high` when decisions were made upstream; Opus `high` for bounded decisions; Fable `high` for high-consequence work with a settled invariant; Fable 5.1 `high` when its escalation criterion also holds |
| `xhigh` | Judgment *is* the work: deriving a correctness argument, invariant, migration or security strategy, concurrency proof, or run-wide contract rather than implementing one already settled. | Sonnet `xhigh` is legal but rare; Opus `xhigh` for a bounded blast radius; Fable `xhigh` when its tier criteria hold; Fable 5.1 `xhigh` when the Fable tier is insufficient |

Choose the axes separately. **Consequence and reach** select the executor tier. **Exploration need and
unresolved decision complexity** select effort: narrow and decision-free → `medium`; broad reading or
bounded implementation judgment → `high`; deriving the governing design or correctness argument →
`xhigh`. High consequence never automatically raises effort, and a mechanical workload never lowers
the tier required by its blast radius. Never pick a level merely to save tokens; never pick `xhigh`
for a fully specified edit — it does not make that edit more correct.

### The Fable 5.1 tier

Fable 5.1 is the highest escalation tier, not the default for every high-consequence ticket. Grade a
ticket `executor:fable-five-one` only when its demanding long-horizon scope is known or expected to exceed
the Fable tier even at `high` or `xhigh`: a prior Fable attempt or project evaluation fell short, or
the ticket must sustain one correctness argument across an unusually large cross-system surface.
Record that evidence in the ticket, then select `medium`, `high` or `xhigh` independently from the
effort ladder.

Rules that follow:

- **Fable 5.1 supports every executor effort.** Capability selects the tier; exploration and open
  decisions still select effort.
- **Name every Fable 5.1 ticket and its escalation evidence in the map.** “Important” or “complex” is
  not evidence; state why Fable at higher effort is insufficient.
- **Fallback.** Where `executor-fable-five-one-<effort>` is missing or Fable 5.1 is unavailable, dispatch
  `executor-fable-<effort>` with the same brief and record the substitution.
- **Fable 5.1 is never a scout.** A judgment that needs it stays in the orchestrator session or uses
  a write-disabled executor brief.

### The Fable tier

Fable exists for one class of ticket: an incorrect implementation can escape the net the pipeline
otherwise relies on — the gate, the orchestrator's verification, one hand-back. Grade a ticket
`executor:fable` when any of these holds, then select `medium`, `high` or `xhigh` independently from
the effort ladder:

- **Irreversible once landed.** A data migration or backfill, a rewrite of stored values, a destructive
  schema change — anything a reset of the branch does not undo because it ran against data.
- **Run-wide.** A seam, contract, type or stored enum that several specs or later waves compose. A wrong
  call is rebuilt by every downstream ticket, and the gate passes on each of them.
- **Adversarial.** A security boundary (authentication, authorisation, tenancy, secrets) or a
  concurrency argument (a race, a lock order, an idempotency key) that the test suite cannot prove and
  a reviewer must reason about.

Everything else that is judgment-heavy stays Opus: a money rule inside one module, a stored enum
consumed inside one spec, a lock on one table, an additive migration the gate proves. Exploration
breadth alone never earns Fable — a large sweep is Opus at most.

Rules that follow:

- **Fable supports every executor effort.** Use `medium` when the high-consequence operation and its
  invariant are fully specified and narrowly located; `high` when the invariant is settled but its
  placement needs broad reading or bounded judgment; `xhigh` when deriving the invariant, strategy or
  correctness argument is itself the work.
- **Name every Fable ticket in the map**, with the clause above that earned it. A wave normally holds
  one or two at most; a run where most tickets grade Fable has been split too coarsely, or its specs
  have left their decisions to the executors.
- **Fable tickets sit early.** They are usually the seam others build on, so they belong in the wave
  that blocks the tickets composing them, never after those tickets.
- **Fallback.** Where the matching `executor-fable-<effort>` is missing or Fable 5 is not available on
  the account, dispatch `executor-opus-<effort>` with the same brief, keep both labels, and record the
  substitution in the ticket's closing comment and the wave report.
- **Fable is never a scout.** Locating and sweeping are breadth, not judgment; a judgement that needs
  Fable is made in the orchestrator session, which already runs on it.

### Scouts

Read-only sub-agents (fact-finding, code location, analysis) follow the same tiering. Always pass the
model and effort explicitly rather than inheriting:

- **Locate a known symbol or file** (one grep, one read, cite `path:line`): `scout-sonnet-medium`.
- **Judge one precise claim over a narrow evidence surface** (trace one known behaviour, answer one
  focused code question): `scout-opus-medium`.
- **Sweep many locations or naming conventions** (map a directory, list every caller, find where
  something lives when the name is unknown): `scout-sonnet-high`.
- **Analyse, judge or audit across a broad or uncertain surface** (root-cause analysis, security sweep,
  reviewing a diff for defects): `scout-opus-high`.
- **Adversarially verify subtle behaviour** (prove a race, a data-loss path, a money rule): do it in
  the orchestrator session, or dispatch an `executor-fable-xhigh` brief that writes nothing
  (`executor-fable-five-one-xhigh` only when the escalation criterion holds; `executor-opus-xhigh` where
  Fable is unavailable).

### How effort is applied

Effort is fixed in the agent definition, never passed per call: Claude Code's `Agent` tool has a
`model` override but no effort parameter, and Codex's `spawn_agent` selects a custom agent whose file
pins `model_reasoning_effort`. The definitions this repo installs are
`executor-{fable-five-one,fable,opus,sonnet}-{medium,high,xhigh}` (full tools),
`scout-sonnet-{medium,high}` and `scout-opus-{medium,high}` (read-only) — one set per host, same names,
same bodies. Dispatch the agent named `executor-<tier>-<effort>` matching the ticket's labels. If the
matching Fable 5.1 agent is missing, fall back to `executor-fable-<effort>`; if the matching Fable
agent is missing, fall back to `executor-opus-<effort>`. If any other agent is missing, use the host's
general agent with the mapped model and effort stated in the prompt. Every substitution is said in
the wave report.

### Hosts

The names in the labels (`fable-five-one`, `fable`, `opus`, `sonnet`) and agent names are stable executor
tiers. Claude pins the named Fable generations explicitly; Codex maps the four tiers to Astra, Sol,
Terra and Luna. The labels stay the same so a map planned on one host executes on the other.
Claude Code's `CLAUDE_CODE_SUBAGENT_MODEL` or a per-invocation model override still takes precedence
over an agent file; without either override, the full Fable model IDs below do not drift with aliases.

| | Claude Code | Codex CLI |
|---|---|---|
| Highest tier (`fable-five-one`) | Fable 5.1 (`claude-fable-5-1`) at `medium` / `high` / `xhigh` | GPT-6 Astra (`gpt-6-astra`) at the same effort |
| Fable tier (`fable`) | Fable 5 (`claude-fable-5`) at `medium` / `high` / `xhigh` | GPT-5.6 Sol (`gpt-5.6-sol`) at the same effort |
| Frontier tier (`opus`) | Opus at `medium` / `high` / `xhigh` | GPT-5.6 Terra (`gpt-5.6-terra`) at the same effort |
| Mid tier (`sonnet`) | Sonnet at `medium` / `high` / `xhigh` | GPT-5.6 Luna (`gpt-5.6-luna`) at the same effort |
| Sonnet scouts (`scout-sonnet-*`) | Sonnet at `medium` / `high` | GPT-5.6 Luna (`gpt-5.6-luna`) at the same effort |
| Opus scouts (`scout-opus-*`) | Opus at `medium` / `high` | GPT-5.6 Terra (`gpt-5.6-terra`) at the same effort |
| Agent definitions | `~/.claude/agents/<name>.md` — YAML frontmatter `model`, `effort`, `tools` | `~/.codex/agents/<name>.toml` (or `.codex/agents/` in a project) — `model`, `model_reasoning_effort`, `sandbox_mode`, `developer_instructions` |
| Dispatch | `Agent` tool with `subagent_type: <name>` | `spawn_agent` naming the custom agent; `wait_agent` to collect; `followup_task` for rework on the same executor |
| Message a running executor | `SendMessage` | `send_message` |
| In-flight ceiling | the map's (default three, hard maximum five) | the map's, and never above `agents.max_concurrent_threads_per_session` in `~/.codex/config.toml` |
| Skill invocation | a slash command: the skill name after `/` | a skill mention: the skill name after `$` |
| Agent directory in the repo | `.claude/` — `worktrees/<row>/<ticket>` and `scratch/` under it | `.codex/` — the same two paths under it, inside the workspace so a `workspace-write` sandbox can write there |
| Required Matt Pocock skills | the `mattpocock-skills` plugin, invoked as `mattpocock-skills:<name>` or `/setup-matt-pocock-skills` | `$grilling`, `$domain-modeling`, and `$setup-matt-pocock-skills`, installed under the project or user `.agents/skills/` directory |
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
