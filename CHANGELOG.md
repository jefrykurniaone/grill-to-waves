# Changelog

What changed in the pipeline's rules and agent set, newest first. The repository carries no version
tags, so entries are dated. Tiers are named by alias only, as everywhere else in this repository.

## 2026-11-17 — Parked launches, complete merge-batch exits and a clean cut

A paired run no longer holds a launch whose tickets went to a human: it parks the launch and says
how it ends. A borrowed working copy is checked before it is used and stays lent after its
borrower's session dies. A merge conflict, a failed pinned check and a third failed hand-back each
take a path, a dropped irreversible ticket settles the dev database with the owner, and the
integration branch is cut without the base as its upstream.

### After updating

Run the installer again on both hosts (`./install.ps1 -Target both` or `./install.sh --target both`).
An integration branch cut before this change has the base as its upstream until the next preflight
removes it. A ticket stopped on a third hand-back before this change carries no label, so label it
`ready-for-human` by hand before the next session, or its reconcile reads the worktree as a lost
report. A paired run's held launches are re-read as parked where they qualify. A hand-back made
before this change has no `hand-back:` line, so its count restarts from zero.

### Changed

- **`/grill-to-waves` and its shared files.**
  - *The borrow check* (SESSIONS §6) says whether a lender is somewhere a walk can use. A lender
    passes when all three hold: `git --no-optional-locks -C ../<folder> status --porcelain` is
    empty; `git -C ../<folder> worktree list` shows no registered worktree besides its main working
    copy; and its `HEAD` matches its map's state, read through its own tracker. The check only
    reads, and a read that keeps failing fails its condition.
  - *A borrow that outlived its session* (SESSIONS §6): a map's `borrowing <folder> since <time>`
    line holds the lender against every launch but its borrower's own repository's, even after the
    borrower's session died. That launch alone has the check's first condition waived on that
    lender, and its cleanup removes the line.
  - SESSIONS §5 says a third failed hand-back sends the ticket to `ready-for-human`, handled as a
    breach is, and no longer that it changes no label. It also says the count of hand-backs is
    kept on the map's execution progress, so it survives the session, and a surviving
    `ready-for-agent` worktree is read as rework in progress where the map counts hand-backs for it.
  - Stage 6's hand-started launch line waits for every lender to pass the borrow check, for a
    lender held by a `borrowing` line, and for its own repository's earlier steps. A parked launch
    keeps its own repository only.
  - DEFAULTS, *Verifying a high-consequence ticket*: the go-ahead bullet points at the dev
    database question. The rule is unchanged.
  - TRACKERS: an other tracker is never detected by Stage 0. Its record is the owner's, written by
    hand before planning, and `/orchestrate` never writes it.
