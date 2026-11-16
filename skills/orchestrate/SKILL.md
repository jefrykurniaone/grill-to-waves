---
name: orchestrate
description: Execute an execution map from /grill-to-waves in one session — dispatching ticket executors as subagents, verifying their work, merging a whole wave under one gate, and closing specs and the map.
disable-model-invocation: true
---

# Orchestrate

You are the orchestrator for a delivery run planned as an **execution map**: specs → tickets → waves.
`/grill-to-waves` produced it; this skill executes it. **Executors are subagents, not sessions**: you
brief them, they work in their own worktrees and report back, and you verify, merge and close.

## Two shapes

| Shape | Repositories | Sessions | Launched by |
|---|---|---|---|
| **solo** | one | one `/orchestrate` session, wave by wave | the user |
| **paired** | several, one run slug | one `/orchestrate` session per repository, each in its own working copy | `/conduct`, in the lead map's run order |

**This file is the whole protocol of one session, in either shape.** A solo session owns the map and
runs it wave by wave; there is no second session to coordinate with. In a paired run each
repository's session is exactly that, against its own map, and a blocker in another repository
reaches it as a cross-run gate (Stage 1). [../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) has
the surfaces and collision the waves were built from, and the paired-run format (§6).

**Two agent sessions never share one working copy**, in either shape. A second session found in this
working copy is a stop, not a shape.

## Arguments

References are whatever the repo's tracker uses — an issue number, a GitLab iid, a Jira key, a file
path under `.scratch/`.

```
/orchestrate map <map>                       the next unstarted wave  (`/orchestrate <map>` is the same)
/orchestrate map <map> + wave <k>            one named wave
/orchestrate map <map> + all                 solo, every remaining wave in order, no stop between them
/orchestrate map <map> + check               read-only preflight, writes nothing
/orchestrate map <map> + ceiling <n>         the in-flight ceiling for this session, with any line here
```

## Stage 0 — Resolve the tracker

Read the repo's tracker record, `docs/agents/issue-tracker.md`
([../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md) *The tracker record*); if it exists
it governs reading, commenting, labelling, linking and closing. Otherwise detect from
`git remote -v` (GitHub → `gh`, GitLab → `glab`, none → local markdown); a map reference that is a
file path settles it. The frontier read that returns labels, bodies and open-blocker counts is in
[../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md).

## Stage 1 — Orient

Four reads, then work. This is the whole resume, and it is enough after a context clear or a crash,
because the tracker and the local integration branch carry the state that matters. Nothing is pushed
before the close, so the remote carries none of it.

1. **The map** — wave order, the contention table, the completion gate, where the run closes and
   who owns the steps after it (`Run closes at:`, `Steps after close owned by:`), the integration
   branch and its base (`Integration branch: <name>, cut from <base>`), what is out of scope, and any
   orchestrator-only checks pinned to a wave. Binding. A map with no `Integration branch:` line was
   planned under the old model, which merged into the base branch and pushed every wave: stop, and
   name the missing line. Its execution-progress section, the recorded commit among it
   (*The integration branch*), is the state the last wave left behind and is kept current by
   *Record, close, tear down*, so trust
   it over the log — and rewrite it when this wave ends. The log (the comment thread; `map-log.md`
   beside a local `map.md`) is history, read only when a question needs it; a local `map.md` still
   carrying dated sections is moved to that layout first, as
   [../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md) says. Read with it any other open
   map that names this run, which *Cross-run gates* below relies on.
2. **One frontier listing** of every open item under `run:<slug>` — state, labels, bodies, open blocker
   counts.
3. **Git ground truth** — `git fetch --prune`, `git status --porcelain`, the local integration
   branch (whether it exists, whether it contains the recorded commit, `git log --merges` on it),
   the commits `origin/<base>` holds that it lacks, every ticket branch, `git worktree list`.
4. **The repo's agent rules** — `CLAUDE.md`, `AGENTS.md`, and anything they include: the gate
   commands, the seams, the hard rules an executor brief has to carry.

**Retry a failed read.** An API, tracker or fetch error is never an answer — never "nothing to do",
never "no open tickets", never "the base is unchanged". Retry it, and a read that keeps failing is a
wait with its reason stated, never a pass.

