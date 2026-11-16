# spec: sweep-followups v1 - borrowed working copies, ignored run paths and complete batch exits

Spec: [#24](https://github.com/jefrykurniaone/grill-to-waves/issues/24) · Map: [#29](https://github.com/jefrykurniaone/grill-to-waves/issues/29) · Tickets: [#25](https://github.com/jefrykurniaone/grill-to-waves/issues/25), [#26](https://github.com/jefrykurniaone/grill-to-waves/issues/26), [#27](https://github.com/jefrykurniaone/grill-to-waves/issues/27), [#28](https://github.com/jefrykurniaone/grill-to-waves/issues/28)

Copied 2026-11-16 onto `feat/sweep-followups`. Below this header, the body of #24 verbatim; the issue, not this file, is the spec.

---

As of 2026-11-16: written against `main` @ `e11a8e4`.

## Problem statement

The owner plans delivery runs with `/grill-to-waves` and executes them with `/orchestrate`, and with `/conduct` when a run spans several repositories. The closing consistency sweep of run `integration-branch` left three items outside that run, each true of `main` @ `e11a8e4`:

- **A paired run lets two sessions use one working copy (#18).** SESSIONS' paired-run section releases a cross-repository blocker once it is merged onto its own repository's integration branch locally and closed, "so a dependent walk can use the blocker's working copy". Released waves of different repositories run at the same time, so the blocker repository's session can be mid-wave while the dependent's walk starts or reads that repository's app. That contends with the session on the tree, the dev server and the dev database, which the invariant *one working copy, one session* forbids, and the walk can read code at an ungated merge, a sync merge or a reset rather than at a recorded green commit.
- **The tree preflight assumes the run's own paths are ignored (#19).** `/orchestrate`'s tree preflight requires an empty `git status --porcelain`, but the paths a run creates inside the repository — the worktree folder and the orchestrator's scratch folder under the host's agent directory, and a local tracker's `.scratch/` — show as untracked unless the repository ignores them, and no skill says to. In a repository without those entries the first preflight stops on a local tracker's own map, and the first preflight after a dispatch reads the worktree folder as executor leakage. This repository itself does not ignore the orchestrator's scratch folder.
- **Five gaps in `/orchestrate`'s wording (#22):**
  1. The tracker record is written "in the format of that tracker's section of TRACKERS", but that section describes mechanics, not a file layout.
  2. A refused irreversible go-ahead resets and "re-merges and re-gates the rest", which leaves out re-syncing where the dispatch preflight had synced, re-writing the spec mirrors and the tracker record the reset removed, and the runtime walk that recording green needs. The red-gate paragraph after it has the same gap.
  3. The preflight accepts `HEAD` at an awaiting batch's head while a go-ahead is pending, without saying that nothing is dispatched until the go-ahead is answered.
  4. A ticket moved to `ready-for-human` keeps its worktree, and a resuming session's reconcile then reads that worktree as an executor's lost report and may verify and merge the very work that was refused.
  5. A `writes:` breach "stops", without saying what becomes of the batch's other green tickets. *Verify* and SESSIONS' breach section share that wording.

## Solution

- A paired-run launch whose walk needs another repository's running app **declares it, and borrows that repository's working copy**: it occupies that working copy for the whole launch, so `/conduct` runs no session of that repository meanwhile, and the walk uses the working copy only at its recorded commit and writes nothing to it. A cross-repository blocker is still released long before its repository's close.
- Before it judges the tree, the orchestrator makes sure the run's own paths are ignored, through the clone's local exclude file. Nothing is committed for it.
- `/orchestrate` says what every path out of a merge batch re-runs and where the session stops, gives a ticket handed to a human a defined teardown, and writes the tracker record in a layout TRACKERS names.

## Goals and non-goals

Goals:

- *One working copy, one session* holds in a paired run too, and a cross-repository blocker is still released once it is merged locally and closed.
- A dependent walk sees another repository's code only at that repository's recorded commit.
- The first preflight in a repository with no ignore entries passes on a tree that is otherwise clean.
- Every way out of a merge batch — green, a red gate, a refused go-ahead, a breach — says what is re-run and where the session stops.
- A ticket handed to a human is never merged by a resuming session, and its work is never discarded.
- One named layout for the tracker record.

Non-goals:

- Running another repository's app from a separate checkout, a clone or a database of its own.
- Committing ignore entries to any repository.
- Changing which tickets are high-consequence, the go-ahead rule itself, or the hand-back limit.
- Moving a ticket to `ready-for-human` on a third hand-back.
- Changing what `/setup-matt-pocock-skills` writes, or this repository's own tracker record.

## User stories

1. As a planner of a paired run, I want a ticket to declare the other repository whose running app its walk needs, so that the need is in the plan rather than discovered during the walk.
2. As a planner, I want Stage 4 to carry that declaration onto the ticket's launch in the run order, so that the conductor can see it.
3. As a conductor, I want a launch to occupy its own repository and every repository it borrows, and to be ready only when no other launch in flight or held occupies any of them, so that two sessions never use one working copy at once.
4. As a conductor, I want `+ check` to print each launch's borrows, so that the owner sees why a released launch is not ready.
5. As the orchestrator of a borrowing launch, I want to walk against the other repository only when its `HEAD` is at the recorded commit its map records and its tree is clean, and to wait otherwise, so that the walk never sees ungated code.
6. As that orchestrator, I want to start the other repository's app by that repository's own runbook and stop it after the walk, writing nothing to its tracked tree and running no install, migration or seed there, so that its session finds its working copy as it left it.
7. As that orchestrator, I want an undeclared need for another repository's app, or an app that does not start at its recorded commit, to be a stop with a report, so that nothing borrows silently — including under a paired map written before this change.
8. As a run owner in a repository that does not ignore the run's paths, I want the orchestrator to add them to the clone's local exclude file before it judges the tree, and to say so in the wave report, so that the first preflight passes and nothing is committed for it.
9. As a planner who picks a local tracker, I want Stage 0 to do the same for the local tracker's folder, since planning is what creates it.
10. As an owner running `+ check`, I want the run paths that are not yet ignored reported, not written.
11. As an orchestrator writing the tracker record, I want its layout named in TRACKERS, so that every run writes the same file.
12. As an orchestrator whose go-ahead is refused, I want to reset, sync again where this wave's dispatch preflight synced, and run the batch's merges, mirrors and tracker record, gate, walk and record again without the refused tickets, so that the green point I record is complete, gated and walked.
13. As an orchestrator whose gate goes red after the last merge, I want the same re-run without the failing merge, so that the reset does not lose the mirrors or the walk.
14. As an orchestrator whose execution progress carries an `awaiting go-ahead:` line, I want to dispatch nothing until the go-ahead is answered, with `+ all` stopping on it, so that no wave is built on a commit that lacks the awaiting batch.
15. As an owner, I want a ticket moved to `ready-for-human` to have its worktree torn down and its branch kept and named, so that I have the work and no session merges it.
16. As a resuming orchestrator, I want reconcile to leave a `ready-for-human` ticket's branch alone, and to tear down a worktree of one that survived, keeping its branch.
17. As an orchestrator facing a `writes:` breach, I want to drop that ticket from the batch, take the rest of the batch to green, and stop at the end of the wave, so that one breach costs only its own ticket.
18. As a reader of the glossary, I want *Borrowed working copy* and *Tracker record* defined.
19. As the owner updating the skills, I want a changelog entry that says what changed and what a paired run already in flight meets.

## Implementation decisions

Modules touched: the `grill-to-waves` skill (its main document's Stage 0, ticket template and paired Stage 4; SESSIONS' surface block, worktrees, breach and paired-run sections; TRACKERS, a new section), the `orchestrate` skill (Stage 1's reconcile, preflight and cross-run gates, `+ check`, *Verify*, *Merge the batch*, the red-gate paragraph, *The runtime walk*, teardown and the stop rule), the `conduct` skill (launch states and `+ check`), the glossary, the README where it describes these, and the changelog. The executor agent definitions do not change: none of them carries the breach, go-ahead or teardown wording.

### Borrowed working copy (#18)

- **On the ticket**, `runtime:` accepts `peer:<folder>` entries beside `dev-server` or `dev-db`, one per repository whose running app the walk needs, the repository named by its folder as everywhere in a paired run: `runtime: dev-server, peer:payments-service`. Why there: what the orchestrator's verification needs is exactly what `runtime:` already means. A `peer:` entry never takes part in collision, since different working copies share no file.
- **On the launch**, Stage 4 carries every `peer:` entry of a launch's tickets onto that launch in the run order as a suffix: `portal · 1 · 02, 04 · borrows payments-service`, several as `borrows a, b`. A suffix, not a column, because one row holds several launches and only some of them borrow.
- **The release rule is unchanged**: a cross-repository blocker is released once it is merged onto its own repository's integration branch, locally, and closed.
- **`/conduct`'s readiness** is restated in terms of occupying. A launch occupies its own repository and every repository it borrows; it is ready when it is released, not landed, in flight or held, and no other launch in flight or held occupies a repository it occupies. The rule is symmetric — a borrower waits on the other repository's session, and that repository's next launch waits on the borrower — and a held launch keeps occupying. The current rule, "no other launch of its repository is in flight or held", is the special case of a launch that borrows nothing. The sessions-in-flight ceiling is unchanged. `+ check` prints every launch's borrows.
- **The borrowing orchestrator**, before the walk, reads the other repository's recorded commit from that repository's map through its own tracker, and checks that repository's `HEAD` equals it and its `git status --porcelain` is empty; otherwise the walk is a wait with its reason. It then starts that repository's app by that repository's own steering file or runbook, runs the walk, and stops the app. It writes nothing to that repository's tracked tree: no checkout, no `git worktree add` (which that repository's single-session guard would read as another session), no install, no code generation, no migration, no seed. Data the walk writes into that repository's dev database follows the walk's existing rules: accounts stay and are reported, other sentinel data is wiped with the wipe proven. A need for another repository's app that no `peer:` entry declares, or an app that does not start at the recorded commit, is a stop with a report.

### The run's own paths (#19)

- The paths: the worktree folder and the scratch folder under the host's agent directory — `.claude/worktrees/` and `.claude/scratch/` on Claude Code, `.codex/worktrees/` and `.codex/scratch/` on Codex — and `.scratch/` where the tracker is local.
- The rule lives once, in SESSIONS' worktrees section, and both skills point at it. `/orchestrate`'s tree preflight gains a step before the status check: each path is tested with `git check-ignore`, and every one not yet ignored is appended to the clone's local exclude file, which sits in the common git directory and so covers every worktree of the clone. The wave report says what was added. `+ check` reports the missing entries and writes nothing. `/grill-to-waves` Stage 0 does the same for `.scratch/` when it picks the local tracker.
- Why the exclude file and not a committed ignore entry: a committed entry would arrive with the first merge batch, after the first preflight had already met the untracked paths. The exclude file needs no commit and no ticket surface, and works before the integration branch exists.

### The tracker record (#22, item 1)

- TRACKERS gains a section, *The tracker record*, naming the file's layout: a title; one paragraph naming the tracker, its CLI and the repository or project (or the `.scratch/` folder), and saying that a session uses it as recorded and does not re-detect it; *Structure*, how children and blocking edges are recorded on that tracker; *Labels*, the vocabulary; *Operations*, a table of the operations pointing at that tracker's section of TRACKERS in the `grill-to-waves` skill, named rather than given as a repository path, since the skill is installed outside the repository. For any other tracker it also records how a comment is posted and what stands in for labels, the two facts TRACKERS' *Other trackers* already requires.
- `/orchestrate`'s *Merge the batch* points at that section in place of "the format of that tracker's section".
- Why not `/setup-matt-pocock-skills`' seed templates: the record governs over TRACKERS, and the local seed's layout (one `spec.md`, a `## Comments` heading) contradicts TRACKERS' local layout (numbered spec files, dated sections, `map-log.md`).

### The ways out of a merge batch (#22, items 2, 3 and 5)

- **A refused go-ahead**: reset to the recorded commit, sync again where this wave's dispatch preflight synced, swap the refused tickets' `ready-for-agent` for `ready-for-human` with a comment saying why, then run *Merge the batch* steps 2 to 5 again without them — the merges, the mirrors and the tracker record, the whole gate, the walk, then the green point or the next awaiting line.
- **A red gate after the last merge**: reset to the recorded commit, sync again where the preflight synced, and run steps 2 to 5 again without the merge it points at; that ticket is handed back.
- **While an `awaiting go-ahead:` line stands**, nothing is dispatched: the next wave would branch from a recorded commit that lacks the awaiting batch. Under `+ all` it is a stop, the go-ahead being a decision that is the user's. The preflight's acceptance of `HEAD` at the batch head serves the go-ahead question only.
- **A `writes:` breach**, whether the executor reports it or the diff shows it: swap the ticket's `ready-for-agent` for `ready-for-human`, comment the path, and drop it from the batch. The batch's other green tickets merge, gate, walk and record green as usual, the wave is torn down, and the session stops at the end of that wave, under `+ all` too. *Verify* and SESSIONS' breach section say the same thing.

### A ticket handed to a human (#22, item 4)

- The rule is keyed to the `ready-for-human` label, whatever put it there — a refused go-ahead or a breach. The ticket's worktree is torn down with the wave's, by the junction-safe procedure; its branch is kept locally and named in the ticket's comment and in the wave report.
- Stage 1's reconcile leaves a `ready-for-human` ticket's branch alone, never "inspect, salvage or delete"; a worktree of one that survived a session's death is torn down and its branch kept. The surviving-worktree rule that verifies and merges an executor's unreported result applies to `ready-for-agent` tickets only.
- A third hand-back does not change the ticket's label, and this rule does not reach it.

### Vocabulary

- **Borrowed working copy**: another repository's working copy in a paired run that a launch walks against; the launch occupies it for its duration, so no session of that repository runs meanwhile. *Avoid*: shared working copy, peer runtime.
- **Tracker record**: the file in a repository that names its tracker, so that planning and orchestration do not detect it again; the mechanics stay in TRACKERS. *Avoid*: tracker config, issue-tracker file.

### Changelog

One dated entry. Its *After updating* says to run the installer again on both hosts, and that a paired map written before this change carries no `peer:` entries or `borrows` suffixes, so a walk there that needs another repository's app is a stop until the declaration is added on the ticket and in the run order.

## Testing decisions

A good test here checks what a session reading the skills will do, not how the text is worded. These skills have no unit under test; four seams cover them:

1. **The install test** (`bash tests/test-install.sh`), every wave. It catches a broken installer and the literals it asserts in the orchestrate skill (`.codex/worktrees`, `../grill-to-waves/`, `$grill-to-waves` after the Codex rewrite), which must survive. It cannot catch a contradiction between rules.
2. **The consistency sweep**, at the close: a grep for the replaced wording ("use the blocker's working copy", "in the format of that tracker's section", "no other launch of its repository", "re-merge and re-gate the rest"), then one read-only analyst reading the changed skills end to end as a solo session and as a paired session would. It catches contradictions and dangling references; it cannot catch behaviour only a real run shows.
3. **CI on the run's draft review request**: the docs check (no tier named with a version number, agent frontmatter that YAML reads), shellcheck, PSScriptAnalyzer and the Windows install tests. `pwsh` and `shellcheck` are not on the planning machine, so CI is where those run. It cannot catch what a rule means.
4. **A sandbox run, the owner's, after the close**: for #19, a repository with no ignore entries; a borrow needs two repositories and is the owner's to try.

Prior art: the previous run's map and its consistency sweep (seam 2) and CI (seam 3).

## Success criteria

- No skill text lets a dependent walk use another repository's working copy except by borrowing it; SESSIONS' paired-run section, `/orchestrate`'s cross-run gates and walk, and `/conduct`'s launch states agree on borrowing and occupying.
- The ticket template and SESSIONS' surface block define `peer:<folder>` in `runtime:`, and the paired Stage 4 defines the `· borrows` suffix.
- `/conduct`'s readiness is stated in terms of occupying, and its `+ check` prints borrows.
- SESSIONS owns the run-paths rule; `/orchestrate`'s preflight applies it before the status check and `+ check` reports it; `/grill-to-waves` Stage 0 applies it to `.scratch/` for a local tracker.
- TRACKERS has *The tracker record*, and `/orchestrate` points at it.
- A refused go-ahead and a red gate both say to sync again where synced and to run steps 2 to 5 again.
- An `awaiting go-ahead:` line blocks dispatch, and `+ all` stops on it.
- A `ready-for-human` ticket's worktree is torn down and its branch kept and named; reconcile leaves that branch alone.
- A breach drops its ticket, the rest of the batch goes green, and the session stops at the end of the wave; *Verify* and SESSIONS agree.
- The glossary defines both terms; the changelog has the entry.
- The install test passes; CI is green on the draft review request; the consistency sweep reports no contradiction.

## Out of scope

- Running another repository's app from a separate checkout, a clone or a database of its own.
- Committing ignore entries to any repository.
- The go-ahead rule itself, which tickets are high-consequence, the hand-back limit, and a third hand-back's label.
- Executor tiers, the effort ladder, the agent set and the agent definitions; `/ship-it-to`.
- The format `/setup-matt-pocock-skills` writes, and this repository's own tracker record.
- Trying a borrow across two real repositories: the owner's, after the close.

## Further notes

The source is #18, #19 and #22, filed by the closing consistency sweep of run `integration-branch` (map #16, spec #11), and the owner's grilling of 2026-11-16, which chose option 2 of #18 in the borrowing form above. Those three issues do not carry this run's label; the run's review request names them to close on merge.