- **`/orchestrate`.**
  - *The runtime walk*: a borrowed walk runs the borrow check first, and the lender's tree is
    re-read once its app is stopped, restoring only the app's own rewrites and stopping on any
    other path. A failed row that names no ticket now has a path.
  - Stage 1 gains *A borrowed walk that died*, run after the single-session guard and before any
    other Stage 1 wait or stop. It stops the leftover app, re-reads the lender's tree, reports the
    walk's data as possibly left in its dev database, and only then removes the `borrowing` line.
    An app that cannot be stopped is a stop that keeps the line.
  - *Merge the batch* step 2: an attributable conflict is resolved and named in the wave report;
    any other conflict is aborted, its ticket dropped with no reset, and handed back for a rebase
    once the batch records green. The delivery contract and the rework paragraph say why that
    rebase is allowed.
  - Step 4: a failed pinned-check row is attributed as a red whole gate is, by reading its
    failures against the batch's diffs. One that points at no ticket merge is a stop: the defect
    is filed and no green point is recorded. *Closing upward* step 4 does the same for a check
    pinned to the close, before the push.
  - One stripping rule, *When the stripping ends*, which *The integration branch* and the stop rule
    point at. A reset and re-run leaves out every ticket the batch has dropped, for a conflict, a
    breach or a third failure.
  - A third failed hand-back goes to `ready-for-human` with its findings posted, then is handled
    as a breach is. *Verify*, the teardown, the stop rule (which stops at the end of the wave) and
    the outcome-line examples agree.
  - A `dev database:` line (Stage 1, `+ check`, *Merge the batch* steps 4 and 5, and *The dev
    database after a dropped irreversible ticket*). The go-ahead question carries three answers,
    and a refusal writes the line with its answer before it swaps the labels. A reset and re-run
    carries the answer out before the walk, a line with no answer is asked again, `+ all` stops on
    it, and the green point replaces it.
  - Hand-backs are written through to the map's execution progress the moment they are spent, as
    `hand-back: #<n> <k> of 2 @ <sha> — <finding>`, one line per ticket, updated in place and
    removed once the ticket is recorded green or its label is swapped. Stage 1 reads a line as
    rework in progress rather than a lost report, so the count survives a session and never
    restarts from zero. `+ check` prints each line, and the wave report and the ticket's closing
    note name the hand-backs it took.
  - A failed check pinned to the close is a stop before the push, and the owner can waive it for
    this run. The waiver is recorded on the execution progress as `waived: <check> — <reason>` and
    named in the review request. A red gate at *Closing upward* step 4 is a stop with a report.
  - *A borrowed walk that died* runs only once the single-session guard has cleared, and a stop of
    the guard's own does no cleanup and leaves the `borrowing` line standing.
  - The integration branch's upstream is read with `git for-each-ref`, whose empty answer is an
    answer and not a failed read, in Stage 1, the preflight and `+ check` alike.
  - *The integration branch* is cut with `git switch --no-track -c <integration branch>
    origin/<base>`. Preflight step 4 unsets any upstream other than `origin/<integration branch>`
    and names it in the wave report, `+ check` reports an upstream and writes nothing, and a
    resumed close keeps its post-push upstream.
  - *Merge the batch* step 3 writes the tracker record only for a tracker Stage 0 detected.