**Trust the local integration branch only when it contains the recorded commit**
(`git merge-base --is-ancestor <sha> <integration branch>`). A missing branch, or one without that
commit, is a stop with a report, never a rebuild: until the close the run's merged work exists only
in this working copy. Where the map records no cut yet, the branch is absent, or has no commits of
its own and is an ancestor of `origin/<base>` (`git merge-base --is-ancestor <integration branch>
origin/<base>`), not only equal to it, so a session that died between the cut and recording it is
not stopped by a base that moved since; anything else is a stop. Commits past the recorded one were
never recorded green: read them, and where each is a sync from the base, a `#<n>` merge of a ticket
branch that still exists, a mirror commit or the tracker record (*Merge the batch*, step 3), reset to
the recorded commit and run the wave or the close they belong to again from there; anything else is a
stop. The exception is a batch awaiting an irreversible go-ahead: the execution progress carries
`awaiting go-ahead: #<n>[, #<m>…] @ <batch head sha>`. Where a ticket the line names now carries
`ready-for-human`, the go-ahead was refused and its re-run did not finish, wherever `HEAD` is: the
tickets the line names that carry that label are the refused ones, and the line exempts nothing any
more. Once the guard below has been answered, the refused tickets' worktrees go by their
`ready-for-human` label, and the batch's other tickets' surviving worktrees are verified as *Verify*
says and merged in the re-run, never torn down and dispatched again; then reset and re-run that
batch without the refused tickets (*Merge the batch*, *Reset and re-run*), rather than stopping. Otherwise, where the integration branch's `HEAD` is that sha,
ask the user for that go-ahead again, for the batch at that commit, instead of resetting past the
batch and re-running it (*Merge the batch*, step 5); with `HEAD` anywhere else, the line is a stop
with a report. While the line stands, nothing is dispatched (*Dispatch the whole wave at once*).
That batch's tickets are exempt from the surviving-worktree rules below and from the guard's
question: their worktrees stay until the batch is recorded green or refused, and a refused
ticket's then goes as a `ready-for-human` ticket's does (*Record, close, tear down*).

**Reconcile before dispatching anything.** The evidence, on every tracker, is the `#<n>` merge
subject on the integration branch, read only among this run's own merges — first parent, from the
recorded cut to the recorded commit:
`git log --merges --first-parent -E --grep '^Merge #<n>([^0-9]|$)' <cut>..<recorded commit>`.
The range keeps out the base's history and an earlier run's merges, which on a local tracker reuse
the same `#01`; the range ends at the recorded commit because a merge past it was never gated;
and the pattern is anchored to the subject form, because `#25` also matches `#253` and a title can
carry another `#<m>`. With no cut recorded there is nothing to reconcile. Such a merge on a
still-open ticket means a previous session died between recording the wave and closing its tickets:
post the record and close it, never re-run it. A ticket branch with no worktree: leave it alone
when its ticket is `ready-for-human`, because it is the work handed to a human; otherwise delete it
when the recorded commit already holds it, or inspect, salvage or delete it, and say which. A
worktree whose ticket is closed: tear it down. A worktree whose ticket is `ready-for-human`, once the
guard below has been answered: tear it down and keep its branch, as *Record, close, tear down* says
for that label, and name the branch in the wave report; never verify, merge or dispatch it. An open
`ready-for-agent` ticket whose worktree survives, outside a batch awaiting a go-ahead, and once the
guard below has been answered: the executor's report died with the session. Where its branch has
commits past the recorded commit (`git log <recorded commit>..<ticket branch>`), they are an
executor's result without its report: verify them as *Verify* says, reading the diff and running
the gate, and merge them in the batch, or tear the worktree down and dispatch again. Where it has none, tear it down and dispatch again. Say
which. Dispatch never re-creates a worktree that already exists. Tickets have no review requests of
their own, so there are none to reconcile.

**The single-session guard.** It asks one question — is another *agent session* live in **this working
copy**? Read `git worktree list`. A worktree registered under `.claude/worktrees/<run-slug>/` is this
run's own: a leftover of an earlier session of this run, or the live worktree of a second launch of
it, such as a relaunch of a session that looked hung. Where this run's worktrees are registered for
open tickets outside a batch awaiting a go-ahead — `ready-for-agent` and `ready-for-human` alike,
since an open ticket's worktree may be one a live second session is still working in, and the
reconcile would tear it down, verify it or merge it under that session — ask the user, in one
question, to confirm that no other session of this run is live in this working copy before
reconciling them. Confirmed: the reconcile above handles them, each by its label. Not confirmed:
stop. A **registered** worktree anywhere else, besides
this working copy itself, is another session and says yes: stop and report, because two sessions in one tree contend on the tree, the dev server and the dev
database at once. An empty leftover directory under `.claude/worktrees/` is not a registered worktree,
so read the list, never the filesystem. That is one cheap read, and if it is clear nothing else can
collide with you here.

