---
name: conduct
description: Drive a paired run — one run slug across several repositories — from one herdr pane, starting /orchestrate in each repository's own pane in the lead map's run order and handing every decision back to you.
disable-model-invocation: true
---

# Conduct

You are the **conductor** of a paired run: one run slug delivered in several repositories, each with
its own working copy, tracker, map and `/orchestrate` session
([../grill-to-waves/PAIRED.md](../grill-to-waves/PAIRED.md)). You start those sessions in their
herdr panes in the order the lead map's *Run order across repositories* gives. Without `+ watch` you
launch what is ready, report, and stop; under `+ watch` you also sleep until a session settles and
start what that releases. Each orchestrator owns its own run: dispatch, verification, merges, its map
and its close. You own the schedule only. Every decision stays the user's: you **relay**, verbatim,
and leave unanswered what you were not told to send.

```
/conduct <lead map>                  launch what is ready now, report, and stop
/conduct <lead map> + watch          every remaining launch: wake when a session settles, launch what that releases
/conduct <lead map> + step <G>       the launches of one named step
/conduct <lead map> + check          read-only: the launches, panes and sessions, and what is ready
/conduct <lead map> + sessions <n>   up to n sessions in flight instead of two
/conduct <lead map> + tabs           one tab per repository instead of splitting your own tab
/conduct <lead map> + bypass         the sessions you start skip permission prompts (Claude Code)
```

`+ watch`, `+ tabs`, `+ bypass`, `+ step` and `+ sessions` combine.

**The numbers are sized for one laptop**: two sessions in flight, five executors in each, no
background process unless you ask for one. Each executor runs the gate in its own worktree, so the
peak is ten test and build runs at once. **The layout is one tab**: you on the left, the two
sessions stacked on the right.

The lead map is a path, or a tracker reference prefixed by its repository's folder (`portal#12`):
your working directory is no repository, so a bare `#12` resolves nowhere.

## Stage 0 — Preconditions

1. `HERDR_ENV` is `1`. Otherwise say that `/conduct` runs only inside herdr, and stop.
2. Call the Skill tool for `herdr`: its CLI and safety rules govern every herdr command below. Where
   that skill is not installed, run `herdr --skill` and read its output instead.
3. Your working directory is the folder that holds the run's repositories, outside every one of them
   (`git rev-parse --show-toplevel` fails there). Inside one of them you would be a second agent
   session in its working copy: say so and stop.
4. Under `+ bypass`, you run on Claude Code. On any other host, say that `+ bypass` is Claude Code
   only, and stop.

Done when all of them hold.

## Stage 1 — Read the run

1. **The lead map**: its run slug, its *Paired runs* line and its *Run order across repositories*,
   in the format of PAIRED.md, each launch in a cell read with its `· borrows` suffix where it
   carries one. A lead map without the run order is a stop: say what is missing.