- **`/conduct`.**
  - *Ready* now includes the borrow check for each lender, a `borrowing` line on a lender, and
    wave order. It reads each lender as `<folder>` from the conductor's own folder.
  - A launch is parked when its session's turn ended on `orchestrate: done` or `orchestrate:
    stopped` and every open ticket it names is `ready-for-human` or waits on an open blocker.
    A parked launch occupies its own repository only, its session is free and its slot may be
    reused, and `+ check`, every wake's report and the stop report name it with its three ways out:
    re-plan, close, or go on without it.
  - A launch let out of parking is ready again and relaunched, and after a context clear a launch
    that reads as held but names a ticket with a kept branch is asked about.
  - `orchestrate: done` reads the same in Stages 1 to 4: free where its launch has landed, and held
    or parked where a ticket it names is still open. A parked launch's stop report is relayed to
    the user, who may answer in that tab or through `/conduct`.
  - An unreadable map's report says the read failed, is retried at every recompute, and that the
    owner restores access to that tracker. A lender held by a `borrowing` line is reported with the
    launch that clears it, rather than as waiting on the owner.
  - Stages 1 to 5 read labels, open blockers and kept branches, and recognise parked in `+ check`,
    slot reuse, the watcher and outcome lines, and the stop.
- **`GLOSSARY.md`.** *Lender* joins, and *Tracker record* now holds for every tracker, with the
  record of a tracker TRACKERS has no commands for describing them in prose.
- **Agent definitions.** No agent definition changed.

## 2026-11-16 — Borrowed working copies, ignored run paths and complete batch exits

A paired run's walk can now use another repository's running app, by borrowing that repository's
working copy while no session runs there. The run's own paths no longer show in `git status`, and
every way out of a merge batch now says what it re-runs and what it keeps.

### After updating

Run the installer again on both hosts (`./install.ps1 -Target both` or `./install.sh --target both`).
A paired map written before this change carries no `peer:` entries and no `borrows` suffixes, so a
walk there that needs another repository's app is a stop until the declaration is added on the ticket
and in the run order.

### Changed

- **Borrowing and occupying in a paired run.** A ticket's `runtime:` takes `peer:<folder>` entries
  beside `dev-db` or `dev-server`, never beside `none`, so such a ticket is always walked, and the
  run order's `· borrows <folder>[, <folder>]` suffix carries those of every ticket of the
  repository wave a launch runs. `/grill-to-waves` prints each paired launch line with its borrows,
  and a launch started by hand goes only while no session runs in a repository it occupies. `/conduct` defines *ready* by occupying: a launch occupies its own
  repository and every repository it borrows, symmetrically, and a held launch keeps occupying. A
  launch counts as in flight from its launch line, so readiness is recomputed within one pass, and a
  launch deferred by a dialog goes out only while still ready. `+ check` prints the borrows. The
  runtime walk gains *A borrowed working copy*: the lender's recorded commit must be at `HEAD` with a
  clean tree or the walk waits, the app is started and stopped by the lender's own runbook, nothing is
  written there, and an undeclared need or an app that will not start is a stop. The stop for an
  undeclared need names the `peer:` entry and the `· borrows` suffix to add before the launch runs
  again.
- **The run's own paths stay out of `git status`.** The worktree and scratch folders, and `.scratch/`
  where the tracker is local, are appended to the clone's local exclude file when not yet ignored, and
  nothing is committed. `/orchestrate` applies it at preflight and names what it added, `+ check`
  reports it, and `/grill-to-waves` applies it to `.scratch/` at Stage 0. In a paired run, planning
  also appends that entry to another repository's clone, through `git -C ../<folder>`, when it
  writes that repository's local tracker.
- **The tracker record's layout.** `docs/agents/issue-tracker.md` now has a fixed layout in
  TRACKERS: a title, one paragraph, *Structure*, *Labels* and *Operations*. `/orchestrate` writes it
  to that layout in *Merge the batch*. The record names the tracker and how items, labels and links
  are recorded on it, and its *Operations* rows point at TRACKERS' commands; only a tracker TRACKERS
  has no commands for has each operation described in its record.
- **The ways out of a merge batch.** A red fast gate, a red whole gate and a failed walk row all
  take one path: reset to the recorded commit, sync from the base wherever it holds commits the
  recorded commit lacks, and run the merge steps again without the ticket, which keeps
  `ready-for-agent` and its worktree for the rework. A refused go-ahead takes the same path once the
  refusal is recorded, labels swapped and comments posted first, and a session that resumes after a
  refusal whose re-run did not finish completes that re-run rather than stopping. An
  `awaiting go-ahead:` line blocks dispatch, and `+ all` stops on it. A breach, whether reported or
  read from the diff, drops its ticket; the rest of the batch goes green and the session stops at
  the end of that wave.
- **The `ready-for-human` teardown.** A ticket handed to a human has any uncommitted change in its
  worktree committed onto its branch as a work-in-progress commit, then its worktree torn down but
  its branch kept and named in the wave report, and reconcile leaves that branch alone.
- **Two glossary terms.** *Borrowed working copy* and *Tracker record* join the glossary.

## 2026-11-16 — One integration branch per run

Every run now delivers through a single integration branch and a single review request, instead of
one pull request per ticket. Tickets merge into the integration branch locally, the whole gate runs
on it, and the first push is the close.

### After updating

Run the installer again on both hosts (`./install.ps1 -Target both` or `./install.sh --target both`).
Finish a run already in flight before installing: the updated `/orchestrate` stops on a map with no
`Integration branch:` line, and a map written before this change has none.

### Changed

- **One integration branch per run.** It is cut from `origin/<base>` at the first wave's preflight
  and recorded as `<integration branch> cut at <sha>`. Worktrees branch from the last green point
  recorded per merge batch, never from the base, and ticket branches never nest under it.
- **Nothing is pushed until the close.** Tickets merge locally with a `Merge #<n> ` commit, which is
  also what Stage 1 reconciles against, bounded to the run's own merges.
- **The sync from the base.** The branch merges the base in at every dispatch preflight and before
  the review request, with attributable conflicts resolved and product decisions a stop.
- **One review request per run, optionally a draft.** It opens at the close from the integration
  branch to the base, in the order the orchestrate skill gives: delivery notes, mirror pass, final
  sync, whole gate, push, request. `Run closes at:` settles draft or ready, and a no-forge close
  ends at *branch ready* or *merged*. A resumed close never opens a second request.
- **Executors commit and report.** They never push, never open a review request and never touch the
  integration or base branch; the Codex no-network caveat is gone. An irreversible ticket Fable did
  not verify waits for the user's go-ahead before its wave is recorded green.
