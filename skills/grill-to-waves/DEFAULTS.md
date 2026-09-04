# Orchestration defaults

The model, effort and worktree rules both skills read. It travels with the skill, so a repository
needs no per-machine setup to run the pipeline. Where a repository or a user's own memory file states
something narrower, that wins — this file is the floor, not a ceiling.

## Model and effort

- **Executors: the frontier model or the mid-tier model only. Never the small/cheap tier.** The
  frontier model (Opus) for hard tickets, the mid tier (Sonnet) for easy ones, following the ticket's
  `executor:` label where one exists.
- **Executor reasoning effort: `medium`, `high` or `xhigh`. Never `low`.** Follow the ticket's
  `effort:` label; default `high` when unlabelled. Two things set the level at ticketing time — how
  much the executor must *explore* before it can edit, and how many *decisions* it makes alone.
- **The orchestrator and the verifier run on the most capable model available.** Verification of
  executor output is the orchestrator's job, never delegated to the model that produced the work.

### The effort ladder

| Level | Use when | Typical pairing |
|---|---|---|
| `medium` | The target is fully specified upstream and the exploration is narrow: the files are named or trivially found, the edit is mechanical, and no decision is left to make — a rename, a dead column removed at enumerated sites, a copy change, a docs mirror, a restyle onto a settled component. | Sonnet `medium` |
| `high` | **The default.** Judgment inside a bounded scope: a new surface on an existing seam, a route or form change, a multi-file feature whose decisions were made upstream but whose *placement* needs reading breadth, any ticket that must discover its own call sites. | Sonnet `high` when the decisions were all made upstream; Opus `high` when the executor decides anything a later ticket builds on |
| `xhigh` | Judgment *is* the work, and a wrong decision propagates or loses data: anything touching money, capacity, stored enums, migrations that need a correctness argument, concurrency or row locks, a component seam several surfaces will compose, security boundaries, adversarial verification of subtle behaviour. | Opus `xhigh` (Sonnet `xhigh` is legal but rarely the right call) |

Two axes, read together: **exploration need** (must the agent sweep many files, naming conventions or
runtime behaviour before editing?) and **task complexity** (how many decisions does it make alone,
and how far do they propagate?). Low on both → `medium`. High on either → `high`. Decisions that
propagate or can lose data → `xhigh`, regardless of exploration. Never pick a level to save tokens on
a ticket where the decisions are the deliverable; never pick `xhigh` for a mechanical edit — it does
not make a rename more correct.

### Scouts

Read-only sub-agents (fact-finding, code location, analysis) follow the same tiering. Always pass the
model and effort explicitly rather than inheriting:

- **Locate a known symbol or file** (one grep, one read, cite `path:line`): `scout-sonnet-medium`.
- **Sweep many locations or naming conventions** (map a directory, list every caller, find where
  something lives when the name is unknown): `scout-sonnet-high`.
- **Analyse, judge or audit inside the sub-agent** (root-cause analysis, security sweep, reviewing a
  diff for defects): `scout-opus-high`.
- **Adversarially verify subtle behaviour** (prove a race, a data-loss path, a money rule): dispatch
  an `executor-opus-xhigh` brief that writes nothing, or do it in the orchestrator session.

### How effort is applied

Claude Code's `Agent` tool has a `model` override but no effort parameter; effort comes from the agent
definition's frontmatter. The definitions this repo installs are
`executor-{sonnet,opus}-{medium,high,xhigh}` (full tools) and `scout-sonnet-medium`,
`scout-sonnet-high`, `scout-opus-high` (read-only). Dispatch with
`subagent_type: executor-<model>-<effort>` matching the ticket's labels. If a type is missing, fall
back to `general-purpose` with `model` set and the effort level stated in the prompt, and say so in
the wave report.

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
