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
   it over the log — and rewrite it when this wave ends. Its `claimed:` line, where it carries one,
   is the claim line the guard reads (*The working-copy claim*, below). The log (the comment thread; `map-log.md`
   beside a local `map.md`) is history, read only when a question needs it; a local `map.md` still
   carrying dated sections is moved to that layout first, once the claim is taken (*The
   single-session guard*, below), as [../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md) says. Read with it any other open
   map that names this run, which *Cross-run gates* below relies on.
2. **One frontier listing** of every open item under `run:<slug>` — state, labels, bodies, open blocker
   counts.
3. **Git ground truth** — `git fetch --prune`, `git status --porcelain`, the local integration
   branch (whether it exists, whether it contains the recorded commit, `git log --merges` on it),
   its upstream, if any (`git for-each-ref --format='%(upstream:short)' refs/heads/<integration
   branch>`, which prints an empty line where there is none — an answer, not a failed read), the
   commits `origin/<base>` holds that it lacks, every ticket branch, `git worktree list`.
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
says and merged in the re-run, never torn down and dispatched again — but for a ticket with a
`hand-back:` line, which goes as that line says (below); then reset and re-run that
batch without the refused tickets (*Merge the batch*, *Reset and re-run*), rather than stopping. Otherwise, where the integration branch's `HEAD` is that sha,
ask the user for that go-ahead again, for the batch at that commit, instead of resetting past the
batch and re-running it (*Merge the batch*, step 5); with `HEAD` anywhere else, the line is a stop
with a report. While the line stands, nothing is dispatched (*Dispatch the whole wave at once*).
That batch's tickets are exempt from the surviving-worktree rules below and from the guard's
question: their worktrees stay until the batch is recorded green or refused, and a refused
ticket's then goes as a `ready-for-human` ticket's does (*Record, close, tear down*).

**A `dev database:` line** in the execution progress says the dev database holds the effects of an
irreversible ticket dropped after the batch's walk ran (*Merge the batch*, *The dev database after a
dropped irreversible ticket*). Read it before any reset or walk of that batch, the refused batch's
re-run above included. With an answer, follow it as *Reset and re-run* says; with none, ask the
user which of *Merge the batch* step 5's three answers applies, and stop on it, under `+ all` too.
It may stand beside an `awaiting go-ahead:` line; the green point replaces both.

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
`ready-for-agent` ticket whose worktree survives, outside a batch awaiting a go-ahead, with no
`hand-back:` line (below), and once the guard below has been answered: the executor's report died
with the session. Where its branch has commits past the recorded commit
(`git log <recorded commit>..<ticket branch>`), they are an
executor's result without its report: verify them as *Verify* says, reading the diff and running
the gate, and merge them in the batch, or tear the worktree down and dispatch again. Where it has none, tear it down and dispatch again. Say
which. Dispatch never re-creates a worktree that already exists. Tickets have no review requests of
their own, so there are none to reconcile.

**A `hand-back:` line** in the execution progress,
`hand-back: #<n> <k> of 2 @ <ticket branch sha> — <the finding, in a few words>`, names a ticket
handed back for rework, the hand-backs it has spent, and its branch's tip that failed (*Record,
close, tear down*). Once the guard below has been answered, that ticket's surviving
`ready-for-agent` worktree is rework in progress, not a lost report. Its commits past that tip
(`git log <ticket branch sha>..<ticket branch>`) are the rework's result: verify them as *Verify*
says. Where there are none, send the rework again with the line's finding — a fresh dispatch into
the worktree that exists, carrying the original brief plus that finding, since the executor that
held it died with the session — once no `awaiting go-ahead:` line and no unanswered `dev database:`
line stands, and until then the line and the worktree wait; a conflict hand-back goes once the
batch it was dropped from has recorded green (*Merge the batch*, step 2). The ticket is never
merged into the re-run of the batch it was dropped from: a batch this stage re-runs (above) takes
it only where the commits past the recorded one hold its `#<n>` merge of the rework, never of that
tip, and otherwise it merges in a later batch. A failure found on that verification is hand-back
`<k>+1`, and the third swaps the label as the rework paragraph says. The count never restarts from
zero.