2. **Every repository's map**, through that repository's own tracker, from inside that repository
   ([../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md)): its execution-progress section,
   any `borrowing <folder> since <time>` line included (Stage 2),
   its in-flight ceiling, and the state of every ticket the run order names: open or closed, its
   labels and whether it waits on an open blocker, as the tracker's frontier read gives them, and
   for each open ticket, the branch its comments name as kept where one does (`/orchestrate`
   *Record, close, tear down*). The ticket states are a
   table with no decision in it: where `clerk-haiku-medium` is installed, give it one brief per
   repository — run the tracker's list command from inside that repository, return each named
   ticket's state as printed, touch nothing in the tree — and read them yourself where it is not.
   For every lender a launch borrows, read what the borrow check needs (PAIRED.md): from its
   map, the cut, the recorded commit, the base and whether the map is open or closed; from its
   working copy, the check's reads, run from your own folder as `git -C <folder>` — PAIRED.md
   writes `../<folder>`, the view from a sibling repository:
   `git --no-optional-locks -C <folder> status --porcelain`, `git -C <folder> worktree list`, its
   claim (below) and its `HEAD`, with `origin/<base>` where its map records no cut. Fetch nothing
   there.

   **Every repository's claim** (`/orchestrate` Stage 1, *The working-copy claim*), at every
   recompute: its claim line, `claimed: …`, from the execution progress just read, and its claim
   file, `working-copy-claim` at the top of the directory that
   `git -C <folder> rev-parse --path-format=absolute --git-common-dir` prints, run from your own
   folder. An absent file is no claim; a file that is there and cannot be read is the table's
   unreadable one. Read every `working-copy-claim.<token>` file beside it too, a **move-aside
   file** (`/orchestrate`'s CLAIMS.md, *A move-aside file*): another session's take-over or release
   passes through that name for an instant, so only one that a second read still finds is
   evidence. One that a second read still finds and that holds a claim of this run is judged as a
   claim, beside the claim file and the claim line (step 4); any other is a leftover.
3. **Panes**: `herdr pane list` in every workspace. A repository's pane is the one whose cwd is that
   repository's root; where there are several, ask which. A repository without a pane gets a slot in
   your own tab when its launch is ready (Stage 3, *The slots*), and this stage creates none. Under
   `+ tabs`, put every repository without a pane into one question instead, and create a tab only
   for those the user agrees to: `herdr tab create --cwd <root> --label <folder> --no-focus`, in
   your own workspace.
4. **Each repository's session**, the agent in its pane under the name Stage 3 gives it:
   - none, or a shell at its prompt: no session yet;
   - `working` or `blocked`: in flight;
   - `idle` or `done`: read it (*Reading a session*, Stage 4). The pause line means in flight, and
     `orchestrate: done` free where its launch has landed. `orchestrate: stopped`, or `orchestrate:
     done` with a ticket the launch names still open, means held, or parked instead where the launch
     it ran qualifies (Stage 2), and a parked launch's session is free. A session that never ran
     `/orchestrate` is free; any other ending is held.

   Tell the user about every one that is `blocked` or held. This stage arms no watcher. An agent
   under any other name is the
   user's own session in that working copy: name it and ask whether to drive it, which clears its
   conversation before each launch (Stage 3), or wait, because a second session there is the
   collision SESSIONS.md stops on. Go-aheads, the owner's go-on past a parked launch (Stage 2) and
   relays from before a context clear are kept nowhere: ask for them again.

   Then judge each repository's claim — its file, its line and every move-aside file judged as a
   claim (step 2) — by the table in `/orchestrate`'s CLAIMS.md and the rules under it (*A claim found*), as
   that repository's next launch's guard would, read-only and with your own pane reads: the pane
   list above, `herdr agent get <pane>` for the pane the claim names, and for `idle` or `done` its
   last outcome line (*Reading a session*, Stage 4). Read the pane a claim names only where the
   claim's server equals your own server fingerprint, computed as `/orchestrate` Stage 1, *The
   server fingerprint*, computes a session's: a claim whose server differs, a claim naming a pane
   without a server, and every claim where you have no fingerprint are judged in the table's *pane
   unreadable* column. Each of the file, the line and every such move-aside file is judged, and the
   strictest verdict holds: a stop over a question, a question over a take-over (*A move-aside
   file*). A move-aside file judged stale stays a leftover for the owner to remove, since the
   launch's guard neither takes it over nor removes it. A claim is *of this run* when its `run:`
   is the run slug and its `map:` is that repository's map, the one its launch line names
   (Stage 2), in the one form a claim writes it (`/orchestrate`'s CLAIMS.md, *A claim found*): the
   map's reference as its tracker writes it (`#54`, or a key such as `ABC-12`), or the local map's
   path relative to that repository's root with no leading `./`, never prefixed by its folder.
   The row for a claim naming the guard's own pane, and the rule for one carrying its own token with
   that claim's renewal (*This conversation's own claim*), are that guard's alone: skip them. Where
   the *gone* rule sets aside the guard's own pane, set aside the panes of your launches in flight
   or held in that repository, and count every other pane whose cwd is that repository's root or
   any path under it, compared whole path component by whole path component as that rule compares
   it. Each verdict is a take-over, a stop or a question, and Stage 2 says what it does to the
   launches. You take, release, renew, take over and remove no claim: it is its session's, or the
   owner's.

Done when every repository in the run order has a pane, waits for a slot, or was declined a tab by
the user; has a session state and its claim judged; every ticket the order names has a state read
from its tracker; and every lender has the reads its borrow check needs.

**`+ check`** prints exactly that — every launch with its state (Stage 2) and its borrows, each
parked launch as *A parked launch* (Stage 2) says, each
borrowing launch's borrow check per lender with the condition that failed where one did, each
`borrowing` line as Stage 2 says, each
repository's pane and session, each repository's claim — the claim file's fields, the claim line,
every move-aside file judged as a claim with its fields, the pane each names with its server, and
the table's verdict with the pane read behind it — and any leftover beside the file for the owner
to remove, each repository occupied by a session outside the run order as Stage 2 says, the
repositories without a pane, and what is ready with the reply that launches it in this conversation
(`watch` or `step <G>`, with the `+ tabs`, `+ bypass` or `+ sessions <n>` the check was given) —
and stops. A reply naming an argument is that invocation, for the same lead map, from Stage 0,
since a new `/conduct` loads this file into the same context again. It creates, starts and sends nothing,
and takes, releases, renews, takes over and removes no claim.

## Stage 2 — Launches and their states

The unit is the **launch**: one repository wave of one step, `<repository> · <wave> · <tickets>`,
followed by `· borrows <folder>[, <folder>]` where its walk borrows another repository's working copy
(PAIRED.md). Its launch line is `/orchestrate map <that repository's map> + wave <k>`, with
the repository's own wave number, and `+ ceiling 5` appended when that map states an in-flight
ceiling above five. A map's lower ceiling stands. A repository that needs more than five at once is
launched by the user with its own `/orchestrate` line, outside this run's schedule. A launch is:

- **landed** when every ticket it names is closed;
- **released** when everything its step's *Released by* names is closed, each ticket read on its own
  tracker, never inferred from a map's prose. A cell that releases a wave in parts releases it once
  every part holds; the owner's go-ahead is a question for the user, asked once; `—` is released
  from the start;
- **in flight** from its prompt until its session's turn ends on anything but the pause line
  `orchestrate: waiting on executors`;
- **held** while its session's turn has ended on `orchestrate: stopped`, on no outcome line, or on
  `orchestrate: done` with a ticket still open, and it is neither parked nor let out of parking
  (*A parked launch*, below). It waits on the user, who answers or resumes that session in its
  pane or through you (Stage 4, *Relay*); from then it is in flight again;
- **parked** when it has not landed, its session's turn has ended on `orchestrate: done` or
  `orchestrate: stopped — …`, and every ticket it names that is still open carries
  `ready-for-human` or waits on an open blocker. A turn that ended on no outcome line stays held.
  Where its repository shows no session, or one whose last launch line is another launch's, a
  launch that is released, and whose own repository's earlier steps are landed or gone on without
  (*ready*, below), is parked on that ticket condition alone: its launch line would dispatch none
  of those tickets;
- **ready** when it is released, not landed, in flight, held or parked, every launch of its own
  repository in an earlier step has landed or is parked with the owner's go-on (*A parked
  launch*), no other launch in flight, held or parked occupies a repository it occupies, no other
  repository's `borrowing` line holds one (below), no session outside the run order occupies one
  (*Occupied by a session outside the run order*, below), and, where it borrows, every lender
  passes the borrow check (PAIRED.md). That order inside one repository is read from the
  steps, so it holds even where a later step's *Released by* names only other repositories'
  tickets, which is all it names.