- **Mirrors are written by the run.** Planning commits nothing. The spec template opens with an
  `As of <date>: written against <base> @ <sha>.` line, each spec's mirror lands on the integration
  branch after the batch holding its first ticket, and the close regenerates each one whole. No
  `docs/` branch and no docs pull request. *Base branch*, *Integration branch* and *Spec mirror*
  join the glossary.

### Removed

- The team shape and `+ team`, `+ spec` and `+ tail`. Solo and paired are the two shapes.
- The Sessions table, `exclusive:` and assignee handling. SESSIONS renumbers around collision,
  worktrees, breach and paired runs.

## 2026-11-13 — A narrower second verification

The second verification of a high-consequence ticket was a full review on the most expensive tier.
In one five-ticket run it cost close to half of what the five executors cost together, mostly in
reading and in re-running gates the batch gate runs anyway. It now checks what can escape the net,
on the tier that check needs.

### After updating

Run the installer again (`./install.ps1 -Target both` or `./install.sh --target both`). An open map
needs no edit; a ticket whose map names one clause keeps the verifier that clause selects.

### Changed

- **The verifier follows the strongest clause.** Adversarial, irreversible, or a decision left to the
  executor: `executor-fable-high`, as before. Run-wide only, with the design settled in the ticket:
  `scout-opus-high`, because checking an implementation against a written design is a diff review.
- **The brief lists its checks.** The invariant each clause names, and each decision the executor
  made that the ticket did not settle. Scope against `writes:`, layering, regenerated files and lint
  stay with the orchestrator's diff read and the batch gate. A probe runs only where reading leaves a
  check undecided, and the verifier is done when every listed check has a verdict with its evidence.
- **A re-verification reads the delta**: the diff since the verified commit, the findings to close,
  and the original checks for whatever the rework touched, on the same agent.
- **The map names every clause a ticket meets**, since the verifier follows the strongest.

## 2026-11-10 — Opus session floor, Fable per ticket, Haiku for narrow agents

The most capable model is now spent per ticket instead of per session, so the pipeline runs on an
account without Fable and costs less on one that has it.

### After updating

1. Run the installer again (`./install.ps1 -Target both` or `./install.sh --target both`) and
   restart the session. It installs the two new agents and removes the two retired ones, backing
   them up first.
2. Replace `scout-sonnet-medium` with `scout-haiku-medium` wherever a repository's own `CLAUDE.md` or
   `AGENTS.md` names it.
3. An open map needs no edit. A ticket still labelled `executor:fable` + `effort:medium` falls back to
   `executor-opus-medium`, which is where the new rule sends it, and a ticket planned at
   `effort:xhigh` still dispatches.
4. Optional, Claude Code only: `/advisor fable` in a session below Fable.
5. `/conduct <lead map>` now launches what is ready and stops. Add `+ watch` for the earlier
   behaviour of running the whole order, and `+ sessions <n>` for more than two repositories at once.

### Changed

- **Session floor.** The session that plans, orchestrates and verifies runs on the frontier tier
  (Opus) at `high`. It replaces "the most capable model available — Fable, then Opus": no step
  requires Fable. `/orchestrate` stays at `high`; `/grill-to-waves` may run at `xhigh` for a paired
  run, a run of many specs, or one that settles a seam several tickets compose.
- **The Fable tier is narrower.** A ticket is *high-consequence* when it is irreversible, run-wide or
  adversarial. It is `executor:fable` only when it also leaves a decision open to the executor. With
  the design settled it runs on Opus.
- **Every high-consequence ticket gets a second verification** in a fresh context before it merges,
  whichever tier ran it: `executor-fable-high` with a brief that writes nothing, or `scout-opus-high`
  where Fable is unavailable. An irreversible ticket that Fable did not verify waits for the user's
  go-ahead before the push.
- **`xhigh` is earned, never planned.** Tickets are planned at `medium` or `high`. A hand-back for a
  reasoning failure at `high` is re-dispatched at `xhigh` on the same tier. `low` and `max` are not
  executor levels, and `DEFAULTS.md` now says why.
- **An executor that stops on a decision reports one question.** The orchestrator re-grades the
  ticket to Fable where Fable is available, and otherwise decides and names the decision in the wave
  report.
- **Executors dispatch no sub-agents**: `disallowedTools: Agent` on Claude Code, and the executor
  body's own instruction on both hosts.
- **`/orchestrate + check`** also prints the session's model and effort, the advisor, any environment
  variable that overrides an agent file, and every high-consequence ticket with the executor and the
  second verification it will get.
