# Claims found by the guard

The single-session guard of [SKILL.md](SKILL.md) Stage 1 reads this file whenever it finds a claim
file or a claim line other than this conversation's own claim, or a move-aside file beside the claim
file; `+ check` reads it for the same finds. It holds the table that judges such a claim, the one
question the guard asks about it, what a move-aside file is, and what the guard cannot see.

**A claim found** — a claim file, a claim line, or both — is judged by this table. A claim is *of
this run* when its `run:` is this run's slug and its `map:` is this map's reference in the one
form a claim writes it and every reader compares it: the map's reference as its tracker writes it
(`#54`, or a key such as `ABC-12`), or the local map's path relative to the repository root with no
leading `./` (`.scratch/<run-slug>/map.md`). Under herdr
(`HERDR_ENV=1`), the pane a claim names is read only where the claim's server equals this session's
server fingerprint ([SKILL.md](SKILL.md) Stage 1, *The working-copy claim*), since a pane id means something only on its
own herdr server. Read it read-only, with the herdr skill's read commands, as
`/conduct` reads a session: `herdr pane list` in every workspace says whether the pane exists and
what its cwd is, `herdr agent get <pane>` gives its agent's state, and for `idle` or `done` its last
outcome line is read as `/conduct` Stage 4, *Reading a session*, reads it. A claim whose server
differs from this session's fingerprint, a claim that names a pane without a server (one written
before claims carried a server), and every claim where this session has no fingerprint are judged
in the table's *pane unreadable* column.

| Found | Under herdr, the pane read on this session's server | Outside herdr, or the pane unreadable: another server, a pane without a server, or no fingerprint here |
|---|---|---|
| No claim file, no claim line | take | take |
| A claim file of another run or another map, or one that cannot be read | stop; report the file; the owner removes it, and its map's `claimed:` line where that map carries one | same |
| A claim of this run naming this session's own pane, by its server and its pane both | stale: take over, name it in the report | — |
| A claim of this run naming a pane that is gone or holds no agent | stale: take over | ask |
| A claim of this run whose agent is `working` or `blocked` | live: stop, name the pane | ask |
| A claim of this run, `idle` or `done`, its last outcome line the pause line | live: stop | ask |
| A claim of this run, `idle` or `done`, any other last line or none | stale, its turn ended without release: take over | ask |
| `unknown`, or a claim without a pane | ask | ask |
| A claim line without a claim file | judged by the rows above by the line's server and pane where it names both; ask otherwise | ask |

A pane counts as **gone** only where no pane whose cwd is this working copy's root or any path
under it, other than this session's own pane, holds an agent that is `working`, `blocked`, or
`idle` or `done` on the pause line. The cwd is compared with the root whole path component by whole path
component, so a sibling folder whose name begins with the root's name never counts. A pane moved to
another herdr workspace gets a new id, so its old id reads as gone while its session lives, and
where such a pane exists the guard asks instead.

**The question is the guard's one question**, widened: it is asked only where the guard asks about
a claim, and then covers the claim and the open tickets' worktrees (SKILL.md Stage 1, *The single-session guard*), and names the claim's
time, host, and pane with its server, or that it names none or names a pane without a server.
Confirmed: take the claim over, and the reconcile handles the worktrees as SKILL.md Stage 1, *Reconcile before dispatching anything*,
says. Not confirmed:
stop. An answer this conversation already holds is not asked again; it covers the worktrees and the
claim's token it named, and a claim with another token is a new question. Where the guard clears —
nothing found, a stale claim, this conversation's own claim, or the user's confirmation — take the
claim, take it over, or renew it, before anything else in this stage writes; where the guard
cleared without a question, the open tickets' worktrees go to the reconcile without one (SKILL.md Stage 1, *The single-session guard*). A
take-over is named in the wave report, or in the turn's report where no wave runs; a renewal of
this conversation's own claim is not. A stop of the guard's own takes nothing and cleans up
nothing; a restore it made before the stop stays, its claim file holding what the move-aside file
held.

**A move-aside file**, `working-copy-claim.<token>` beside the claim file, is the name a take-over
or a release passes the claim file through, never a claim file itself; another session's take-over
or release passes through that name for an instant, so only a file that a second read still finds
is evidence. The guard and `+ check` read every such file, and `+ check` restores none. Where the
guard finds no claim file, one that a second read still finds and that carries this conversation's
own token, and its own pane by that paragraph's rule, is restored and renewed, not judged by the
table (SKILL.md Stage 1, *This conversation's own claim*). Any other one that a second read still finds and
that holds a claim of this run, one kept where the restore's create failed included, is judged by
the table's rows beside the claim file and the claim line, and the strictest verdict holds: a stop over a question, a question over a take-over. One
judged stale stays a leftover: the guard neither takes it over nor removes it, and reports it for
the owner to remove. Any other such file that a second read still finds is a leftover, as a
take-over's or a release's: the guard and `+ check` report it, and the owner removes it.

The guard sees every `/orchestrate` session in this working copy at every moment of its turn,
whichever host runs it: by its registered worktrees while a wave is in flight, and by its claim from
its guard to its outcome line. **Its residual risk** is what it cannot see, or cannot judge without
asking: an agent session that runs no `/orchestrate`, such as the owner working by hand, which
makes no worktree and takes no claim; a claim left by a session that died outside herdr, or written
under another herdr server or on another machine, which it cannot tell stale, so it costs the next
session one question; a terminal nested inside a herdr pane that neither renames the terminal
program nor sets a multiplexer's marker, whose session reads the outer pane as its own pane; and
the window between a take-over's read of the claim file and its move, in which a fresh claim
another session has just written can be moved aside. The guard's restore, which comes before its
judgment, adds a cost in liveness, never a second session: where a conversation whose release died
mid-way is resumed after another session took a fresh claim, and its guard lands between that
holder's move and its create in a renewal, the restore wins the create, the holder's create fails
and it stops, and the restoring guard then stops on the holder's live claim line. Neither proceeds
until the holder's next turn takes the restored claim over as stale, at the cost of one prompt.