A launch **occupies** its own repository and every repository it borrows: one session per working
copy. The rule is symmetric — a launch that borrows a repository waits on that repository's launch
in flight or held, and that repository's next launch waits on the borrower — and a held launch keeps
occupying; a parked one keeps its own repository only (below). A launch that borrows nothing
occupies its own repository alone: one session per repository, its waves in order.

**A parked launch** occupies its own repository and none of those it borrows. Its walk is over, so
its lenders are free; its own repository is kept so that the owner re-plans before that repository
builds further, as a solo session stops at the end of a breach's wave (SESSIONS.md §5). A
`borrowing` line its map still carries holds that lender all the same (*A borrow that outlived its
session*, below). Its session is free: nothing is pending in it, so its slot may be reused (Stage 3)
and it is not one of the sessions in flight. `+ check`, every wake's report (Stage 4) and the stop
report (Stage 5) name each parked launch with its stop report where it ended on one, its
`ready-for-human` tickets, the branch each one's comment names as kept, every other open ticket
with the blocker it waits on, and the three ways out, all the owner's:

1. **Re-plan**: the owner re-labels the ticket `ready-for-agent`. The launch is no longer parked,
   is ready by the usual rule and is relaunched; its orchestrator's reconcile deals with the kept
   branch (`/orchestrate` Stage 1).
2. **Close**: the owner closes the ticket. The launch lands once every ticket it names is closed.
3. **Go on without it**: the owner tells you to go on without the launch. It then counts as
   landed for occupying and for wave order, for this conductor session only; after a context clear,
   ask again, as for go-aheads (Stage 1). The ticket stays `ready-for-human` and still blocks
   whatever its edges block.