**Cross-run gates.** Where the map, its comments, or another open map says this run waits on another
run's tickets — or, in a paired run, on another repository's
([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §6), read through that repository's
own tracker as [../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md) *Across repositories*
says — verify it by reading those tickets' states, never by trusting the prose that describes it.
A blocker in another repository is released once it is merged onto that repository's integration
branch and closed, long before that run's close. A gate reads that repository's tracker and nothing
else of it: a walk that needs its running app uses its working copy only by borrowing it
(*The runtime walk*). An unsatisfied gate is a wait, not a failure: say what it waits on and stop.

**A borrowed walk that died.** Where the execution progress carries `borrowing <folder> since
<time>`, a walk against that repository's working copy died mid-way (*The runtime walk*, *A
borrowed working copy*), and its walker's report died with it. Clean up once the single-session
guard has been answered, because the walk may be a live session's, and before this stage ends on
any other wait or stop, an unsatisfied gate included. In this order: check whether that
repository's app still runs, by its runbook (its port or health URL); stop it the way the runbook
says; re-read its tree as *The lender's tree after the walk* says (*The
runtime walk*); report the walk's accounts and sentinel data as possibly left in its dev database;
then remove the line. The line is what keeps that repository lent
([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §6, *A borrow that outlived its
session*), so it goes only once the app is stopped, or was found not running, and the tree is
re-read. An app that cannot be stopped, like a path that cannot be attributed, is a stop that
leaves the line standing: its report names the app's port or health URL, or the path, the owner
clears it and tells this session to go on, and this session, or the next one's Stage 1, resumes
from the line. `+ check` reports the line and does none of this.

**The tree preflight**, run before each wave's dispatch and again before each merge batch — not
before every step:

1. `git fetch --prune` exits 0 (retry a few times; a persistent failure is a wait, never a pass).
2. The run's own paths are ignored, and then `git status --porcelain` is empty. Apply
   [../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §4 *The run's own paths stay
   ignored* first: each path not yet ignored is appended to the clone's local exclude file, and the
   wave report names every entry added (`+ check` only reports them). Then the status check. When
   it is not empty and a dispatch has just finished, suspect
   **executor leakage** before anything else: an executor that wrote outside its worktree leaves
   exactly this, and the merge is what catches it. Read the file, prove the branch is a strict
   superset of what it holds, then discard it and name the breach in the wave report. Never discard
   unread — a partial copy of the branch's own edit is safe to drop, and anything else is not.
3. No `MERGE_HEAD`, `rebase-merge`, `rebase-apply` or `CHERRY_PICK_HEAD` under `.git`.
4. The integration branch is checked out with `HEAD` at the recorded commit — or, at a merge
   batch's preflight, at the sync merge this wave's dispatch preflight made on top of it, or, where
   the execution progress carries an `awaiting go-ahead:` line, at its batch head sha, which serves
   the go-ahead question only: no wave is dispatched from it (Stage 1). Before the
   first wave the map records no cut yet: the branch is absent, and is cut now, or has no commits of
   its own and is an ancestor of `origin/<base>`, not only equal to it, and is recorded as the cut
   now (*The integration branch*); step 6 then syncs it with any base commits it lacks.
5. Where the repo generates a database client or other build-time artifact into the dependency tree,
   it is present. Missing → repair it before anything else, because it misattributes every failure
   downstream of it.
6. Before dispatch only: when `origin/<base>` holds commits the integration branch lacks, sync from
   the base (*The integration branch*).

**`+ check`** runs Stage 1 read-only and prints: the waves with each ticket's state and open blockers,
the integration branch with its base, its last green point and how far `origin/<base>` is ahead of it,
an `awaiting go-ahead:` line as the state the run is in, never as a failing preflight step 4, with
no wave dispatchable until it is answered,
what the guard found, what the preflight found, which of the run's own paths
([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §4) are not yet ignored, cross-run gates with the tickets they wait on, and the
line to run next. It also prints what will actually run: the model and effort of this session as the
host reports them, the advisor configured for this session if any, any environment variable that overrides an
agent file ([../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md) *Hosts*), and every
high-consequence ticket with the executor and the second verification it will get. It writes nothing.

## The integration branch — one per run, local until the close

Every run delivers through one **integration branch**, named on the map's header line
`Integration branch: <name>, cut from <base>`. It is cut from the run's **base branch**, every ticket
merges into it, it is kept current with the base, and the close takes it to the base in one review
request.

- **The cut.** At the first wave's preflight, when the branch does not exist locally, cut it from the
  base as just fetched: `git switch -c <integration branch> origin/<base>`, and record the cut in the
  map's execution progress at once, `<integration branch> cut at <sha>`. A resuming session uses
  the existing local branch, trusted as Stage 1 says. Planning cuts nothing. The name is the map's,
  in the repository's branch-prefix vocabulary, `feat/<run-slug>` by default, and ticket branches
  never nest under it, because git refuses `feat/x` and `feat/x/…` side by side.
- **Nothing is pushed before the close**: not the integration branch, not a ticket branch, not the
  base. Executors push nothing and open no review request. The close pushes the integration branch
  once (*Closing upward*). The residual risk, stated in the map's *How this is executed*: until the
  close, the run's code exists only in this working copy.
- **The last green point.** Once a merge batch's gate and walk are green, the map's execution
  progress records `<integration branch> @ <sha>`, posted the moment it is true (*Merge the batch*,
  step 5). **The recorded commit** is that last green point, or, until a green point is recorded,
  the cut. The next worktrees branch from it, a red gate resets to it, and the preflight expects
  `HEAD` there.
- **Sync from the base.** Whenever `origin/<base>` holds commits the integration branch lacks —
  checked at every wave's preflight before dispatch, and once more at the close before the review
  request — merge it in with a merge commit, `git merge --no-ff origin/<base>`, never a rebase and
  never a force-push, then run the whole gate. A wave's own gate covers the sync at its preflight;
  the sync before the review request gets a gate of its own. Sync whichever files changed: disjoint
  writes prove non-collision, never independence, so a base change in a file no ticket touched can
  still break the run. Resolve a conflict whose two sides you can attribute, such as
  append-plus-append; a conflict that needs a product decision is aborted (`git merge --abort`)
  and then a stop, so the next preflight does not meet a `MERGE_HEAD`. A gate that stays red once
  every ticket merge is cleared of the break is the base's doing: a stop with a report, because no
  ticket owns the fix.
- **Without a remote**, read `origin/<base>` as the local base branch: the fetch and the push have
  nothing to reach, and the close is the no-forge one.

## Model and effort

[../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md) is the source of truth, overridden only
by the repository's own `CLAUDE.md` or `AGENTS.md`. This session runs on the frontier tier at `high`.
Executors are Fable, Opus or Sonnet at `medium`, `high` or `xhigh`, from the ticket's labels; default
effort is `high` when unlabelled. Dispatch `executor-<tier>-<effort>` by the host's mechanism in
DEFAULTS.md's *Hosts* table (Claude Code: `subagent_type`; Codex: `spawn_agent` naming that custom
agent). Scouts are `scout-haiku-medium`, `scout-sonnet-high`, `scout-opus-medium` and
`scout-opus-high`; `clerk-haiku-medium` takes the chores DEFAULTS.md's *The clerk* lists.

**Re-grade only when the body contradicts a label**, then correct the label and say why in one line:

- A `medium` brief that leaves a decision open moves to `high`.
- A ticket that meets a consequence clause and leaves a decision open moves to Fable. One whose design
  is settled runs on Opus. Either way it keeps its second verification.
- `xhigh` is reached only by a hand-back: an attempt at `high` that came back wrong for a reasoning
  failure goes to `executor-<tier>-xhigh` as a fresh dispatch carrying the original brief plus the
  finding.

**Substitutions.** If the matching `executor-fable-<effort>` is missing or the Fable model is
unavailable, dispatch `executor-opus-<effort>`. If any other agent is missing, fall back to the host's
general agent with the mapped model and effort stated in the prompt. Record every substitution on the
ticket and in the wave report.

**When an executor stops on a decision**, it reports one question with its evidence. Answer by what
the decision is:

- **A missing fact or a wrong premise**: correct the ticket and send the answer to the same executor.
- **A high-consequence decision, Fable available**: re-grade the ticket to `executor:fable` and
  dispatch it there.
- **A high-consequence decision, Fable unavailable**: decide it, send the decision to the same
  executor, and name it in the wave report as a decision made without the Fable tier.

Record the decision and the path it took in the ticket's comment.

## Dispatch the whole wave at once

A ticket is dispatchable iff it is open, `ready-for-agent`, carries both an `executor:` and an `effort:`
label, has zero open blockers on the tracker's own edge read live, and belongs to this wave. A
mislabelled item — `ready-for-agent` without the pair — is reported by name, never guessed at.

**While the execution progress carries an `awaiting go-ahead:` line, nothing is dispatched**: the
next wave would branch from a recorded commit that lacks the awaiting batch. Ask for the go-ahead
(Stage 1) and stop on it; under `+ all` too, because the go-ahead is a decision that is the user's.

**Dispatch every dispatchable ticket in the wave in one message, so the subagents run concurrently —
up to the in-flight ceiling.** The ceiling is **five tickets by default**. `+ ceiling <n>` sets it for
this session, and a line in the map giving the number and the reason sets it for the run; above five
is the user's call either way. A wave holding more
dispatchable tickets than the ceiling goes out in successive batches of at most that many, each batch
dispatched in one message. The waves exist precisely to separate contended files, so there is
normally no overlap to serialise. Two exceptions, both read off the map: if two tickets in the wave
declare overlapping `writes:`, or the contention table names a file they share, the second waits for
the first to merge. Honour a ceiling lower than five only where `+ ceiling` sets one, or the map states
one and gives a reason.

Then, in one pass:

1. **Worktrees** at `.claude/worktrees/<run-slug>/<ticket>`, one branch per ticket in the repo's
   prefix vocabulary, never nested under the integration branch's name, off the recorded commit —
   the last green point, or the cut where none is recorded yet. Never off `origin/<base>` or the
   base branch,
   and never off a sync merge the preflight just made, which no gate has run on yet. `deps: shared` →
   copy
   the local environment file and link the dependency tree (a junction on Windows, a symlink
   elsewhere); **no install and no code generation inside it, by anyone,
   orchestrator included**, because the generator empties the shared copy for every tree at once.
   `deps: own` → copy the whole dependency tree, install and generate inside the copy only.
2. **Briefs** — the ticket body verbatim; the repo's hard rules (seams, gate, i18n, security,
   accessibility); the gate commands; the delivery contract (Conventional Commits in the repo's style,
   on the ticket branch in its worktree; never push, never open a review request, never merge, never
   touch the integration branch or the base branch; report the branch, the final commit and the gate
   start time, and at the Fable tier the correctness argument); the
   prohibition on installing or generating in a junctioned worktree; that **`writes:` is a contract** —
   a tracked file it must change outside the block is a stop-and-report, never a widening; and that
   **executors start no dev server, run no migration or seed, and touch no shared database** — one-shot
   gate commands only, because the running app and the dev database are yours.

## Verify — yours, never the executor's

An executor's account of its own work is a claim, not evidence. Before a branch merges:

- **Read the diff yourself.** Confirm it touches the `writes:` set and nothing else. A diff touching
  a tracked file outside `writes:` is a breach, and so is an executor's report that it must write
  there. Either way: swap the ticket's `ready-for-agent` for `ready-for-human`, comment the path,
  and drop it from the batch; never merge it, never widen the block. The batch's other green tickets
  merge, gate, walk and record green as usual, the wave is torn down, and the session stops at the
  end of that wave, under `+ all` too
  ([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §5).
- **A wrong ticket premise is the common failure**, and an executor that refuses its own ticket is
  usually right. Verify the claim against the code; if the ticket is wrong, correct its body and any
  acceptance criterion quoting it, record why, and re-dispatch. That is not a hand-back.
- **A high-consequence ticket gets a second verification** in a fresh context before it merges, and an
  irreversible one that Fable did not verify waits for the user's go-ahead before its wave is
  recorded green —
  [../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md) *Verifying a high-consequence ticket*.
- **The runtime is walked after the merge, by a sub-agent you judge** — *The runtime walk*, below.

## Merge the batch — one gate, and nothing pushed before the close

Merges land on the integration branch, locally. One session owns every merge in this working copy,
so the whole gate runs once per batch rather than after every merge — and it runs after every batch,
whatever the tickets' surfaces say. Disjoint writes
prove non-collision, never independence: two tickets can share a type, a translation key or a seam
contract without sharing a file, and the whole-gate re-run is the only net, catching only what the
gate catches. A gate command may go to `clerk-haiku-medium`, which returns its exit code and its
failures verbatim; attributing a break and judging the tree stay here:

1. Preflight the tree.
2. For each green branch, in wave order: `git merge --no-ff` into the integration branch, with the
   ticket number in the merge subject as `#<n>` (`Merge #<n> <title> into <integration branch>`),
   the form the reconcile grep of Stage 1 matches, then the **fast** part of the gate only — the
   test suite — so a break is attributed to the merge that caused it. A red fast gate takes the red
   gate's path below, without that merge. Resolve append-plus-append catalogue conflicts yourself.
3. After the last merge, the **spec mirrors** and the **tracker record**, then the **whole** gate
   once. Planning wrote no mirror, so every spec whose first ticket merges in this batch and whose mirror
   (`docs/spec-<spec-slug>-v<N>.md`) is absent from the integration branch gets it now, one commit
   per spec, after the batch's last merge and before the gate: the title line, links to the spec, the
   map and the tickets, the date copied and the integration branch, `---`, then the item's body
   verbatim, its as-of line included (`/grill-to-waves` Stage 2). The rule reads state — which
   mirrors the integration branch holds — not a wave number, so it survives a reset and a resume. A
   clerk may do the copy; you commit it. The **tracker record** is a commit of its own and follows
   the same state rule: where the map's *How this is executed* records a tracker Stage 0 detected
   and `docs/agents/issue-tracker.md` is absent from the integration branch, write that file from the
   map's record, in the layout [../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md)
   *The tracker record* names, and commit it beside this batch's
   mirror commits, which puts it in the first merge batch: planning wrote none. Where a ticket's
   `writes:` includes `docs/agents/issue-tracker.md`, the ticket owns the file and you add none.
   The whole gate is lint, type check, tests, build. Restore any
   file the test run dirties before judging the tree, and record the result with the commit it ran on — the
   close reuses that record (*Closing upward*).
4. **Then the runtime walk**, on the integration branch's `HEAD`, for every ticket whose `runtime:`
   is not `none` and for every check the map pins to this wave — dispatched and judged as *The
   runtime walk* says. A failed row of a ticket takes the red gate's path below, without that
   ticket.
5. **Record the green point, and push nothing.** Only when the gate and the walk are both green —
   and, where the batch holds an irreversible ticket Fable did not verify, once the user has given
   the go-ahead — rewrite the map's execution progress to carry `<integration branch> @ <sha>`
   before anything else. While that go-ahead is pending, the execution progress carries
   `awaiting go-ahead: #<n>[, #<m>…] @ <batch head sha>`, naming every irreversible ticket in the
   batch, written the moment the gate and the walk are green, so the wait survives the session's
   end (Stage 1); the green point replaces it. **A refused go-ahead** is recorded before anything
   else: swap the refused tickets' `ready-for-agent` for `ready-for-human` and post on each the
   comment saying why, so a session that dies from here on resumes it (Stage 1). Then reset and
   re-run without them, below. The refused tickets' worktrees go as *Record, close, tear down* says
   for that label.

**A red gate** — a red fast gate at step 2, a red whole gate after the last merge, which points at
that merge first, or a failed walk row at step 4 — is reset and re-run without the ticket it points
at. That ticket is handed back: it keeps `ready-for-agent` and its worktree for the rework, which
goes as the rework paragraph of *Record, close, tear down* says, and the `ready-for-human` teardown
does not reach it. Nothing leaves this working copy before the close, so a bad ticket costs a reset
and a re-run without it — there is no revert to publish and no ungated commit anywhere but here.

**Reset and re-run**, for a refused go-ahead and a red gate alike: `git reset --hard <recorded
commit>`; sync from the base wherever `origin/<base>` holds commits the recorded commit lacks, as
the tree preflight's step 6 does (*The integration branch*); then run steps 2 to 5 again without the
dropped tickets — the merges, the mirrors and the tracker record, the whole gate, the walk — ending
on the green point or the next awaiting line, which replaces any line standing.

## The runtime walk — a sub-agent walks, you judge

The walk runs in a fresh context, never in yours: a browser driven from the orchestrator's context
re-reads every earlier call, and the walk's own calls soon are most of them. Dispatch one agent from
the executor definitions (the scouts carry no browser tool), the way executors are dispatched —
`executor-sonnet-high`, because the checks were settled upstream and the work is a sweep;
`executor-opus-high` where a pinned check leaves the walker to decide what to measure — with a brief
that writes nothing to the codebase and carries:

- **What to observe**: every `runtime:` criterion of the wave's tickets verbatim — the surface to open,
  the role, the property, the value it must hold — and every check the map pins to this wave.
- **How to sign in**: the way the repository's own steering file (`CLAUDE.md`, `AGENTS.md`) or runbook
  says, with credentials from env by name.
- **Measure, do not eyeball.** A claim about type, size, spacing or contrast is settled by
  `getComputedStyle` or a computed value, not by comparing screenshots — a screenshot pair can be clean
  and still hide the defect.
- **Playwright MCP** (`mcp__playwright__*`) wherever it is connected: `browser_navigate`,
  `browser_snapshot` for the accessibility tree, `browser_evaluate` for the measurement,
  `browser_console_messages` for the console-error count, `browser_take_screenshot` once per check,
  captioned with what it measured, because the set is posted on the run's review request at the close. Where
  the server is not connected the walker falls back to the npx-cached Playwright scripts under
  `.claude/scratch/`, or to plain HTTP where the check needs no DOM, and names the fallback in its
  table. A fallback is a stated fact, never a silent substitution — and never a reason to skip the walk.
- **An artifact a route returns is verified by fetching it**, not by reasoning about the library that
  produced it. Where the output is an image or a file rather than a page, fetch it and look at it, and
  settle any "does this declaration take effect" question by rendering twice with only that declaration
  changed and comparing hashes. Identical bytes mean the declaration is inert.
- **What it returns**: a per-ticket pass/fail table with the measured values, the console-error count
  per page, the screenshot paths, every account it created with its password — those stay, for the
  reviewer — and any other sentinel data it wrote, wiped, with the wipe proven.

Judge the table against the criteria yourself. A failed row is a hand-back to the ticket's executor,
by the red gate's path of *Merge the batch*; a
row whose evidence is thin is a re-dispatch of the walker with the gap named. Open the browser from this
context only to settle a single disputed measurement. Done when every criterion in the brief carries a
measured value or a named failure.

**A borrowed working copy.** In a paired run, a ticket whose `runtime:` carries `peer:<folder>`
entries walks against each such repository's running app, in that repository's working copy, which
this launch borrows ([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §6). For each
of them:

1. **Before the walk**, run the borrow check on it
   ([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §6). A lender that fails is a
   stop with a report naming the lender and the condition that failed. `/conduct`, or the user
   starting this launch by hand, saw it pass when this launch went — but for a dead walk's
   leftovers, which Stage 1 has cleaned up since — and occupancy has kept every scheduled session
   out of it since, so the cause is outside the schedule: the owner clears it and tells this
   session to go on.
2. **Start its app** the way that repository's own steering file (`CLAUDE.md`, `AGENTS.md`) or
   runbook says, run the walk, and stop the app once the walk returns, whatever it found. Before
   the app starts, add `borrowing <folder> since <time>` to this map's execution progress, so a
   session that dies mid-walk leaves the next one what to clean up (Stage 1); remove the line once
   the app is stopped, the walk's sentinel data wiped and the lender's tree re-read (below).

**The lender's tree after the walk.** Once its app is stopped, read
`git -C ../<folder> status --porcelain` again; the borrow check found it empty. A path it shows now
is restored only where it is provably the app's own rewrite, read first, the way executor leakage is
read (*The tree preflight*, step 2): a tracked path with `git -C ../<folder> restore -- <path>`, an
untracked one removed. Name every restored path in the wave report. Anything that cannot be
attributed to the app is a stop with a report, never discarded unread.

Write nothing to that repository's tracked tree but that restoring, its one exception. The walk
brief says the same, without the exception: no checkout, no `git worktree add` — that repository's
single-session guard would read it as another session — no install, no code generation, no
migration, no seed. Data the walk writes into that repository's dev
database follows the rules above: every account stays and is reported with its password, and other
sentinel data is wiped, with the wipe proven. A need for another repository's app that no `peer:`
entry declares, or an app that does not start at the commit the borrow check passed, is a stop
with a report. For an undeclared need, the report names what to add before the launch runs again:
the `peer:<folder>` entry on the ticket's `runtime:`, and the `· borrows <folder>` suffix on its launch
in the lead map's run order ([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §6).

## Record, close, tear down

Per ticket, **one comment**: what landed, the gate result with its start time and the commit it ran
on, the runtime finding with its screenshot paths, so a closing session that did not run the
earlier walks can post them, the merge commit on the integration branch, and, from a Fable-tier
executor, its correctness argument. Then close it.
`clerk-haiku-medium` may draft a comment or the log entry into `.claude/scratch/` from the facts you
give it; read the draft, then post it yourself.

Per wave, **two writes on the map, and the body is the one that matters**:

- **Rewrite the map's execution-progress section in its body.** The cut line,
  `<integration branch> cut at <sha>`, kept as it was written, because the reconcile range starts
  there; the last green point, `<integration branch> @ <sha>`, already written by *Merge the
  batch*; the waves table with what
  landed and its merge commit, how many tickets remain, the next dispatchable tickets from a live blocking-edge read, the
  open items still blocking the close, and the tree state. A fact the next session needs before it
  dispatches is one line here; how the wave went belongs to the log. Stage 1 reads the body first and
  calls it binding, so a body still saying "wave 5 is next" after wave 5 landed aims the next session
  at a closed ticket. A log entry does not correct that: it is one entry in a thread nobody reads
  before acting. Where the map has no such section yet, add one at the top.
- **One log entry**: the tickets with their shas, the decisions taken, the defects filed, and what the
  next wave waits on — a comment on the map, or on the local tracker a dated section appended to
  `map-log.md` (TRACKERS.md). The log is the append-only record of *how* the run went; the body is
  the state the next session resumes *from*. Neither replaces the other.

**That is the entire tracker footprint of a run.**

Where a knowledge-base scribe agent is installed (`vault-scribe`), hand it the wave's durable facts
once those tracker writes are done — the decisions taken and why, the traps found, the environment
quirks — and name the notes it wrote in the report. It is a companion to the tracker, never a
substitute for it, and where no such agent exists this step does not exist either.

Rework goes back to the introducing executor — by a follow-up message to the same executor where the
host has one (`SendMessage` on Claude Code, `followup_task` on Codex), otherwise as a fresh dispatch
carrying the original brief plus the finding — at most twice; the third failure is a stop and a
report. A hand-back for a reasoning failure at `high` is the fresh dispatch at `xhigh` that *Model and
effort* describes, and counts as one of the two. A defect found in code a ticket did not own is **filed as its own item**, never an
opportunistic fix and never a hot fix on the integration branch or the base branch.

Tear down every worktree of the wave in one pass — yourself, or through `executor-sonnet-medium`
carrying the procedure verbatim — by the junction-safe procedure in
[../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md): unlink every reparse point or symlink
deepest-first — the `.next/node_modules/*` junctions a
build leaves, then `node_modules` — confirm none remain, then remove, `git worktree prune`, and confirm
the generated client is still present. Delete each ticket branch locally; none was ever pushed.

**A ticket handed to a human** — one carrying `ready-for-human`, whatever put it there, a refused
go-ahead or a breach — has its worktree torn down in that same pass by the same procedure, but its
branch is kept: skip the procedure's `git branch -D`. Before the procedure runs, read the
worktree's `git status --porcelain`, and commit any change it shows onto the ticket's branch
yourself, as one work-in-progress commit, never the dependency tree, its link or the environment
file the dispatch placed there, so `git worktree remove --force` discards nothing handed to the
human. A work-in-progress commit that fails, a pre-commit hook rejecting it for one, is a stop with
a report before the teardown: the worktree is not removed while it holds uncommitted work. That
branch is the work handed to the human, and no session merges or deletes it. Name it, and the
work-in-progress commit where there is one, in the ticket's comment and in the wave report. A
teardown delegated to `executor-sonnet-medium` carries in its brief the kept branches by name and
the instruction to skip `git branch -D` for them. A third hand-back changes no label, and this rule
does not reach it.

## Closing upward

**A spec closes** when every one of its tickets is closed and every orchestrator-only check the map
pinned to it is recorded done. Post its completion record — what landed against its implementation and
testing decisions, with its tickets and their merge commits on the integration branch — and close it.
A spec another open map is still executing stays open, and the record says so.

**The map closes** when: zero open tickets under the run label on this side of the map's
`Run closes at:` line — a ticket past that point, or one the map's `Steps after close owned by:` line
hands to someone else, is outside the close condition, and the record names it as handed over to its
owner, never as waited on; zero open non-ticket items under it other than the specs and the map (a
mislabelled item is resolved or re-labelled first); every spec closed with its record; every
orchestrator-only item pinned to the close done, runtime verification included; the completion gate
green on `HEAD` — a recorded gate run stands when `HEAD` is the commit it ran on and
`git status --porcelain` is empty, and is run again only otherwise; the mirror pass from
`/grill-to-waves` Stage 2 run over every spec this run produced, on the integration branch and
before the final sync and the gate — the delivery notes written on the spec item, each mirror
regenerated from it (the copy is a clerk chore; the delivery notes are yours);
the walk's screenshots posted on the run's review request as one captioned note (without a forge,
with the execution record in the map's last log entry); and the integration branch synced with the
base and pushed — both judged as of the moment its review request opened, or, without a forge, as
of step 5, since the base moves on once it merges — and its review request at the close point.

**The close runs in this order**, once every ticket on this side of the close point is closed.
Steps 1 to 6 are not repeated once a review request from the integration branch exists: a resumed
close that finds one, open or merged, goes straight to step 7. A no-forge *merged* close that finds
`origin/<base>` already holding the integration branch's tip (the local base where there is no
remote) goes straight to step 8.

1. **Delivery notes** on each spec item this run produced.
2. **The mirror pass, as one commit** on the integration branch: each mirror regenerated whole
   from its item (`/grill-to-waves` Stage 2), so the final sync and the gate below run over it.
3. **The final sync**: `git fetch --prune`, since the tree preflight does not run at the close, then
   sync from the base (*The integration branch*).
4. **The whole gate** on `HEAD`, reused where the record above stands; its commit is recorded as the
   last green point. Then the walk of every runtime check the map pins to the close, on `HEAD`,
   dispatched and judged as *The runtime walk* says.
5. **Push the integration branch** where a remote exists, `git push -u origin <integration branch>`:
   the run's first push.
6. **One review request to the base**, opened as a draft when `Run closes at:` is *draft review
   request opened* and ready for review otherwise. Its body is the execution record: every ticket
   with its merge commit, the gate result with the commit it ran on, a summary of each Fable-tier
   correctness argument, and the steps handed over past the close point with their owner. Post the
   walk's screenshots on it — every wave's, from the ticket comments, and the close's own walk from
   step 4.
   [../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md) *Deliver* has the commands.
7. **Wait to the close point**: the request open, for *draft review request opened* or *review
   request opened*; the request's merged state on the forge, for *merged* — never ancestry, since a
   squash or rebase merge leaves the base without the integration branch's commits; the promotion
   reported, for *deployed* (below).
   Without a forge there is no request: *branch ready* is reached at step 5, with the merge handed
   to the owner; for *merged*, fast-forward the local base to `origin/<base>` (never a reset), merge
   the integration branch into it with `--no-ff` after the final gate, and push the base where a
   remote exists.
8. **Close the map**, its last log entry linking the review request — or, without a forge, carrying
   the execution record and the walk's screenshots itself — and where a spec has a parent item above
   it, post a delivery summary there and close it too.

Closing upward is part of finishing.

## Stop rule

**Stop after the wave, and report.** `+ all` is the exception: continue through every remaining wave in
order without a further go-ahead, and stop early only on a third hand-back, a gate that stays red
after the reset, or a decision that is the user's — an `awaiting go-ahead:` line among them, which
stops before the next dispatch. A `writes:` breach stops at the end of its wave, once the rest of
the batch is recorded green and the wave torn down. The closing chain above always runs without a
further go-ahead.

Leave nothing half-held: no worktree for a closed or `ready-for-human` ticket, and no branch that is
green but unmerged, or kept for a `ready-for-human` ticket, without saying so by name. The report
names the tickets closed with their merge commits on the integration branch, the last green point,
the hand-backs, each `ready-for-human` ticket with its kept branch, the defects filed, every account the walk created with its password
(a file committed to the repository names the account and never the password), anything outstanding
for the user, the steps handed over past the close point with their owner, and the next wave with
what it waits on.

**Every turn ends on an outcome line**, alone on the last line: `orchestrate: done` when the scope
ran to its end; `orchestrate: stopped — <the reason, in a few words>` for anything else that hands
the run back to the user, such as a question, a decision, a third hand-back or a gate that stays red;
and `orchestrate: waiting on executors` when the turn ends while executors still run in the
background. `/conduct` reads that line to tell a pause from the end.

**This run ends at its close point.** Promotion starts from the base branch:
taking what the base holds to staging or production is `/ship-it-to stg` or `/ship-it-to prd`, in
its own session, and it reads the repository's promotion contract and the forge's protections rather
than inheriting anything from this run. Name it in the report once the run's work has reached the
base and is worth promoting; never promote from here. A map whose `Run closes at:` is
*deployed* closes once that session has reported the promotion; the closing session waits on that
report.

## Hosts without subagent dispatch

Where the host has no subagent tool — a Codex CLI too old to expose `spawn_agent`, a Codex
configuration with agents disabled, or another agent CLI — everything above holds except the fan-out:
the session **is** the executor, one ticket at a time, in the ticket's own worktree, and the walker
too; the installed agent definitions are read as role briefs rather than dispatched. The in-flight
ceiling is then 1, so a wave is executed serially in wave order. Verification does not become optional
because the same session did the work — read the diff, run the gate, walk the runtime by the walk
brief's own rules, and say in the report that executor, walker and verifier were the same context.

Where the host does dispatch but its sub-agents share the parent's working directory (Codex), every
executor brief names the worktree's absolute path and tells the executor to work only there; the
worktree sits inside the repository (`.codex/worktrees/…` on Codex) precisely so a workspace-scoped
sandbox can write to it.
