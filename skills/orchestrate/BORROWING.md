# Borrowing another repository's working copy

In a paired run, a launch walks against another repository's running app by borrowing that
repository's working copy. [SKILL.md](SKILL.md) points here from two places: Stage 1, where the
execution progress carries a `borrowing <folder> since <time>` line, and *The runtime walk*, where a
ticket's `runtime:` carries `peer:<folder>` entries. The borrow check itself and the paired-run format
are [../grill-to-waves/PAIRED.md](../grill-to-waves/PAIRED.md).

**A borrowed walk that died.** Where the execution progress carries `borrowing <folder> since
<time>`, a walk against that repository's working copy died mid-way (*A borrowed working copy*, below), and its walker's report died with it. Clean up once the single-session
guard has cleared — it found no claim, a stale claim or this conversation's own claim, or the user
confirmed there is no other session — and this session has taken the claim, taken it over or
renewed it, because the
walk may be a live session's, and before this stage ends on any other wait or stop, an unsatisfied
gate included. A stop of the guard's own takes no claim, does no cleanup and leaves the line standing. In this
order: check whether that repository's app still runs, by its runbook (its port or health URL);
stop it the way the runbook says; re-read its tree as *The lender's tree after the walk* says (below); report the walk's accounts and sentinel data as possibly left in its dev database;
then remove the line. The line is what keeps that repository lent
([../grill-to-waves/PAIRED.md](../grill-to-waves/PAIRED.md), *A borrow that outlived its
session*), so it goes only once the app is stopped, or was found not running, and the tree is
re-read. An app that cannot be stopped, like a path that cannot be attributed, is a stop that
leaves the line standing: its report names the app's port or health URL, or the path, the owner
clears it and tells this session to go on, and this session, or the next one's Stage 1, resumes
from the line. `+ check` reports the line and does none of this.

**A borrowed working copy.** In a paired run, a ticket whose `runtime:` carries `peer:<folder>`
entries walks against each such repository's running app, in that repository's working copy, which
this launch borrows ([../grill-to-waves/PAIRED.md](../grill-to-waves/PAIRED.md)). For each
of them:

1. **Before the walk**, run the borrow check on it
   ([../grill-to-waves/PAIRED.md](../grill-to-waves/PAIRED.md)). A lender that fails is a
   stop with a report naming the lender and the condition that failed. `/conduct`, or the user
   starting this launch by hand, saw it pass when this launch went — but for a dead walk's
   leftovers, which SKILL.md Stage 1 has cleaned up since — and occupancy has kept every scheduled session
   out of it since, so the cause is outside the schedule: the owner clears it and tells this
   session to go on.
2. **Start its app** the way that repository's own steering file (`CLAUDE.md`, `AGENTS.md`) or
   runbook says, run the walk, and stop the app once the walk returns, whatever it found. Before
   the app starts, add `borrowing <folder> since <time>` to this map's execution progress, so a
   session that dies mid-walk leaves the next one what to clean up (*A borrowed walk that died*, above); remove the line once
   the app is stopped, the walk's sentinel data wiped and the lender's tree re-read (below).

**The lender's tree after the walk.** Once its app is stopped, read
`git -C ../<folder> status --porcelain` again; the borrow check found it empty. A path it shows now
is restored only where it is provably the app's own rewrite, read first, the way executor leakage is
read ([SKILL.md](SKILL.md) Stage 1, *The tree preflight*, step 2): a tracked path with `git -C ../<folder> restore -- <path>`, an
untracked one removed. Name every restored path in the wave report. Anything that cannot be
attributed to the app is a stop with a report, never discarded unread.

Write nothing to that repository's tracked tree but that restoring, its one exception. The walk
brief says the same, without the exception: no checkout, no `git worktree add` — that repository's
single-session guard would read it as another session — no install, no code generation, no
migration, no seed. Data the walk writes into that repository's dev
database follows the walk's rules (SKILL.md *The runtime walk*): every account stays and is reported with its password, and other
sentinel data is wiped, with the wipe proven. A need for another repository's app that no `peer:`
entry declares, or an app that does not start at the commit the borrow check passed, is a stop
with a report. For an undeclared need, the report names what to add before the launch runs again:
the `peer:<folder>` entry on the ticket's `runtime:`, and the `· borrows <folder>` suffix on its launch
in the lead map's run order ([../grill-to-waves/PAIRED.md](../grill-to-waves/PAIRED.md)).