**The single-session guard.** It asks one question — is another *agent session* live in **this working
copy**? It runs on Stage 1's four reads, before this stage writes anything — before a reset of the
integration branch, before the reconcile above and before *A borrowed walk that died* below — and
reads three things: `git worktree list`, the claim file and the map's claim line (*The working-copy
claim*, below). A worktree registered under `.claude/worktrees/<run-slug>/` is this
run's own: a leftover of an earlier session of this run, or the live worktree of a second launch of
it, such as a relaunch of a session that looked hung. Where this run's worktrees are registered for
open tickets outside a batch awaiting a go-ahead, other than those this conversation registered
itself in an earlier turn (*Lifecycle*, below) — `ready-for-agent` and `ready-for-human` alike,
since an open ticket's worktree may be one a live second session is still working in, and the
reconcile would tear it down, verify it or merge it under that session — ask the user, in one
question, to confirm that no other session of this run is live in this working copy before
reconciling them, the same question that asks about a claim (below). Confirmed: the reconcile above handles them, each by its label and any
`hand-back:` line. Not confirmed: stop. A **registered** worktree anywhere else, besides
this working copy itself, is another session and says yes: stop and report, because two sessions in one tree contend on the tree, the dev server and the dev
database at once. An empty leftover directory under `.claude/worktrees/` is not a registered worktree,
so read the list, never the filesystem.

**A claim found** — a claim file, a claim line, or both — is judged by this table. A claim is *of
this run* when its `run:` is this run's slug and its `map:` is this map's reference in the one
form a claim writes it and every reader compares it: the issue reference with its `#` (`#54`), or
the local map's path relative to the repository root with no leading `./`
(`.scratch/<run-slug>/map.md`). Under herdr
(`HERDR_ENV=1`), read the pane the claim names, read-only, with the herdr skill's read commands, as
`/conduct` reads a session: `herdr pane list` in every workspace says whether the pane exists and
what its cwd is, `herdr agent get <pane>` gives its agent's state, and for `idle` or `done` its last
outcome line is read as `/conduct` Stage 4, *Reading a session*, reads it.

| Found | Under herdr | Outside herdr, or the pane unreadable |
|---|---|---|
| No claim file, no claim line | take | take |
| A claim file of another run or another map, or one that cannot be read | stop; report the file; the owner removes it, and its map's `claimed:` line where that map carries one | same |
| A claim of this run naming this session's own pane (`HERDR_PANE_ID`) | stale: take over, name it in the report | — |
| A claim of this run naming a pane that is gone or holds no agent | stale: take over | ask |
| A claim of this run whose agent is `working` or `blocked` | live: stop, name the pane | ask |
| A claim of this run, `idle` or `done`, its last outcome line the pause line | live: stop | ask |
| A claim of this run, `idle` or `done`, any other last line or none | stale, its turn ended without release: take over | ask |
| `unknown`, or a claim without a pane | ask | ask |
| A claim line without a claim file | judged by the rows above by the line's pane where it names one; ask otherwise | ask |

A pane counts as **gone** only where no pane other than this session's own whose cwd is this
working copy's root holds an agent that is `working`, `blocked`, or `idle` or `done` on the pause line: a pane moved to another
herdr workspace gets a new id, so its old id reads as gone while its session lives, and where such
a pane exists the guard asks instead. A claim carrying this conversation's own token is read before the table: it is this
session's own, left by a turn that ended without releasing it: it is held still, and nothing is
asked about it — under herdr, only where it names no pane or this session's own pane
(`HERDR_PANE_ID`). Where it names another pane, read that pane as above: an agent there that is
`working` or `blocked`, or `idle` or `done` on the pause line, means this conversation is running in
a second process, so stop, and name that pane; any other reading is judged by the table's rows, as
any claim of this run is. Where the claim file and the claim line name different tokens, judge
each, and the stricter verdict holds: a stop over a question, a question over a take-over.

**The question is the guard's one question**, widened: it covers the open tickets' worktrees above
and the claim, and names the claim's time, host and pane, or that it names none. Confirmed: take the
claim over, and the reconcile handles the worktrees as above. Not confirmed: stop. An answer this
conversation already holds is not asked again; it covers the worktrees and the claim's token it
named, and a claim with another token is a new question. Where the guard clears — nothing found, a
stale claim, or the user's confirmation — take the claim, or take it over, before anything else in
this stage writes. A take-over is named in the wave report, or in the turn's report where no wave
runs. A stop of the guard's own takes nothing and cleans up nothing.

The guard sees every `/orchestrate` session in this working copy at every moment of its turn,
whichever host runs it: by its registered worktrees while a wave is in flight, and by its claim from
its guard to its outcome line. An agent session that runs no `/orchestrate`, such as the owner
working by hand, makes no worktree and takes no claim, so the guard cannot see it.