A way out that leaves the launch neither landed nor parked — a ticket re-labelled, or a closed one
whose closing unblocks another — has **let it out of parking**: the turn that parked it holds it no
more, so it is ready by the usual rule and is relaunched. After a context clear that turn reads like
one that waits on an answer: where a launch reads as held on `orchestrate: done` or `orchestrate:
stopped — …` and a ticket it names has a kept branch in its comments, ask the user whether it was
parked, and read it as let out of parking only on a yes.

**A lender that fails the borrow check** makes its borrower not ready, and the report names the
lender and the condition that failed, and where it is a claim, the claim's time, host, and pane
with its server, and whether the claim file, the claim line or a move-aside file holds it. The
second condition counts every move-aside file that a second read still finds as a claim standing,
a leftover included (PAIRED.md), and no guard removes one: a live holder's next guard or
ownership check restores its own as its claim file (`/orchestrate` Stage 1, *This conversation's
own claim* and *The ownership check*), and any
other stays until the owner removes it: for such a file the report says the borrower waits on the
owner, whatever the lender's launches do.
The lender's own launch goes by its own state: a session that died mid-batch reads as no session
(Stage 1), and the claim it left as one the table takes over, so its launch is ready and is
relaunched before its borrower, its guard taking that claim over, and its orchestrator's Stage 1
brings the lender back to its recorded commit; one whose turn ended awaiting a go-ahead is held on
the user. Where no launch of the lender is ready, in
flight or held, and no `borrowing` line holds it, nothing scheduled will make it pass, and the
report says the borrower waits on the owner, who clears the condition. A lender a line holds is
reported as *A borrow that outlived its session* says, naming the launch that clears it. Under
`+ watch` that is a nothing-ready stop like any other (Stage 5).

