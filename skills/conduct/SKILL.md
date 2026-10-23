---
name: conduct
description: Drive a paired run — one run slug across several repositories — from one herdr pane, starting /orchestrate in each repository's own pane in the lead map's run order and handing every decision back to you.
disable-model-invocation: true
---

# Conduct

You are the **conductor** of a paired run: one run slug delivered in several repositories, each with
its own working copy, tracker, map and `/orchestrate` session
([../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §8). You start those sessions in their
herdr panes in the order the lead map's *Run order across repositories* gives, sleep until one
settles, and start what that releases. Each orchestrator owns its own run: dispatch, verification,
merges, its map and its close. You own the schedule only. Every decision stays the user's: you
**relay**, verbatim, and leave unanswered what you were not told to send.

```
/conduct <lead map>                  every remaining launch of the run order
/conduct <lead map> + step <G>       the launches of one named step
/conduct <lead map> + check          read-only: the launches, panes and sessions, and what is ready
/conduct <lead map> + sessions <n>   up to n sessions in flight instead of five
```

The lead map is a path, or a tracker reference prefixed by its repository's folder (`portal#12`):
your working directory is no repository, so a bare `#12` resolves nowhere.

## Stage 0 — Preconditions

1. `HERDR_ENV` is `1`. Otherwise say that `/conduct` runs only inside herdr, and stop.
2. Call the Skill tool for `herdr`: its CLI and safety rules govern every herdr command below. Where
   that skill is not installed, run `herdr --skill` and read its output instead.
3. Your working directory is the folder that holds the run's repositories, outside every one of them
   (`git rev-parse --show-toplevel` fails there). Inside one of them you would be a second agent
   session in its working copy: say so and stop.

Done when all three hold.

## Stage 1 — Read the run

1. **The lead map**: its run slug, its *Paired runs* line and its *Run order across repositories*,
   in the format of SESSIONS.md §8. A lead map without the run order is a stop: say what is missing.
2. **Every repository's map**, through that repository's own tracker, from inside that repository
   ([../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md)): its execution-progress section,
   and the state of every ticket the run order names.
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

   Arm a watcher (Stage 3) on every session in flight or held, from its current `state_change_seq`,
   and tell the user about every one that is `blocked` or held. An agent under any other name is the
   user's own session in that working copy: name it and ask whether to drive it or wait, because a
   second session there is the collision SESSIONS.md stops on. Go-aheads and relays from before a
   context clear are kept nowhere: ask for them again.

Done when every repository in the run order has a pane, or the user declined one, and a session
state, and every ticket the order names has a state read from its tracker.

**`+ check`** prints exactly that — every launch with its state (Stage 2), each repository's pane and
session, the repositories without a pane, and what is ready — and stops. It creates, starts and sends
nothing.

## Stage 2 — Launches and their states

The unit is the **launch**: one repository wave of one step, `<repository> · <wave> · <tickets>`.
Its launch line is `/orchestrate map <that repository's map> + wave <k>`, with the repository's own
wave number. A launch is:

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

Recompute every state on every wake, of any kind: a ticket can close inside a wave that later stops,
or by hand. In flight at once: five sessions, or the `+ sessions <n>` the user gave. A held session
does not count until it works again. State the peak in the first report, sessions in flight times
each map's executor ceiling, because the rate limit sees that number.

## Stage 3 — Launch

For each ready launch, in step order, while a slot is free:

1. **The session.** Its name is the repository folder lower-cased, every character outside `a-z`,
   `0-9`, `_` and `-` replaced by `-`, prefixed `r-` when it does not start with a letter, cut to 32
   characters, and suffixed `-2` on a clash. A repository without a session gets one:
   `herdr agent start <name> --kind <host> --pane <pane>`, where `<host>` is the agent CLI you run on
   (`claude`, or `codex`). Pass no agent arguments: the user's own settings choose the model and the
   permissions. `agent_not_ready` is a dialog on that pane — folder trust, a sign-in — and the user's
   to answer: name the tab, arm its watcher, and go on with the other launches.
2. **The prompt**: `herdr agent prompt <name> '<launch line>'`, in single quotes so no shell expands
   it, with any `'` inside escaped the way your shell does. Then arm its watcher.

**The watcher.** Every session you are responsible for has exactly one armed, from the moment you
start or prompt it until its launch lands. Read its `state_change_seq` with `herdr agent get <name>`
before you act on the session, then start this skill's watcher by its full path, in the background
so its exit wakes you (on Claude Code, `run_in_background`):

```powershell
powershell -NoProfile -File <this skill's directory>/scripts/watch.ps1 -Agent <name> -AfterSeq <seq>
```

```bash
bash <this skill's directory>/scripts/watch.sh <name> <seq>
```

It exits once the session settles after that number, at once when it already has, so a settle
between your read and the watcher is never lost; it prints the session's state, its new
`state_change_seq` included. To **re-arm**, start a new watcher from that printed number. A host
without background commands runs the same check itself at a long interval.

Done when every ready launch is in flight or waits for a slot, and every session in flight or held
has its watcher.

## Stage 4 — On every wake

A watcher exited. Act on the session it names, by its exit and its state:

- **`blocked`**: a permission prompt or a question on that pane. Tell the user the repository, its tab
  and what the screen asks. Re-arm.
- **`idle` or `done`, not prompted yet**: the dialog that held its start is answered. Send its launch
  line now (Stage 3, step 2).
- **`idle` or `done`**: read the session's last lines. Its **outcome line**, the last line of
  `/orchestrate`'s turn, decides:
  - `orchestrate: waiting on executors`: paused while its executors run in the background. Re-arm.
  - `orchestrate: done`: the launch lands when its tickets are closed. A ticket still open makes it
    held.
  - `orchestrate: stopped — …`: when every ticket of the launch is closed it landed anyway, and the
    stop concerns a later step. Otherwise it is held: relay its report to the user and re-arm, since
    the user may answer in that tab or through you.
  - No outcome line: the turn ended without saying how, through an API error, a usage limit, an
    interrupt or a context limit. Tell the user, with the screen's last lines. It is held. Re-arm.
- **`unknown`**, or exit 1 (the session is gone): read the pane and tell the user. Send a launch line
  again only after the pane shows it never arrived.

Then recompute every state (Stage 2) and launch what is ready (Stage 3).

**Reading a session**: `herdr agent read <name> --source recent-unwrapped --lines 80`. Where that
comes back blank, read the last assistant message of the session's transcript, and only that
message: herdr gives the transcript's id as `agent_session.value`, and Claude Code keeps it under
`~/.claude/projects/`.

**Relay**: besides launch lines, the only input you give a session is what the user tells you to
send, verbatim. Send text with `herdr agent prompt <name> '<text>'` and a dialog choice with
`herdr agent send-keys`, never with `--wait`, because the session's watcher is already armed.
Approvals, answers and go-aheads you were not given wait for the user.

## Stage 5 — Stop

Stop when every launch has landed, or when nothing is in flight and nothing is ready. Stopping ends
your turn, not the watchers: a held session that works again wakes you, and you go on from Stage 4.

The report names each launch with its state, what every open launch waits on and on whom, each
relayed question still unanswered, and the next `/conduct` line. It names the sessions still
running, by tab: they stay open for the user to close. A wave that is not in the run order, such as
a follow-up added after planning, is named with its repository's own `/orchestrate` line for the user
to launch. Each repository's closing chain and its promotion stay with its orchestrator and the user.