**The working-copy claim** is the record that one `/orchestrate` session is acting in this working
copy. It is recorded twice, and the file is the authority and the only mutual exclusion:

- **The claim file**, `working-copy-claim` at the top of the clone's git common directory
  (`git rev-parse --path-format=absolute --git-common-dir`). Every worktree of the clone shares it,
  `git status` never shows it, and a session on any host sees it. One field per line, `pane:` only
  where `HERDR_PANE_ID` is set:

  ```
  token: <host>-<UTC time of this conversation's first take, compact>-<8 random hex digits>
  run: <run slug>
  map: #<n> | <the local map's path from the repository root, no leading ./>
  host: claude | codex | <other>
  since: <UTC time of the current take, ISO 8601>
  pane: <HERDR_PANE_ID>
  ```

  The token, `codex-20261117T093000Z-3f9a1c2e` for one, is this conversation's own: one token per
  conversation, minted at its first take and reused at every re-take (*Lifecycle*), while `since`
  gives the time of the current take. Keep it, and
  never take it back from the file or the line, because the ownership check below compares against
  it; a session that no longer holds its own token, after a context compaction for one, fails the
  ownership check and stops. The file is **created exclusively**, so that of two sessions taking at once one create fails,
  and that session stops. In bash, a `set -C` (noclobber) redirection, which fails where the file
  exists:

  ```sh
  ( set -C; printf '%s\n' 'token: <token>' 'run: <run slug>' 'map: <map>' 'host: <host>' 'since: <time>' 'pane: <pane>' > "$(git rev-parse --path-format=absolute --git-common-dir)/working-copy-claim" )
  ```

  In PowerShell, `New-Item` without `-Force`, which fails the same way:

  ```powershell
  New-Item -ItemType File -ErrorAction Stop -Path (Join-Path (git rev-parse --path-format=absolute --git-common-dir) 'working-copy-claim') -Value "token: <token>`nrun: <run slug>`nmap: <map>`nhost: <host>`nsince: <time>`npane: <pane>`n"
  ```

  Leave the `pane:` field out of either where `HERDR_PANE_ID` is unset.
- **The claim line**, on the map's execution progress beside its other live-state lines:
  `claimed: <token> since <time> · <host>[ · pane <id>]`. It carries no path and no machine name,
  because the map may be public. Only a take, a take-over and a release write it: every other
  rewrite of the execution progress — the green point (*Merge the batch*, step 5) and *Record,
  close, tear down* among them — keeps the `claimed:` line exactly as the map carries it when
  re-read for that rewrite, and never restores it from an earlier copy, so a session that was taken
  over cannot write its own line back over the new holder's.

**Take** writes the file, then the line, before any other write. **A take-over** removes the stale
file and creates it again exclusively, and removes the stale file only: move it aside first, to
`working-copy-claim.<this session's token>` beside it (`mv`, or `Move-Item` without `-Force`), a
rename only one session can make of that file, and read the moved file. A move-aside whose target
`working-copy-claim.<this session's token>` already exists moves nothing and is a stop that reports
that file. Where the moved file carries the stale
claim's token, delete it, create the claim exclusively as above, and replace the stale claim line
with this session's. Where the move finds no file, or the moved file carries another token, another
session took this working copy meanwhile: write a moved file's content back by the same exclusive
create and delete the moved file — or, where that create fails too, keep the moved file — and stop.
A claim line without a claim file is taken over by
creating the file exclusively and replacing the line. A `working-copy-claim.<token>` file is a
take-over's or a release's leftover, never a claim file — and a leftover only where a second read
still finds it, since another session's take-over or release passes through that name for an
instant: the guard and `+ check` report it, and the owner removes it.

**Lifecycle.** The claim is held while this launch is in flight, in `/conduct`'s sense: a turn that
ends on `orchestrate: waiting on executors` keeps it, and the turn that follows the pause holds it
still. **Release** is the last act before any other outcome line, `orchestrate: done` or
`orchestrate: stopped — …`, a stop that asks a question included (*Stop rule*): the ownership check
below, then remove this session's claim line, then the file, so that a crash between them leaves the
file, the stronger evidence. The file goes the way a take-over removes one: move it aside to
`working-copy-claim.<this session's token>` and delete it only where it carries this session's
token; otherwise write it back by the exclusive create, as a take-over does, and stop. A later turn of the same session after a release, or after a turn that
ended on no outcome line — an answer to its stop, for one — takes the claim again through the
guard's read and runs Stage 1's four reads again before acting on the answer; what the user already
answered in this conversation is not asked again. In that turn the guard asks nothing about a
worktree this conversation registered itself, and the four reads are reads: where they show the
integration branch's `HEAD`, the execution progress, its `claimed:` line aside, and the worktrees as
the turn that stopped left them, act on the answer from the step where it stopped; where any of them
changed, Stage 1 runs in full, the reconcile and its question included. `+ check` never takes,
releases or takes over a claim.