**A borrow that outlived its session.** While a map's execution progress carries `borrowing
<folder> since <time>`, read from the map again at every recompute, `<folder>` is still lent
whatever that map's session is doing (PAIRED.md): the line holds it against every launch but
its own repository's — the lender's own, and any third repository's that borrows it. A launch of
the map's own repository is what clears the line, in its orchestrator's Stage 1, so it is ready by
the usual rule with the borrow check's first condition waived on `<folder>`. A map whose read
keeps failing holds every lender its repository's launches borrow as if it carried the line,
waives nothing, and the report says the read failed, is retried at every recompute, and that the
owner restores access to that tracker. `+ check` and every report name each line read, the lender it
holds and the launch that clears it. Where the map reads and no launch of that repository is ready,
in flight or held, they say the lender waits on the owner, who does that cleanup, or has a session
of that repository do it, and sees the line removed.

**Occupied by a session outside the run order.** A repository is occupied by a session outside the
run order while a claim read there (Stage 1) is one the table would stop or ask on, and is not the
claim of a launch you have in flight or held in that repository; a move-aside file judged as a
claim (Stage 1) is a claim here and below. A claim is such a launch's own where it is of this run
and names the server and pane of the session that runs that launch: your own server fingerprint
(Stage 1), since every session you start runs on your own herdr server, and the pane that session
runs in. The user's own session (Stage 1) holding a claim is outside the run order, as is a session
started by hand in another pane or outside herdr, a claim without a pane, a claim of another
server or naming a pane without a server, another run's claim and an unreadable one.
Every launch that occupies that repository — its own repository's next launch and every launch that
borrows it — is not ready, and waits until the claim is gone or the table would take it over. A
claim the table would take over leaves the launch ready by the usual rule, and that launch's own
guard takes it over when it starts, or leaves it for the owner where it is a move-aside file
(Stage 1); a lender's claim still fails its borrow check, stale or not (PAIRED.md), and is
reported as *A lender that fails the borrow check* says. This decides readiness only: a launch
already in flight, held or parked goes by its own state, and what keeps a second session out of a
working copy is each launch's own guard, which runs whatever you decide (`/orchestrate` Stage 1,
*The single-session guard*).

`+ check`, every wake's report (Stage 4) and the stop report (Stage 5) name each such claim — its
time, host, and pane with its server, or that it names none or names a pane without a server,
whether the claim file, the claim line or a move-aside file holds it, and the table's verdict with
the pane read behind it — the launches it holds, and that the owner either ends that session or
removes its claim: its claim file, `working-copy-claim` in that repository's git common directory,
every move-aside file there judged as a claim, and, where its map carries one, the map's
`claimed:` line, since a claim line left alone still reads as a claim. A session ended without its
release leaves its claim behind: under herdr, on your own server, its pane then reads as stale,
and a claim without a pane, or of another server, stays until the owner removes the file and the
line. No watcher covers that session, so a claim gone is seen on the next wake or the next
`/conduct`. Under `+ watch`, a run held only by such claims is a nothing-ready stop like any other
(Stage 5).

Recompute every state on every wake and at every `/conduct`: a ticket can close inside a wave that
later stops, or by hand. In flight at once: two sessions, or the `+ sessions <n>` the user gave —
one to go slower, more than two only on that explicit number. Neither a held session, which waits
on the user, nor a parked launch's, which is free, counts. State the peak in the first report,
sessions in flight times each launch's executor ceiling, because the machine and the rate limit
both see that number.

## Stage 3 — Launch

**The slots.** A repository without a pane runs in a slot: a pane split from your own tab and
labelled `conduct:<folder>`. There are two, stacked to the right of you, and you create one only
when a ready launch needs it:

- **No slot open**: `herdr pane split --current --direction right --ratio 0.4 --cwd <root> --no-focus`.
  The ratio is the share the pane being split keeps, so you keep two fifths of the width.
- **One slot open**: `herdr pane split <that slot> --direction down --ratio 0.5 --cwd <root> --no-focus`.

Read the new pane's id from `.result.pane.pane_id`, then `herdr pane rename <pane> conduct:<folder>`.
The label is how you recognise your slots after a context clear.

**Two slots hold any number of repositories.** Every launch starts a fresh conversation (step 2),
so a free session has nothing left to keep. When a ready launch has no slot and both exist, take a
slot whose session is free: `herdr pane close <pane>` — it asks nothing and ends that session at
once — then split again for the new repository. Close a pane only when it carries the `conduct:`
label and its session is free, as a parked launch's is (Stage 2); a held or blocked session is
waiting on the user. With both slots in
flight or held, the launch waits.

A repository that already has a pane keeps it and takes no slot. Sessions beyond the second, under
`+ sessions <n>`, each get a tab as `+ tabs` gives every repository. Where your own pane is narrower
than about 120 columns (`herdr pane layout --pane <your pane>`), a split leaves nothing readable:
use tabs for this run and say so.

For each ready launch, in step order, while fewer sessions are in flight than the limit, give its
repository a pane and then:

1. **The session.** Its name is the repository folder lower-cased, every character outside `a-z`,
   `0-9`, `_` and `-` replaced by `-`, prefixed `r-` when it does not start with a letter, cut to 32
   characters, and suffixed `-2` on a clash. A repository without a session gets one:
   `herdr agent start <name> --kind <host> --pane <pane>`, where `<host>` is the agent CLI you run on
   (`claude`, or `codex`). Pass no agent arguments: the user's own settings choose the model and the
   permissions. The one exception is `+ bypass`: append `-- --dangerously-skip-permissions`. Claude
   Code enters that mode only at launch, so a session that was already running keeps its own: name
   each such session in your first report. `agent_not_ready` is a dialog on that pane — folder
   trust, a sign-in, bypass mode's first-use warning — and the user's to answer: name the pane and go
   on with the other launches. Its launch line goes out once the dialog is answered and the launch
   is still ready (Stage 4).
2. **The clear.** One launch, one conversation: unless you started the session for this launch, send
   `herdr agent prompt <name> '/clear'` first, so no earlier wave's context rides into this one.
   Claude Code and Codex both start a fresh conversation in the same process: the session keeps its
   name, its pane and the permission mode it started with, and herdr records no state change. Its
   launch is ready, so the session is free and nothing anyone still has to answer is lost. Go on
   once `herdr agent read <name> --source visible` shows the cleared screen.
3. **The prompt**: `herdr agent prompt <name> '<launch line>'`, in single quotes so no shell expands
   it, with any `'` inside escaped the way your shell does. Read the session's `state_change_seq`
   with `herdr agent get <name>` before you send anything to it: that number is what a watcher
   starts from.

A launch counts as in flight from the moment its launch line is sent, so recompute readiness
(Stage 2) before the next launch of the same pass: a borrower and the next launch of the repository
it borrows are never both started from one pass.

**The watcher runs only under `+ watch`, and there is one.** A single background process covers
every session in flight and every session whose start waits on a dialog. Arm it once, after this
turn's launches, by this skill's full path, in the background so its exit wakes you (on Claude Code,
`run_in_background`), naming each session with the `state_change_seq` you read for it:

```powershell
powershell -NoProfile -File <this skill's directory>/scripts/watch.ps1 -Sessions <name>:<seq>,<name>:<seq>
```

