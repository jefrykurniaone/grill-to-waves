---
name: conduct
description: Drive a paired run — one run slug across several repositories — from one herdr pane, starting /orchestrate in each repository's own pane in the lead map's run order and handing every decision back to you.
disable-model-invocation: true
---

# Conduct

You are the **conductor** of a paired run: one run slug delivered in several repositories, each with
its own working copy, tracker, map and `/orchestrate` session
([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §8). You start those sessions in their
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
/conduct <lead map> + bypass         the sessions you start skip permission prompts (Claude Code)
```

`+ watch`, `+ bypass`, `+ step` and `+ sessions` combine.

**The numbers are sized for one laptop**: two sessions in flight, five executors in each, no
background process unless you ask for one. Each executor runs the gate in its own worktree, so the
peak is ten test and build runs at once.

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
   in the format of SESSIONS.md §8. A lead map without the run order is a stop: say what is missing.
2. **Every repository's map**, through that repository's own tracker, from inside that repository
   ([../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md)): its execution-progress section,
   its in-flight ceiling, and the state of every ticket the run order names. The ticket states are a
   table with no decision in it: where `clerk-haiku-medium` is installed, give it one brief per
   repository — run the tracker's list command from inside that repository, return each named
   ticket's state as printed, touch nothing in the tree — and read them yourself where it is not.
3. **Panes**: `herdr pane list` in every workspace. A repository's pane is the one whose cwd is that
   repository's root; where there are several, ask which. Put every repository without a pane into
   one question, and create a tab only for those the user agrees to:
   `herdr tab create --cwd <root> --label <folder> --no-focus`, in your own workspace.
4. **Each repository's session**, the agent in its pane under the name Stage 3 gives it:
   - none, or a shell at its prompt: no session yet;
   - `working` or `blocked`: in flight;
   - `idle` or `done`: read it (*Reading a session*, Stage 4). The pause line means in flight,
     `orchestrate: stopped` held, and `orchestrate: done` free. A session that never ran
     `/orchestrate` is free; any other ending is held.

   Tell the user about every one that is `blocked` or held. This stage arms no watcher. An agent
   under any other name is the
   user's own session in that working copy: name it and ask whether to drive it, which clears its
   conversation before each launch (Stage 3), or wait, because a second session there is the
   collision SESSIONS.md stops on. Go-aheads and relays from before a
   context clear are kept nowhere: ask for them again.

Done when every repository in the run order has a pane, or the user declined one, and a session
state, and every ticket the order names has a state read from its tracker.

**`+ check`** prints exactly that — every launch with its state (Stage 2), each repository's pane and
session, the repositories without a pane, and what is ready — and stops. It creates, starts and sends
nothing.

## Stage 2 — Launches and their states

The unit is the **launch**: one repository wave of one step, `<repository> · <wave> · <tickets>`.
Its launch line is `/orchestrate map <that repository's map> + wave <k>`, with the repository's own
wave number, and `+ ceiling 5` appended when that map states an in-flight ceiling above five. A map's
lower ceiling stands. A repository that needs more than five at once is launched by the user with its
own `/orchestrate` line, outside this run's schedule. A launch is:

- **landed** when every ticket it names is closed;
- **released** when everything its step's *Released by* names is closed, each ticket read on its own
  tracker, never inferred from a map's prose. A cell that releases a wave in parts releases it once
  every part holds; the owner's go-ahead is a question for the user, asked once; `—` is released
  from the start;
- **in flight** from its prompt until its session's turn ends on anything but the pause line
  `orchestrate: waiting on executors`;
- **held** while its session's turn has ended on `orchestrate: stopped`, on no outcome line, or on
  `orchestrate: done` with a ticket still open, until that session works again;
- **ready** when it is released and none of the above, and no other launch of its repository is in
  flight or held: one session per repository, its waves in order.

Recompute every state on every wake and at every `/conduct`: a ticket can close inside a wave that
later stops, or by hand. In flight at once: two sessions, or the `+ sessions <n>` the user gave —
one to go slower, more than two only on that explicit number. A held session does not count until it
works again. State the peak in the first report, sessions in flight times each launch's executor
ceiling, because the machine and the rate limit both see that number.

## Stage 3 — Launch

For each ready launch, in step order, while a slot is free:

1. **The session.** Its name is the repository folder lower-cased, every character outside `a-z`,
   `0-9`, `_` and `-` replaced by `-`, prefixed `r-` when it does not start with a letter, cut to 32
   characters, and suffixed `-2` on a clash. A repository without a session gets one:
   `herdr agent start <name> --kind <host> --pane <pane>`, where `<host>` is the agent CLI you run on
   (`claude`, or `codex`). Pass no agent arguments: the user's own settings choose the model and the
   permissions. The one exception is `+ bypass`: append `-- --dangerously-skip-permissions`. Claude
   Code enters that mode only at launch, so a session that was already running keeps its own: name
   each such session in your first report. `agent_not_ready` is a dialog on that pane — folder
   trust, a sign-in, bypass mode's first-use warning — and the user's to answer: name the tab and go
   on with the other launches. Its launch line goes out once the dialog is answered (Stage 4).
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

**The watcher runs only under `+ watch`, and there is one.** A single background process covers
every session in flight and every session whose start waits on a dialog. Arm it once, after this
turn's launches, by this skill's full path, in the background so its exit wakes you (on Claude Code,
`run_in_background`), giving each session with the `state_change_seq` you read for it:

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
an hour with no settle it exits 3, and it exits 1 when a session is gone. A held session gets no
watcher: it waits on the user, and it rejoins the schedule on the next wake or the next `/conduct`.
A host without background commands runs the same check itself at a long interval.

Done when every ready launch is in flight or waits for a slot, and, under `+ watch`, one watcher
covers them. Without `+ watch`, go to Stage 5.

## Stage 4 — On every wake

The watcher exited. `settled <name>` names the session to act on, by its state. On exit 3, the hour
ran out: read every session in flight the same way, because a session whose turn ended without an
outcome line can still show an old pause line.

- **`blocked`**: a permission prompt or a question on that pane. Tell the user the repository, its tab
  and what the screen asks. It is still in flight.
- **`idle` or `done`, not prompted yet**: the dialog that held its start is answered. Send its launch
  line now (Stage 3, step 3).
- **`idle` or `done`**: read the session's last lines. Its **outcome line**, the last line of
  `/orchestrate`'s turn, decides:
  - `orchestrate: waiting on executors`: paused while its executors run in the background. It is
    still in flight.
  - `orchestrate: done`: the launch lands when its tickets are closed. A ticket still open makes it
    held.
  - `orchestrate: stopped — …`: when every ticket of the launch is closed it landed anyway, and the
    stop concerns a later step. Otherwise it is held: relay its report to the user, who may answer in
    that tab or through you.
  - No outcome line: the turn ended without saying how, through an API error, a usage limit, an
    interrupt or a context limit. Tell the user, with the screen's last lines. It is held.
- **`unknown`**, or exit 1 (the session is gone): read the pane and tell the user. Send a launch line
  again only after the pane shows it never arrived.

Then recompute every state (Stage 2), launch what is ready (Stage 3), and arm one new watcher over
what is in flight, each session from the `state_change_seq` you last read for it. Nothing in flight
means no watcher, and Stage 5.

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
has landed, or when nothing is in flight and nothing is ready. Either way no watcher outlives the
stop: a session that settles afterwards is picked up by the next `/conduct`.

The report names each launch with its state, what every open launch waits on and on whom, each
relayed question still unanswered, and the next `/conduct` line — without `+ watch`, the line to run
once a session settles. It names the sessions still running, by tab, and marks as safe to close each
one whose repository has no launch left: an idle session still holds memory, and closing it is the
user's. A wave that is not in the run order, such as
a follow-up added after planning, is named with its repository's own `/orchestrate` line for the user
to launch. Each repository's closing chain and its promotion stay with its orchestrator and the user.