**The ownership check** reads the claim file and confirms it carries this session's token. It runs
only in a session that holds the claim: before the tree preflight's first step, at the start of
each step of *The close runs in this order* (*Closing upward*), and at release. A mismatch, or a missing file, is a stop: nothing more is
written — not to the tree, the tracker or the map — neither the file nor the line is removed, and
the report says that another session took this working copy.

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
guard has cleared — it found no other session, found a stale claim, or the user confirmed there is
none — and this session has taken the claim, because the
walk may be a live session's, and before this stage ends on any other wait or stop, an unsatisfied
gate included. A stop of the guard's own takes no claim, does no cleanup and leaves the line standing. In this
order: check whether that repository's app still runs, by its runbook (its port or health URL);
stop it the way the runbook says; re-read its tree as *The lender's tree after the walk* says (*The
runtime walk*); report the walk's accounts and sentinel data as possibly left in its dev database;
then remove the line. The line is what keeps that repository lent
([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §6, *A borrow that outlived its
session*), so it goes only once the app is stopped, or was found not running, and the tree is
re-read. An app that cannot be stopped, like a path that cannot be attributed, is a stop that
leaves the line standing: its report names the app's port or health URL, or the path, the owner
clears it and tells this session to go on, and this session, or the next one's Stage 1, resumes
from the line. `+ check` reports the line and does none of this.

**The tree preflight**, run before each wave's dispatch and again before each merge batch — not
before every step. In a session that holds the claim, it begins with the ownership check (*The
ownership check*, above): the claim file carries this session's token, or the preflight is a stop
before step 1. `+ check` holds no claim and no token, and skips it. Then:

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
   now (*The integration branch*); step 6 then syncs it with any base commits it lacks. Before the
   close the branch has no upstream, read as Stage 1's git ground truth reads it: one other than
   `origin/<integration branch>` (a branch cut by the old rule has the base) is unset,
   `git branch --unset-upstream <integration branch>`, and the wave report names it. After the
   close's `git push -u` the upstream is `origin/<integration branch>`, and a resumed close leaves
   it alone.
5. Where the repo generates a database client or other build-time artifact into the dependency tree,
   it is present. Missing → repair it before anything else, because it misattributes every failure
   downstream of it.
6. Before dispatch only: when `origin/<base>` holds commits the integration branch lacks, sync from
   the base (*The integration branch*).

**`+ check`** runs Stage 1 read-only and prints: the waves with each ticket's state and open blockers,
the integration branch with its base, its last green point and how far `origin/<base>` is ahead of it,
its upstream, read as the git ground truth reads it, where it has one other than
`origin/<integration branch>` (the preflight's step 4 unsets it; `+ check` writes nothing),
an `awaiting go-ahead:` line as the state the run is in, never as a failing preflight step 4, with
no wave dispatchable until it is answered,
a `dev database:` line as part of that state, with its answer or that it has none,
each `hand-back:` line with its ticket, its count and its finding, and whether its branch has
commits past the line's sha,
what the guard found — the claim file's fields, the claim line, any `working-copy-claim.<token>`
file beside the claim file, and the verdict the guard's table gives with the pane read behind it,
taking, releasing and taking over nothing —
what the preflight's other steps found — never that another session took this working copy, since
`+ check` holds no token and runs no ownership check — which of the run's own paths
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
  base as just fetched: `git switch --no-track -c <integration branch> origin/<base>` (git's
  default gives a branch cut from a remote-tracking branch that branch as its upstream, and the
  integration branch has none before the close, so a bare `git pull` or `git push` cannot reach the
  base), and record the cut in
  the map's execution progress at once, `<integration branch> cut at <sha>`. A resuming session uses
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
  and then a stop, so the next preflight does not meet a `MERGE_HEAD`. A gate that goes red after a
  sync takes the red gate's path of *Merge the batch*, whose one rule says when its stripping ends;
  a break that is the base's doing points at no ticket merge, and that rule ends there.
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
   touch the integration branch or the base branch — a conflict hand-back's rebase of its own ticket
   branch (*Record, close, tear down*) breaches none of this, since the ticket branch is local and
   never pushed, and the protocol's "never a rebase" governs the integration branch, which the rebase
   does not touch; report the branch, the final commit and the gate
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
  ([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §5). A ticket's third failure is
  handled the same way once its label is swapped (*Record, close, tear down*).
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
   gate's path below, without that merge. **A merge conflict** is resolved where you can attribute
   both its sides and the resolution needs no product decision — append-plus-append among them, the
   test the sync from the base applies (*The integration branch*) — and the resolution is named in
   the wave report. Any other conflict: `git merge --abort`, which returns `HEAD` to the batch's
   previous merge, drop the ticket from the batch, and go on with the batch's other branches, with
   no reset. Once the batch records green, the ticket is handed back as a conflict hand-back
   (*Record, close, tear down*). A conflict reaches this step at all because worktrees branch from
   the recorded commit, never from the sync merge the dispatch preflight made, so a base change in a
   ticket's file meets that ticket only here.
3. After the last merge, the **spec mirrors** and the **tracker record**, then the **whole** gate
   once. Planning wrote no mirror, so every spec whose first ticket merges in this batch and whose mirror
   (`docs/spec-<spec-slug>-v<N>.md`) is absent from the integration branch gets it now, one commit
   per spec, after the batch's last merge and before the gate: the title line, links to the spec, the
   map and the tickets, the date copied and the integration branch, `---`, then the item's body
   verbatim, its as-of line included (`/grill-to-waves` Stage 2). The rule reads state — which
   mirrors the integration branch holds — not a wave number, so it survives a reset and a resume. A
   clerk may do the copy; you commit it. The **tracker record** is a commit of its own and follows
   the same state rule: where the map's *How this is executed* records a tracker Stage 0 detected
   (GitHub, GitLab or local) and `docs/agents/issue-tracker.md` is absent from the integration
   branch, write that file from the
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
   ticket; where that ticket is irreversible, the dev database is settled with the user before the
   reset (*The dev database after a dropped irreversible ticket*, below). A failed row of a pinned
   check names no ticket, so it is attributed as a red whole gate is: read what the check measures
   against the batch's diffs. Where it points at one ticket merge, it takes the red gate's path
   without that ticket. Where it points at no ticket merge — the sync from the base, or a state the
   recorded commit already held — it is a stop with a report: the defect is filed as its own item,
   and no green point is recorded.
5. **Record the green point, and push nothing.** Only when the gate and the walk are both green —
   and, where the batch holds an irreversible ticket Fable did not verify, once the user has given
   the go-ahead — rewrite the map's execution progress to carry `<integration branch> @ <sha>`
   before anything else, its `claimed:` line kept as the map carries it (Stage 1, *The working-copy
   claim*). While that go-ahead is pending, the execution progress carries
   `awaiting go-ahead: #<n>[, #<m>…] @ <batch head sha>`, naming every irreversible ticket in the
   batch, written the moment the gate and the walk are green, so the wait survives the session's
   end (Stage 1); the green point replaces it. The go-ahead question names each such ticket and what
   a reset of the branch will not undo
   ([../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md) *Verifying a high-consequence
   ticket*), and asks in the same exchange which of these applies to the dev database should the
   user refuse (*The dev database after a dropped irreversible ticket*, below):
   1. the user restores the dev database and says so;
   2. you reset or re-seed it by the repository's runbook — offered only where the runbook names how;
   3. the re-run's walk runs against it as it is, and the walk's table says it ran against a dev
      database holding that ticket's effects.

   **A refused go-ahead** is recorded before anything else: write the `dev database:` line with the
   answer, then swap the refused tickets' `ready-for-agent` for `ready-for-human` and post on each
   the comment saying why, carrying that answer, so a session that dies from here on resumes it
   (Stage 1). Then reset and re-run without them, below. The refused tickets' worktrees go as
   *Record, close, tear down* says for that label.

**A red gate** — a red fast gate at step 2, a red whole gate after the last merge, which points at
that merge first, or a failed walk row at step 4 — is attributed by reading its failures against
the batch's diffs, and is reset and re-run without the ticket it points at. That ticket is handed
back, unless this is its third failure: it keeps `ready-for-agent` and its worktree for the rework,
which goes as the rework paragraph of *Record, close, tear down* says, and the `ready-for-human`
teardown does not reach it. Nothing leaves this working copy before the close, so a bad ticket costs
a reset and a re-run without it — there is no revert to publish and no ungated commit anywhere but
here.

**When the stripping ends** is one rule, stated here, and *The integration branch* and the stop
rule point at it. Each reset and re-run drops the ticket the failure is attributed to, and handing
it back counts as one of its two. It repeats while each failure points at a ticket merge still in
the batch. It ends on green, or on a failure that points at no ticket merge — the sync from the
base, or a state the recorded commit already held — which is a stop with a report, because no
ticket owns the fix. No count caps it: the attribution is the bound, and every drop spends one of
that ticket's hand-backs.

**The dev database after a dropped irreversible ticket.** A reset undoes the code, never what an
irreversible ticket — the map names each high-consequence ticket with its clauses — did to the dev
database once a walk of the batch ran against it. So a reset that drops an irreversible ticket after
the batch's walk has run settles with the user, before the re-run's walk, how the dev database is
brought back: a refused go-ahead (step 5), or a failed walk row that points at an irreversible
ticket (step 4), and, in a re-run after such a walk, any red gate that drops one. A red fast gate
or a red whole gate before the batch's walk is outside the rule: no walk has run, so the dev
database holds nothing of the batch. A refusal carries the answer in the go-ahead exchange. Any
other such drop writes the line with no answer before the reset and asks which of step 5's three
answers applies; that is a decision that is the user's, so the session stops on it, under `+ all`
too, and resets once it is answered. The answer is written through twice: as a comment on each
ticket the line names — for a refusal, the refusal comment step 5 posts — and in the map's
execution progress as `dev database: holds the effects of #<n>[, #<m>] — <answer>`, from before
the reset until the re-run records green; the green point replaces the line. A further such drop
before then adds its ticket to the line and asks again. A line with no answer yet is asked again,
and nothing walks against that dev database until it is answered (Stage 1).

**Reset and re-run**, for a refused go-ahead and a red gate alike:
`git reset --hard <recorded commit>`; sync from the base wherever `origin/<base>` holds commits the
recorded commit lacks, as the tree preflight's step 6 does (*The integration branch*); then run
steps 2 to 5 again — the merges, the mirrors and the tracker record, the whole gate, the walk —
without the dropped tickets, every ticket dropped from this batch so far, for a conflict, a breach
or a third failure among them — a resuming session knows them by their `ready-for-human` label and
their `hand-back:` lines (Stage 1) — ending on the green point or the next awaiting line, which
replaces any `awaiting go-ahead:` line standing; a `dev database:` line stays until the green point.
Where a `dev database:` line stands, carry out its answer before step 4's walk: answer 2 is your own
step before that walk, by the runbook; answer 1 waits for the user's word that the dev database is
restored, which a resuming session asks for again; answer 3 goes into the walk's brief, so its table
says it ran against a dev database holding those tickets' effects.

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
by the red gate's path of *Merge the batch*; a failed row that names no ticket, a pinned check's,
is attributed as *Merge the batch* step 4 says, and is a stop where it points at no ticket merge; a
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
earlier walks can post them, the merge commit on the integration branch, the hand-backs it took,
each with its finding, and, from a Fable-tier executor, its correctness argument. Then close it.
`clerk-haiku-medium` may draft a comment or the log entry into `.claude/scratch/` from the facts you
give it; read the draft, then post it yourself.

Per wave, **two writes on the map, and the body is the one that matters**:

- **Rewrite the map's execution-progress section in its body.** The cut line,
  `<integration branch> cut at <sha>`, kept as it was written, because the reconcile range starts
  there; the last green point, `<integration branch> @ <sha>`, already written by *Merge the batch*;
  the `claimed:` line, kept exactly as the map carries it when re-read for this rewrite and never
  restored from an earlier copy, since only a take, a take-over and a release write it (Stage 1,
  *The working-copy claim*);
  the waves table with what landed and its merge commit, how many tickets remain, the next
  dispatchable tickets from a live blocking-edge read, the open items still blocking the close,
  every `hand-back:` line still standing (the rework paragraph below), and the tree state. A fact
  the next session needs before it dispatches is one line here; how the wave went belongs to the
  log. Stage 1 reads the body first and calls it binding, so a body still saying "wave 5 is next"
  after wave 5 landed aims the next session at a closed ticket. A log entry does not correct that:
  it is one entry in a thread nobody reads before acting. Where the map has no such section yet, add
  one at the top.
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
carrying the original brief plus the finding — at most twice. Every hand-back counts toward the two,
the conflict hand-back included. **The count lives on the map**, not in this session: a hand-back
is written through the moment it is spent — when its ticket is dropped from the batch, or found
failing at *Verify* — before any reset, any stop and the rework itself, as one line per ticket in
the execution progress, `hand-back: #<n> <k> of 2 @ <ticket branch sha> — <the finding, in a few
words>`, the sha being the branch's tip that failed. A second hand-back updates that line in place.
The line goes once the ticket is recorded green or carries `ready-for-human`, whatever put the label
there, the third failure included; until then a resuming session reads the rework from it
(Stage 1). A hand-back for a reasoning failure at `high` is the fresh dispatch at `xhigh` that
*Model and effort* describes, and counts as one of the two. **A conflict hand-back**
(*Merge the batch*, step 2) tells the executor to rebase its own ticket branch onto the new recorded
commit, in its worktree, resolve, and run the gate; a resolution that needs a product decision is
`git rebase --abort`, then its stop-and-report. That rebase is within the delivery contract
(*Dispatch the whole wave at once*): the ticket branch is local and never pushed, so rewriting it
publishes nothing, and the protocol's "never a rebase" governs the integration branch, which the
rebase does not touch. **The third failure hands the ticket to a human**: swap its `ready-for-agent`
for `ready-for-human` and post on it the findings that failed it. From there it is handled exactly
as a `writes:` breach is (*Verify*): it is dropped from the batch; the batch's other green tickets
merge, gate, walk and record green; the wave is torn down, its worktree by the `ready-for-human`
teardown below, uncommitted work committed as one work-in-progress commit and its branch kept and
named; and the session stops at the end of that wave, under `+ all` too. A defect found in code a
ticket did not own is **filed as its own item**, never an opportunistic fix and never a hot fix on
the integration branch or the base branch.

Tear down every worktree of the wave in one pass — yourself, or through `executor-sonnet-medium`
carrying the procedure verbatim — by the junction-safe procedure in
[../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md): unlink every reparse point or symlink
deepest-first — the `.next/node_modules/*` junctions a
build leaves, then `node_modules` — confirm none remain, then remove, `git worktree prune`, and confirm
the generated client is still present. Delete each ticket branch locally; none was ever pushed.

**A ticket handed to a human** — one carrying `ready-for-human`, whatever put it there, a refused
go-ahead, a breach or a third failure — has its worktree torn down in that same pass by the same
procedure, but its branch is kept: skip the procedure's `git branch -D`. Before the procedure runs,
read the worktree's `git status --porcelain`, and commit any change it shows onto the ticket's branch
yourself, as one work-in-progress commit, never the dependency tree, its link or the environment
file the dispatch placed there, so `git worktree remove --force` discards nothing handed to the
human. A work-in-progress commit that fails, a pre-commit hook rejecting it for one, is a stop with
a report before the teardown: the worktree is not removed while it holds uncommitted work. That
branch is the work handed to the human, and no session merges or deletes it. Name it, and the
work-in-progress commit where there is one, in the ticket's comment and in the wave report. A
teardown delegated to `executor-sonnet-medium` carries in its brief the kept branches by name and
the instruction to skip `git branch -D` for them. A ticket handed back for rework keeps
`ready-for-agent`, so this rule does not reach it until its third failure swaps the label.

## Closing upward

**A spec closes** when every one of its tickets is closed and every orchestrator-only check the map
pinned to it is recorded done. Post its completion record — what landed against its implementation and
testing decisions, with its tickets and their merge commits on the integration branch — and close it.
A spec another open map is still executing stays open, and the record says so.

**The map closes** when: zero open tickets under the run label on this side of the map's
`Run closes at:` line — a ticket past that point, or one the map's `Steps after close owned by:`
line hands to someone else, is outside the close condition, and the record names it as handed over
to its owner, never as waited on; zero open non-ticket items under it other than the specs and the
map (a mislabelled item is resolved or re-labelled first); every spec closed with its record; every
orchestrator-only item pinned to the close done, runtime verification included, or waived by the
owner (step 4); the completion gate green on `HEAD` — a recorded gate run stands when `HEAD` is the
commit it ran on and `git status --porcelain` is empty, and is run again only otherwise; the mirror
pass from `/grill-to-waves` Stage 2 run over every spec this run produced, on the integration branch
and before the final sync and the gate — the delivery notes written on the spec item, each mirror
regenerated from it (the copy is a clerk chore; the delivery notes are yours); the walk's
screenshots posted on the run's review request as one captioned note (without a forge, with the
execution record in the map's last log entry); and the integration branch synced with the base and
pushed — both judged as of the moment its review request opened, or, without a forge, as of step 5,
since the base moves on once it merges — and its review request at the close point.

**The close runs in this order**, once every ticket on this side of the close point is closed.
Steps 1 to 6 are not repeated once a review request from the integration branch exists: a resumed
close that finds one, open or merged, goes straight to step 7. A no-forge *merged* close that finds
`origin/<base>` already holding the integration branch's tip (the local base where there is no
remote) goes straight to step 8. Each step begins with the ownership check (Stage 1, *The
ownership check*), since the tree preflight does not run at the close: the claim file carries
this session's token, or the close stops before that step writes anything.

1. **Delivery notes** on each spec item this run produced.
2. **The mirror pass, as one commit** on the integration branch: each mirror regenerated whole
   from its item (`/grill-to-waves` Stage 2), so the final sync and the gate below run over it.
3. **The final sync**: `git fetch --prune`, since the tree preflight does not run at the close, then
   sync from the base (*The integration branch*).
4. **The whole gate** on `HEAD`, reused where the record above stands; its commit is recorded as the
   last green point. A red gate here points at no ticket merge — every ticket merge on `HEAD` is
   recorded green — so it is a stop with a report (*Merge the batch*, *When the stripping ends*).
   Then the walk of every runtime check the map pins to the close, on `HEAD`, dispatched and judged
   as *The runtime walk* says. A failed check pinned to the close is filed as its own item and is a
   stop before the push (step 5): the owner either takes a ticket for it, added to the map as a
   wave, or waives the check for this run. A waiver is recorded on the map's execution progress,
   `waived: <check> — <the owner's reason>`, and in the review request's body (step 6), and the
   close goes on at step 5.
5. **Push the integration branch** where a remote exists, `git push -u origin <integration branch>`:
   the run's first push.
6. **One review request to the base**, opened as a draft when `Run closes at:` is *draft review
   request opened* and ready for review otherwise. Its body is the execution record: every ticket
   with its merge commit, the gate result with the commit it ran on, a summary of each Fable-tier
   correctness argument, every check waived at step 4 with the owner's reason, and the steps handed
   over past the close point with their owner. Post the walk's screenshots on it — every wave's,
   from the ticket comments, and the close's own walk from step 4.
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
order without a further go-ahead, and stop early only on a red gate whose stripping ends on a failure
that points at no ticket merge (*Merge the batch*, *When the stripping ends*), a failed pinned check
that points at none (*Merge the batch*, step 4), or a decision that is the user's — an `awaiting
go-ahead:` line among them, which stops before the next dispatch, and a `dev database:` line with no
answer, which stops before the re-run's walk. A `writes:` breach and a ticket's
third failure stop at the end of their wave, once the rest of the batch is recorded green and the
wave torn down. The closing chain above always runs without a further go-ahead.

Leave nothing half-held: no worktree for a closed or `ready-for-human` ticket, and no branch that is
green but unmerged, or kept for a `ready-for-human` ticket, without saying so by name. The report
names the tickets closed with their merge commits on the integration branch, the last green point,
the hand-backs, each `ready-for-human` ticket with its kept branch, the defects filed, every account the walk created with its password
(a file committed to the repository names the account and never the password), anything outstanding
for the user, the steps handed over past the close point with their owner, and the next wave with
what it waits on.

**Every turn ends on an outcome line**, alone on the last line: `orchestrate: done` when the scope
ran to its end; `orchestrate: stopped — <the reason, in a few words>` for anything else that hands
the run back to the user, such as a question, a decision, a red gate no ticket merge owns, or the end
of a wave that handed a ticket to a human for a breach or a third failure;
and `orchestrate: waiting on executors` when the turn ends while executors still run in the
background. `/conduct` reads that line to tell a pause from the end. The pause line keeps this
session's working-copy claim; before `orchestrate: done` or `orchestrate: stopped — …`, a stop
that asks a question included, release it as the turn's last act (Stage 1, *The working-copy
claim*). A turn that holds no claim, as at a stop of the guard's own, releases nothing, and a stop
on a failed ownership check removes neither the claim file nor the claim line.

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