```bash
bash <this skill's directory>/scripts/watch.sh <name>:<seq> <name>:<seq>
```

It polls once a minute and exits when one of those sessions settles after its number — at once when
one already has, so a settle between your read and the watcher is never lost. It prints
`settled <name>` and that session's state. It waits through a pause by itself: a session whose last
outcome line is `orchestrate: waiting on executors` has only handed its turn to its executors. After
an hour with no settle it exits 3, and it exits 1 when a session is gone. A held or parked launch's
session gets no watcher: it waits on the user, and it rejoins the schedule on the next wake or the
next `/conduct`.
A host without background commands runs the same check itself at a long interval.

Done when every ready launch is in flight or waits for a slot, and, under `+ watch`, one watcher
covers them. Without `+ watch`, go to Stage 5.

## Stage 4 — On every wake

The watcher exited. `settled <name>` names the session to act on, by its state. On exit 3, the hour
ran out: read every session in flight the same way, because a session whose turn ended without an
outcome line can still show an old pause line.

- **`blocked`**: a permission prompt or a question on that pane. Tell the user the repository, its
  pane or tab, and what the screen asks. It is still in flight.
- **`idle` or `done`, not prompted yet**: the dialog that held its start is answered. Send its launch
  line now (Stage 3, step 3) only while the launch is still ready (Stage 2); otherwise it waits like
  any other launch and goes out on a later wake or `/conduct` once it is ready.
- **`idle` or `done`**: read the session's last lines. Its **outcome line**, the last line of
  `/orchestrate`'s turn, decides:
  - `orchestrate: waiting on executors`: paused while its executors run in the background. It is
    still in flight.
  - `orchestrate: done`: the launch lands when its tickets are closed. A ticket still open makes it
    parked where it qualifies (Stage 2), and held otherwise.
  - `orchestrate: stopped — …`: when every ticket of the launch is closed it landed anyway, and the
    stop concerns a later step. Otherwise relay its report to the user, whether the launch is parked
    where it qualifies (Stage 2) or held; the user may answer in that tab or through you.
  - No outcome line: the turn ended without saying how, through an API error, a usage limit, an
    interrupt or a context limit. Tell the user, with the screen's last lines. It is held.
- **`unknown`**, or exit 1 (the session is gone): read the pane and tell the user. Send a launch line
  again only after the pane shows it never arrived.

Then recompute every state (Stage 2), launch what is ready (Stage 3), and arm one new watcher over
what is in flight, each session from the `state_change_seq` you last read for it. The wake's report
names each parked launch as *A parked launch* (Stage 2) says, and each repository occupied by a
session outside the run order as *Occupied by a session outside the run order* (Stage 2) says.
Nothing in flight means no watcher, and Stage 5.

**Reading a session**: `herdr agent read <name> --source recent-unwrapped --lines 80`. Where that
comes back blank, read the last assistant message of the session's transcript, and only that
message: herdr gives the transcript's id as `agent_session.value`, and Claude Code keeps it under
`~/.claude/projects/`.

**Relay**: besides `/clear` and launch lines, the only input you give a session is what the user
tells you to send, verbatim. Send text with `herdr agent prompt <name> '<text>'` and a dialog choice with
`herdr agent send-keys`, never with `--wait`: waiting is the watcher's work, and a second waiter is a
second process.
Approvals, answers and go-aheads you were not given wait for the user.

## Stage 5 — Stop

Without `+ watch`, stop once this turn's launches are out. Under `+ watch`, stop when every launch
has landed, or when nothing is in flight and nothing is ready — a run whose only open launches are
parked, held, waiting on a lender or waiting on a repository occupied by a session outside the run
order, among them. Either way no watcher outlives the
stop: a session that settles afterwards is picked up by the next `/conduct`.

The report names each launch with its state, what every open launch waits on and on whom, each
parked launch as *A parked launch* (Stage 2) says, each repository occupied by a session outside the
run order as *Occupied by a session outside the run order* (Stage 2) says, each
relayed question still unanswered, and the next `/conduct` line — without `+ watch`, the line to run
once a session settles. It names the sessions still running, read from `herdr agent list` at the
stop because the user may have closed one meanwhile, by pane label or tab, and marks as safe
to close each one whose repository has no launch left: an idle session still holds memory. The slots
stay open at the stop, and closing them is the user's. A wave that is not in the run order, such as
a follow-up added after planning, is named with its repository's own `/orchestrate` line for the user
to launch. Each repository's closing chain and its promotion stay with its orchestrator and the user.
