# spec: stalls-and-exits v1 - stalled launches, the borrow check and the remaining ways out of a merge batch

Spec: [#37](https://github.com/jefrykurniaone/grill-to-waves/issues/37) · Map: [#44](https://github.com/jefrykurniaone/grill-to-waves/issues/44) · Tickets: [#38](https://github.com/jefrykurniaone/grill-to-waves/issues/38), [#39](https://github.com/jefrykurniaone/grill-to-waves/issues/39), [#40](https://github.com/jefrykurniaone/grill-to-waves/issues/40), [#41](https://github.com/jefrykurniaone/grill-to-waves/issues/41), [#42](https://github.com/jefrykurniaone/grill-to-waves/issues/42), [#43](https://github.com/jefrykurniaone/grill-to-waves/issues/43), [#46](https://github.com/jefrykurniaone/grill-to-waves/issues/46), [#47](https://github.com/jefrykurniaone/grill-to-waves/issues/47), [#48](https://github.com/jefrykurniaone/grill-to-waves/issues/48)

Copied 2026-11-16 onto `feat/stalls-and-exits`, and regenerated from #37 at the run's close on 2026-11-17. Below this header, the body of #37 verbatim; the issue, not this file, is the spec.

---

As of 2026-11-16: written against `main` @ `7caebdf`.

## Problem statement

The owner plans delivery runs with `/grill-to-waves` and executes them with `/orchestrate`, and with `/conduct` when a run spans several repositories. The closing consistency sweep of run `sweep-followups` (map #29, spec #24) and the sandbox run after its close left five items, each true of `main` @ `7caebdf`:

- **A borrowed walk can stall the conductor, and a live lender goes undetected (#31).** A borrower checks only the lender's `HEAD` against its recorded commit and an empty `git status`. When the lender's session has died mid-batch, `/conduct` reads its pane as no session, the borrower goes first, its walk waits, it is held, and a held launch keeps occupying the lender — so the lender's relaunch, the one thing that would fix its `HEAD`, is never ready, and nothing says how to get out. The same stall follows a lender that loses its pane while awaiting a go-ahead, a lender with no cut yet (there is no recorded commit to compare with), and a lender after a no-forge *merged* close (`HEAD` on its base). A lender session live outside the schedule passes both checks, since its executors work in ignored worktrees. A session that dies mid-walk leaves the lender's app running and the walk's sentinel data in its dev database, and nothing re-checks the lender's tree after the walk.
- **A launch holding a ticket that will not close never lands, and a third hand-back reads as a crash leftover (#32).** `/conduct` holds a launch that ends `orchestrate: done` with a ticket still open "until that session works again"; a `ready-for-human` ticket stays open whatever that session does, so the launch is held again, and with borrowing every launch that borrows its repository stalls too. A third hand-back changes no label, so the next session's reconcile reads the surviving worktree as an executor's lost report and verifies and merges it, bypassing the decision SESSIONS hands to the user. And `/conduct` does not keep one repository's waves in order: a later wave whose row lists only cross-repository blockers can launch before an earlier one.
- **A refused irreversible go-ahead re-walks against a dev database that still holds the refused ticket's effects (#33).** The reset undoes the code, not what the ticket did to the dev database during the batch's first walk, so the re-run's walk can pass or fail for reasons the batch's code no longer explains.
- **Ways out of a merge batch are still unstated, and the other-tracker record is unreachable (#34).** A merge conflict at *Merge the batch* step 2 that is not append-plus-append has no path; a failed row of a pinned check names no ticket to drop; and three passages say three different things about when the red gate's stripping ends. The glossary says a tracker record leaves the mechanics to TRACKERS, while an other tracker's record must describe them in prose, and `/orchestrate` is told to write that record from the map although planning never detects such a tracker.
- **The integration branch's cut tracks the base (#36).** Cut from `origin/<base>`, the branch gets the base as its upstream under git's default, so `git status` reads "ahead of origin/<base>", a bare `git pull` merges the base outside the protocol's sync, and under `push.default=upstream` a bare `git push` lands the integration branch on the base before the close.

## Solution

- `/conduct` runs one **borrow check** before a borrowing launch goes, the same check the borrower runs before its walk, so a borrower never starts against a lender its own schedule has left mid-batch, and a lender's own relaunch is what goes first. The check knows a lender with no cut yet and a lender whose run has closed, and reads the lender's registered worktrees, which is where a live wave shows. A borrowed walk that dies mid-way is cleaned up by the next session, and the lender's tree is re-read after every walk.
- A third hand-back hands the ticket to a human, like a breach. `/conduct` gains a **parked** launch state for a launch whose open tickets wait on the owner, with three stated ways out, and it keeps one repository's launches in their run-order steps.
- A refused go-ahead — and a failed walk row of an irreversible ticket — settles with the owner how the dev database is brought back before the re-run's walk, and records the answer before the reset.
- Every way out of a merge batch says what happens: a conflict the orchestrator cannot attribute drops its ticket and hands it back; a failed pinned check is attributed like a red gate or is a stop; the red gate's stripping follows one rule. An other tracker's record is the owner's to write, and the glossary says so.
- The integration branch is cut without an upstream, and a branch cut before the fix loses its upstream at the next preflight.

## Goals and non-goals

Goals:

- No paired run reaches a state where nothing is in flight, nothing is ready and nothing says how to get out; every stop names what clears it and who.
- A borrower walks only against a lender that is at a gated or base commit, clean, and free of any live wave.
- A borrowed walk leaves the lender as it found it, or the session that follows says what it could not restore.
- A ticket that has failed three times is never merged by a resuming session, and its work is kept for the human.
- One repository's launches go in run-order step order.
- The re-run's walk after a dropped irreversible ticket runs against a dev database the owner has ruled on.
- Every way out of a merge batch — green, a red gate, a non-append conflict, a failed pinned check, a refused go-ahead, a breach, a third hand-back — says what is re-run and where the session stops.
- The integration branch has no upstream before the close.

Non-goals:

- Detecting or asking for an other tracker (Jira, Linear) at planning's Stage 0.
- Snapshotting or restoring the dev database automatically before a walk.
- Detecting an owner's session in a lender that runs outside herdr and makes no worktree; it is a stated residual risk.
- Changing the go-ahead rule, which tickets are high-consequence, or the hand-back limit of two.
- Changing the run order's format: *Released by* still names cross-repository blockers only.
- Changing any agent definition.

## User stories

1. As a conductor, I want a borrowing launch to be ready only when every lender passes the borrow check, so that I never start a borrower whose walk can only wait.
2. As a conductor, I want a lender whose session died mid-batch to be relaunched before its borrower, so that its own Stage 1 brings `HEAD` back to its recorded commit.
3. As a conductor whose borrower waits on a lender no scheduled launch will fix, I want the report to name the lender, the condition that failed and that the owner clears it, so that the run does not end silent.
4. As a borrowing orchestrator, I want the borrow check to accept a lender with no cut yet at its base as last fetched, and a lender whose map has closed at any clean commit holding its last green point, so that those lenders can be borrowed at all.
5. As a borrowing orchestrator, I want a registered worktree in the lender other than its main working copy to fail the check, so that a wave launched outside the schedule is seen.
6. As a borrowing orchestrator whose check fails at walk time, I want that to be a stop with a report, because the schedule kept every scheduled session out and the cause is outside it.
7. As a resuming orchestrator, I want a borrow that died mid-walk to be visible in my map's execution progress, so that I stop the lender's app it left running and report the sentinel data it may have left.
8. As a borrowing orchestrator, I want the lender's tree re-read once its app is stopped, and only what is provably the app's rewrite restored, so that the lender's own next preflight does not read my walk's leftovers as executor leakage.
9. As an orchestrator whose ticket fails a third time, I want it moved to `ready-for-human` and handled as a breach is, so that its branch is kept for the human and no later session merges it.
10. As a conductor, I want a launch whose open tickets all wait on the owner to be parked, keeping its own repository and releasing what it borrowed, so that it neither loops as held nor lets later waves build past an unreplanned ticket.
11. As an owner, I want three stated ways out of a parked launch — re-label, close, or tell the conductor to go on — so that I know what to do.
12. As a conductor, I want a launch to wait for every launch of its own repository in an earlier step, so that one repository's waves run in order.
13. As an owner refusing an irreversible go-ahead, I want the same exchange to settle how the dev database is brought back before the re-run's walk, so that the walk I am shown means something.
14. As an orchestrator dropping an irreversible ticket after a failed walk row, I want to ask the owner the same question before the re-run's walk.
15. As a resuming orchestrator, I want that answer on the map's execution progress until the re-run is recorded green, so that I do not walk without it.
16. As an orchestrator meeting a merge conflict I cannot attribute, I want to abort it, drop the ticket, finish the batch and hand the ticket back to rebase onto the new green commit, so that one conflict costs one ticket.
17. As an orchestrator whose pinned check fails, I want to attribute it as a red whole gate is attributed, and to stop when it points at no ticket, so that a check with no ticket of its own still has a path.
18. As an orchestrator on the red gate's path, I want one rule for when the stripping ends, so that the stop rule, the integration branch section and the red-gate paragraph agree.
19. As an owner using Jira or Linear, I want to know that the tracker record is mine to write before the run, so that no session waits on a detection that never happens.
20. As an orchestrator, I want the integration branch cut without an upstream, and an upstream left by an older cut removed, so that a bare pull or push cannot reach the base.
21. As a reader of the glossary, I want *Lender* defined and *Tracker record* accurate for every tracker.
22. As the owner updating the skills, I want a changelog entry that says what changed and what a run already in flight meets.

## Implementation decisions

Modules touched: the `orchestrate` skill (Stage 1's git ground truth and resume, the tree preflight, `+ check`, *The integration branch*, *Merge the batch* and its red-gate and reset paragraphs, *The runtime walk*'s borrowed working copy, *Record, close, tear down*, the close order, the stop rule), the `conduct` skill (launch states, readiness, `+ check`, the wake and stop reports), the `grill-to-waves` skill (SESSIONS' breach and paired-run sections; TRACKERS' *Other trackers* and *The tracker record*; the main document's hand-started launch lines), the glossary, the README where it describes these, and the changelog. No agent definition changes: the conflict hand-back below is a rebase of the executor's own ticket branch, which the definitions' "never merge, never touch the integration branch or the base branch" already allows. No step or section is renumbered; every existing reference must still land.

### The integration branch's cut (#36)

- The cut becomes `git switch --no-track -c <integration branch> origin/<base>`. Why: git's default `branch.autoSetupMerge` gives a branch started from a remote-tracking branch that branch as its upstream; `--no-track` also covers `autoSetupMerge=always` and the no-remote case, where `origin/<base>` reads as the local base.
- **Before the close the integration branch has no upstream.** Stage 1's git ground truth reads it; the tree preflight, in an existing step, unsets any upstream other than `origin/<integration branch>` and names it in the wave report; `+ check` reports it and writes nothing. After the close's `git push -u`, `origin/<integration branch>` is its upstream, and a resumed close leaves that alone. Why at the preflight: a run in flight was cut by the old rule, and the preflight is the one place every session passes.

### A third hand-back hands the ticket to a human (#32)

- The third failure of a ticket swaps its `ready-for-agent` for `ready-for-human` and posts on it the findings that failed it. It is then handled exactly as a `writes:` breach: dropped from the batch, the batch's other green tickets merge, gate, walk and record green, the wave is torn down — its worktree by the `ready-for-human` teardown, uncommitted work committed as one work-in-progress commit and its branch kept and named — and the session stops at the end of that wave, under `+ all` too.
- Every hand-back counts toward the two, the conflict hand-back below included.
- Why: the label is what the reconcile, the teardown and `/conduct` read. Without it the next session's reconcile reads the surviving worktree as an executor's lost report. This reverses #24's non-goal "a third hand-back's label".
- SESSIONS' breach section and `/orchestrate`'s stop rule, rework paragraph and outcome-line examples say the same.

### Parked launches and wave order in `/conduct` (#32)

- **A new launch state, parked.** A launch is **parked** when its session's turn has ended on `orchestrate: done` or `orchestrate: stopped — …`, and every ticket it names that is still open carries `ready-for-human` or waits on an open blocker. A turn that ended with no outcome line stays held, as now.
- **A parked launch occupies its own repository and nothing else.** Keeping its own repository matches the solo session's stop at the end of a breach's wave: the owner re-plans before that repository builds further. Releasing what it borrowed is safe because its walk is over. Its session is free: nothing is pending in it, so its slot may be reused, and it does not count toward the sessions in flight.
- **Three ways out, stated wherever a parked launch is reported** (`+ check`, the wake report and the stop report), with each `ready-for-human` ticket and its kept branch:
  1. The owner re-plans and re-labels the ticket `ready-for-agent`: the launch is no longer parked, so it is ready again by the usual rule and is relaunched, and its orchestrator's reconcile deals with the kept branch as it does today.
  2. The owner closes the ticket: the launch lands.
  3. The owner tells the conductor to go on without it: the launch counts as landed for occupying and for wave order, for this conductor session only — after a context clear the conductor asks again, as it does for go-aheads. The ticket stays `ready-for-human` and still blocks whatever its edges block.
- **Wave order.** A launch is ready only when, besides today's conditions, every launch of its own repository in an earlier run-order step has landed, or is parked and the owner said to go on. Why at runtime rather than in *Released by*: maps already planned need no edit, and *Released by* keeps naming cross-repository blockers only.
- The hand-started launch lines `/grill-to-waves` Stage 6 prints say the same: wait for the repository's earlier steps, and for the borrow check below.

### The borrow check (#31)

- **One check, defined once in SESSIONS' paired-run section**, run by `/conduct` when it computes readiness and by the borrowing orchestrator before its walk. It is reads only (`git -C ../<folder>` and the lender's map through its own tracker). A lender passes when all of these hold:
  1. Its `git status --porcelain` is empty. _(Delivered otherwise; see Delivery notes.)_
  2. `git worktree list` shows no registered worktree besides its main working copy — the single-session guard's own read: a registered worktree is a live session or its leftover, and either is the lender's own business first.
  3. Its `HEAD` is where its map says it may be:
     - **map open, cut recorded**: `HEAD` equals its recorded commit;
     - **map closed**: `HEAD` holds its last recorded commit (an ancestor of or equal to `HEAD`), which covers a no-forge *merged* close whose `HEAD` is on the base;
     - **no cut recorded yet**: `HEAD` equals that clone's `origin/<base>` as last fetched, the base its map names — the local base where there is no remote. The borrower fetches nothing there.
- **`/conduct`'s readiness**: a launch that borrows is ready only when every lender passes. A lender that fails makes its borrower not ready, and the report names the lender and the condition that failed. The lender's own launch goes by its own state — a session that died mid-batch reads as no session, so its launch is ready and is relaunched, and its Stage 1 resets `HEAD`; one awaiting a go-ahead is held on the owner. Where no launch of the lender is ready, in flight or held, nothing scheduled will fix it, and the report says the borrower waits on the owner. Under `+ watch` that ends in the stop report like any other nothing-ready state.
- **The borrower's own check** keeps its place before the walk, now as the full check. Because the conductor saw the lender pass and occupancy has kept every scheduled session out since, a failure there means something outside the schedule touched the lender: it is a stop with a report naming the lender and the condition, and the owner clears it and tells the borrower to go on. Why no new outcome line: a stop already holds the launch, and the cause is the owner's to clear.
- **Residual risk, stated in SESSIONS**: an owner's own session in a lender that makes no worktree is seen only by `/conduct`'s pane read, and not at all outside herdr.

### Leftovers of a borrowed walk (#31)

- **Write-through of the borrow.** Before starting a lender's app, the borrower adds `borrowing <folder> since <time>` to its own map's execution progress, and removes it once the app is stopped, the sentinel data wiped and the lender's tree re-read. A resuming session that finds the line knows a borrowed walk died mid-way: it checks whether the lender's app still runs, by that repository's runbook (its port or health URL), stops it the way the runbook says or reports that it cannot, re-reads the lender's tree as below, reports the walk's accounts and sentinel data as possibly left in the lender's dev database — the walker's report died with it — and then removes the line. _(Delivered otherwise; see Delivery notes.)_
- **The lender's tree after the walk.** Once the app is stopped, the borrower reads the lender's `git status --porcelain` again; the borrow check found it empty. What it shows is restored only where it is provably the app's own rewrite — read first, the way executor leakage is read — and every restored path is named in the wave report. Anything it cannot attribute to the app is a stop with a report, never discarded unread. Restoring the lender's tree to the state the check found it in is the one write the borrower makes there.

### The dev database after a dropped irreversible ticket (#33)

- **When it applies**: a reset that drops an irreversible ticket after the batch's walk has run — a refused go-ahead, or a failed walk row that points at an irreversible ticket. A red fast gate or a red whole gate drops before any walk, so the dev database holds nothing of the batch. _(Delivered otherwise; see Delivery notes.)_
- **The owner's answer, one of three**: (i) the owner restores the dev database and says so; (ii) the orchestrator resets or re-seeds it by the repository's runbook — offered only where the runbook names how; (iii) the re-run's walk runs against it as it is, and the walk's table says it ran against a dev database holding that ticket's effects.
- **A refusal carries it**: the go-ahead question, which already names what a reset will not undo, asks in the same exchange which of the three applies should the owner refuse. **A failed walk row** of an irreversible ticket asks it before the re-run's walk; it is a decision that is the user's, so `+ all` stops on it.
- **Write-through**: the answer is posted on the dropped ticket's comment, and the map's execution progress carries `dev database: holds the effects of #<n>[, #<m>] — <answer>` from before the reset until the re-run records green, so a resuming session reads it before its walk. A line with no answer yet is asked again.

### The ways out of a merge batch (#34)

- **A merge conflict at step 2.** A conflict whose two sides the orchestrator can attribute and whose resolution needs no product decision — append-plus-append among them, the same test the sync from the base applies — is resolved and named in the wave report. Any other: `git merge --abort`, which returns `HEAD` to the batch's previous merge; the ticket is dropped from the batch; the batch goes on with its other branches, with no reset. Once the batch records green, the ticket is handed back to its executor: rebase its own ticket branch onto the new recorded commit in its worktree, resolve, and run the gate; a resolution that needs a product decision is `git rebase --abort` and the executor's stop-and-report. Why a rebase: the ticket branch is local and never pushed, so rewriting it publishes nothing, and the executor definitions forbid merging; the protocol's "never a rebase" governs the integration branch, which this does not touch. The hand-back counts as one of the two. Why a conflict reaches step 2 at all: worktrees branch from the recorded commit, never from the sync merge the dispatch preflight made, so a base change in a ticket's file meets that ticket only here.
- **A failed row of a pinned check at step 4** is attributed as a red whole gate is: the orchestrator reads what the check measures against the batch's diffs. Where it points at one ticket merge, the red gate's path without that ticket. Where it points at no ticket merge of the batch — the sync from the base, or a state the recorded commit already held — it is a stop with a report, the defect filed as its own item, and no green point is recorded. **At the close**, a failed check pinned to the close is filed as its own item and is a stop before the push; the owner decides whether the run takes a ticket for it.
- **When the red gate's stripping ends — one rule**, stated in *Merge the batch* and pointed at by the stop rule and *The integration branch*: each reset and re-run drops the ticket the failure is attributed to, and handing it back counts. It repeats while each failure points at a ticket merge still in the batch. It ends on green, or on a failure that points at no ticket merge — a stop with a report, because no ticket owns the fix. No count caps it: the attribution is the bound, and every drop spends one of that ticket's hand-backs.

### The tracker record for an other tracker (#34)

- Planning's Stage 0 detects only GitHub, GitLab and a local tracker. An other tracker is used only where the repository's tracker record already names it, written by the owner, or by `/setup-matt-pocock-skills`, before the run.
- `/orchestrate` writes the tracker record from the map only for a tracker Stage 0 detected.
- TRACKERS' *Other trackers* says the record must exist before planning; *The tracker record*'s paragraph on other trackers is the layout the owner writes by hand.

### Vocabulary

- **Lender**: the repository of a paired run whose working copy a launch borrows; while the borrow lasts no session of its own runs, and the borrower walks it only where the borrow check passes. *Avoid*: peer repository, host repository.
- **Tracker record**, amended: the file in a repository that names its tracker, so that planning and orchestration do not detect it again; the mechanics stay in TRACKERS, except for a tracker TRACKERS has no commands for, whose record describes them in prose.
- **Parked** is a launch state defined in `/conduct` beside landed, released, in flight, held and ready, and gets no glossary entry, as those have none.

### Changelog

One dated entry. Its *After updating* says to run the installer again on both hosts, and what a run already in flight meets: an integration branch cut before this change has the base as its upstream until the next preflight removes it; a ticket stopped on a third hand-back before this change carries no label, so label it `ready-for-human` by hand before the next session, or its reconcile reads the worktree as a lost report; a paired run's held launches are re-read as parked where they qualify.

## Testing decisions

A good test here checks what a session reading the skills will do, not how the text is worded. These skills have no unit under test; four seams cover them:

1. **The install test** (`bash tests/test-install.sh`), every wave. It catches a broken installer and the literals it asserts in the orchestrate skill (`.codex/worktrees`, `../grill-to-waves/`, and `$grill-to-waves` after the Codex rewrite), which must survive. It cannot catch a contradiction between rules.
2. **The consistency sweep**, at the close: a grep for the replaced wording ("`git switch -c <integration branch>`", "A third hand-back changes no label", "until that session works again", "a gate that stays red after the reset", "the walk is a wait with its reason"), a check that every `§` and numbered-step reference still lands, then one read-only analyst reading the changed skills end to end as a solo session and as a paired session would. It catches contradictions and dangling references; it cannot catch behaviour only a real run shows.
3. **CI on the run's draft review request**: the docs check (no tier named with a version number, agent frontmatter YAML reads), shellcheck, PSScriptAnalyzer and the Windows install tests, which this machine cannot run. It cannot catch what a rule means.
4. **A sandbox run, the owner's, after the close**: two throwaway repositories under `/conduct + check`, with a lender left mid-batch so its borrower reads as not ready, a parked launch, and a fresh cut with no upstream (`git rev-parse @{u}` fails).

Prior art: the previous runs' maps (#16, #29), their consistency sweeps (seam 2) and CI (seam 3).

## Success criteria

- SESSIONS defines the borrow check once; `/conduct`'s readiness and `/orchestrate`'s borrowed walk both use it, and it covers a lender with no cut and a closed lender.
- `/conduct` defines parked, its occupying and its three ways out, keeps one repository's launches in step order, and `+ check` and its reports name parked launches with their tickets and kept branches.
- No state of `/conduct` leaves nothing in flight and nothing ready without a report naming what clears it and who.
- A borrowed walk is written through on the borrower's map, and a resume that finds it stops the lender's app and reports what may be left; the lender's tree is re-read after every walk.
- A third hand-back moves the ticket to `ready-for-human` and is handled as a breach; SESSIONS and `/orchestrate` agree, and no text still says it changes no label.
- A refused go-ahead and a failed walk row of an irreversible ticket settle the dev database with the owner, and the answer is on the execution progress until the re-run is green.
- *Merge the batch* states the non-append conflict, the failed pinned check and one red-gate stripping rule; the stop rule and *The integration branch* point at it.
- The integration branch is cut with `--no-track`, and the preflight removes an upstream left by an older cut.
- TRACKERS and `/orchestrate` agree that an other tracker's record is the owner's; the glossary defines *Lender* and its *Tracker record* holds for every tracker.
- The install test passes; CI is green on the draft review request; the consistency sweep reports no contradiction.

## Out of scope

- Detecting or asking for an other tracker at planning's Stage 0.
- Snapshotting or restoring the dev database automatically.
- Detecting an owner's session in a lender outside herdr when it makes no worktree.
- The go-ahead rule itself, which tickets are high-consequence, and the hand-back limit.
- The run order's format.
- Executor tiers, the effort ladder, the agent set and the agent definitions; `/ship-it-to`.
- The sandbox run: the owner's, after the close.

## Further notes

The source is #31, #32, #33 and #34, filed by the closing consistency sweep of run `sweep-followups` (map #29, spec #24), and #36, found by the sandbox run after that close, together with the owner's grilling of 2026-11-16. Those five issues do not carry this run's label; the run's review request names them to close on merge.

This spec reverses one non-goal of #24: a third hand-back now moves its ticket to `ready-for-human`.

## Delivery notes

This spec was delivered on 2026-11-17 by run `stalls-and-exits` (map #44), on `feat/stalls-and-exits`. That branch was cut at `7caebdf` from `origin/main` with `--no-track` and went to `main` in one draft pull request, opened at the run's close.

| Ticket | Merge on `feat/stalls-and-exits` | Executor | Second verification |
| --- | --- | --- | --- |
| #38 The borrow check, and a borrowed walk that cleans up after itself | `fbc590f` | Opus, `high`, re-graded to Fable, `high`, for an open decision; one hand-back | Fable, read-only, adversarial clause: two must-fix findings, closed on a delta re-read |
| #39 Parked launches and wave order in `/conduct` | `d8d0f56` | Opus, `high` | — |
| #40 The remaining ways out of a merge batch, and a third hand-back hands the ticket to a human | `3a52100` | Opus, `high` | — |
| #41 The dev database after a dropped irreversible ticket | `936e3b7` | Opus, `high` | — |
| #42 The cut has no upstream, and an other tracker's record is the owner's | `6d6fadf` | Sonnet, `medium`, one hand-back | — |
| #46 Count hand-backs on the map, give a declined close check a way out, and keep the guard's stop from cleaning up (added at the close) | `681e0e7` | Opus, `high` | — (the sweep's reader re-read its delta) |
| #47 Make `/conduct`'s done, parked and borrow-check reports agree, and count parked in hand-started launches (added at the close) | `fc1f5fc` | Sonnet, `high` | — (the sweep's reader re-read its delta) |
| #43 Changelog entry and README | `9f4919b` | Sonnet, `medium`, one hand-back | — |
| #48 Let the owner's go-on reach a hand-started launch's occupying, and hold a resent rework behind a pending go-ahead or dev database answer (added at the close) | `e2a4ff9` | Sonnet, `high` | — (the orchestrator read its delta) |

This spec's mirror was committed in wave 1's batch as `5055f62`.

**Claims in this body that delivery reversed.** They are marked here and left in place above:

- *Leftovers of a borrowed walk*, "stops it the way the runbook says or reports that it cannot … and then removes the line". As delivered, an app that cannot be stopped is a stop that **keeps** the line, and the owner clears it. The same goes for a path that cannot be attributed. Removing the line would hand the lender back to its own session while a stray dev server still runs there (#38, decided at the Fable tier).
- *The borrow check*, condition 1, "Its `git status --porcelain` is empty". As delivered it is `git --no-optional-locks -C ../<folder> status --porcelain`. This keeps the conductor's recurring read off the lender's index lock while a merge is under way there. The conductor runs the reads from its own folder as `git -C <folder>` (#38).
- *The dev database after a dropped irreversible ticket*, "When it applies". As delivered it also covers a red fast or whole gate in a re-run after such a walk, when that gate drops an irreversible ticket (#41).

**Decisions made in delivery that this spec did not settle:**

- **A borrow outlives its session.** A `borrowing <folder>` line on any map holds that lender against every launch except the line's own repository's, whatever that map's session is doing. That repository's next launch clears the line in its Stage 1, and only the borrow check's first condition is waived for it. The cleanup runs once the single-session guard has cleared, never on the guard's own stop. A map that cannot be read holds its lenders as if it carried the line (#38, #46, #47).
- **A read that keeps failing fails its borrow-check condition** and never passes it (#38).
- **Let out of parking.** A re-label, or a close that unblocks another ticket, frees a parked launch's turn. A launch with no session of its own, which is released and in wave order, is parked on its ticket condition alone (#39).
- **One stripping rule.** A red whole gate is attributed by reading its failures against the batch's diffs. The re-run leaves out every ticket dropped so far (#40).
- **Hand-backs are written through.** Each one goes on the map's execution progress as `hand-back: #<n> <k> of 2 @ <sha> — <finding>`, and the sha marks where the rework's commits start. A failed check pinned to the close can be waived by the owner and is recorded as `waived:`. The upstream is read with `git for-each-ref` (#46).
- **`/conduct`'s reports agree.** `done` reads the same in every stage, and a parked launch's stop report is relayed. A hand-started launch counts a parked launch as occupying its own repository, and stops counting it once the owner goes on without it (#47, #48).
- **A resent rework waits** while an `awaiting go-ahead:` line or an unanswered `dev database:` line stands. A `hand-back:` line goes once its ticket is recorded green or carries `ready-for-human` (#48).

**Filed outside this run:** #45, the single-session guard does not see a live second session of the same run between waves or at the close.

**Observations from the consistency sweep, left as they are:**

- TRACKERS says both "by hand" and `/setup-matt-pocock-skills` for who writes an other tracker's record.
- The red-gate paragraph's "unless this is its third failure:" can be misparsed.
- Stage 6's hand-started wording on a held lender is clear only through the SESSIONS link.
- A parked launch let out by the owner's close reads as held after a context clear.
- A `waived:` line is not read on resume, so a close resumed before step 6 re-walks the waived check.
- A conflict drop leaves no merge to say which batch it was dropped from, and a conflict rework that died mid-rebase is re-sent into a worktree that still has a rebase in progress.
- A parked session's slot may be reused although its relayed stop report says the user may answer in that tab.
- The map body is edited mid-batch for the `hand-back:` and `awaiting go-ahead:` lines, which sits uneasily with SESSIONS' "only on a quiescent tree". This predates the run.

**Seams:**

1. The install test: green at every wave, on every merge, and on every ticket branch: 11 passed, 1 skipped for want of `pwsh`.
2. The consistency sweep:
   - The leftovers grep and the `§`, step and section references were clean.
   - One read-only analyst read the skills end to end. Its eight must-fix findings were fixed by #46 and #47.
   - The same analyst read that delta again. All eight were closed, and it found two contradictions the fixes had introduced. #48 fixed those, and the orchestrator read #48's delta.
3. CI on the draft pull request: its result is recorded on the map, #44.
4. The sandbox run is the owner's, after the close.