- **Precedence.** `DEFAULTS.md` names `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` and
  `CLAUDE_CODE_EFFORT_LEVEL`, which override an agent file's `model` and `effort`.
- `SESSIONS.md` states the one-session-per-working-copy rule without reference to an earlier
  protocol.

### Changed — `/conduct`, sized for one laptop

- **No watcher unless asked.** Plain `/conduct` launches what is ready, reports, and stops; Stage 1
  and `+ check` never arm one. `+ watch` keeps the run going.
- **One watcher for the whole run** instead of one process per session. It takes every session as
  `<name>:<seq>`, polls once a minute instead of every twenty seconds, exits after an hour without a
  settle instead of waiting indefinitely, and waits through `orchestrate: waiting on executors` by
  itself, so a pause no longer costs the conductor a turn. A held session gets no watcher, and none
  outlives the stop.
- **One tab, split.** The sessions `/conduct` starts run in panes split from its own tab — the
  conductor on the left, two slots stacked on the right, labelled `conduct:<folder>` — instead of
  one new tab per repository. A slot is closed and reused for the next repository once its session
  is free. `+ tabs` keeps the earlier layout, and a session beyond the second gets a tab.
- **Two sessions in flight** by default instead of five; `+ sessions <n>` changes it.
- **Five executors per session**: the launch line carries `+ ceiling 5` when a map plans more.
- **Ticket states** are read through `clerk-haiku-medium` where it is installed.
- **The stop report** marks the sessions whose repository has no launch left as safe to close.
- `watch.ps1` takes `-Sessions <name>:<seq>,…` and `watch.sh` takes `<name>:<seq> …`; the earlier
  `-Agent`/`-AfterSeq` and positional forms are gone.

### Fixed

- **A merge subject carries the ticket as `#<n>`**, on a local tracker too. `/orchestrate`'s
  reconcile grep matches that form, and a sandbox run showed one orchestrator writing
  `merge ticket 02 …` instead, which the grep would not have found.
- **`tests/check-docs.ps1` also checks agent frontmatter.** A plain YAML value holding a colon
  followed by a space fails to parse, and the host then registers no agent for that file, silently.
  Two descriptions written for this change had one, and the test run caught it.

### Added

- **`scout-haiku-medium`** — the locate scout, on the narrow tier (Luna on Codex).
- **`clerk-haiku-medium`** — runs a gate command and condenses its output, reads the tracker into a
  table, drafts a closing comment or log entry from facts the brief supplies, copies a spec body into
  its mirror. It decides, posts and commits nothing; the orchestrator judges and posts.
- **The advisor as a host capability** in the `Hosts` table: a Claude Code session below Fable may
  set Fable as its advisor, and its sub-agents inherit it. No step depends on it.
- `GLOSSARY.md`: *High-consequence ticket*, *Session floor*, *Narrow tier*, *Clerk*.
- This file.

### Removed

- **`executor-fable-medium`** — a fully specified high-consequence ticket runs on Opus.
- **`scout-sonnet-medium`** — replaced by `scout-haiku-medium`, the same job on the narrow tier.

Both are on the installers' retired list, so a copy left by an earlier install is removed.

### Unchanged

The three executor tiers and their labels, Opus as the default tier for judgment, the rule that
Fable is never a scout, the Codex mapping of the three executor tiers, and worktree teardown, which
stays with the orchestrator or `executor-sonnet-medium` and is never a clerk chore.

### Sources

Host facts were read from the Claude Code documentation on 2026-11-10: the advisor tool and its
pairing rules, sub-agent frontmatter (`disallowedTools`, `effort`), sub-agent nesting, and the model
and effort precedence.

### Tested

On 2026-11-10, before the merge, against three throwaway repositories with one paired run on a local
tracker, under herdr with Claude Code: `/orchestrate + check`, `/conduct + check`, `/conduct`,
`/conduct + watch` through to the close of all three repositories, and one `/orchestrate` run on an
Opus session whose high-consequence ticket was verified by `executor-fable-high`. Not exercised: Codex,
a remote tracker, a runtime walk, a hand-back to `xhigh`, an account without Fable, and a session
that sits `idle` at the pause line — herdr kept reporting `working` while executors ran.
