# spec: working-copy-claim v1 - a working-copy claim the single-session guard sees at every moment of a session's turn

Spec: [#50](https://github.com/jefrykurniaone/grill-to-waves/issues/50) · Map: [#54](https://github.com/jefrykurniaone/grill-to-waves/issues/54) · Tickets: [#51](https://github.com/jefrykurniaone/grill-to-waves/issues/51), [#52](https://github.com/jefrykurniaone/grill-to-waves/issues/52), [#53](https://github.com/jefrykurniaone/grill-to-waves/issues/53)

Copied 2026-11-17 onto `feat/working-copy-claim`. Below this header, the body of #50 verbatim; the issue, not this file, is the spec.

---

As of 2026-11-17: written against `main` @ `928a004`.

## Problem statement

The owner executes delivery runs with `/orchestrate`, one session per working copy, and with `/conduct` when a run spans several repositories. As of `main` @ `928a004`, `/orchestrate`'s single-session guard (Stage 1) decides whether another agent session is live in this working copy by reading `git worktree list` alone. A worktree registered under `.claude/worktrees/<run-slug>/` for an open ticket prompts one question to the user, and a registered worktree anywhere else is a stop. A live session of the same run registers a worktree only while a wave's tickets are in flight, so it is invisible:

- from its Stage 1 until its first dispatch;
- between waves under `+ all`, after one wave's teardown and before the next dispatch;
- through the whole close: the delivery notes, the mirror pass, the final sync, the gate and the close's walk, the push and the review request.

A hand relaunch of a session that only looked hung, at one of those moments, passes the guard and acts on the working copy beside the live one: the tree, the dev server and the dev database (#45). As of `928a004` the guard's paragraph ends "if it is clear nothing else can collide with you here", which those moments contradict.

The same read is the borrow check's second condition in SESSIONS §6 ("It is the lender's single-session guard's own read"), so a lender's session between waves passes the check as well. §6 states as residual risk that an owner's session in a lender that makes no worktree is seen only by `/conduct`'s pane read, and not at all outside herdr. And *A borrowed walk that died* cleans up only once the guard has cleared (#38): safe as of `928a004` only because every borrowed walk runs while its batch's ticket worktrees are still registered, and a check pinned to the close cannot borrow.

## Solution

A session that acts in a working copy **takes a working-copy claim** there the moment its guard clears, and **releases** it when its turn ends on anything but the pause line. The claim is recorded twice: a claim file in the clone's git common directory, which is the authority and the only mutual exclusion, and a claim line on the map's execution progress, which is the tracker's copy. The guard reads both beside `git worktree list`. Under herdr it reads the pane a claim names to tell a live claim from a stale one; otherwise it asks the user, inside the one question it already asks. A session checks that its claim is still its own before it writes, and stops if another session has taken over. The borrow check and `/conduct` read claims too, so a lender's session, or a session started outside `/conduct`, is seen at every moment of its turn.

## Goals and non-goals

Goals:

- An `/orchestrate` session in flight is seen by any other `/orchestrate` session's guard in the same working copy at every moment of its turn — before its first dispatch, between waves and through the close — whichever host each runs on.
- Two launches started at the same moment in one working copy cannot both proceed.
- A claim left by a session that died costs at most one question, and none under herdr where its pane shows the session gone.
- A session taken over by mistake stops before its next write and never removes the other session's claim.
- The borrow check and `/conduct` see an `/orchestrate` session in a repository at every moment of its turn, outside herdr included.
- `+ check` reports claims and changes none.

Non-goals:

- Letting a check pinned to the close borrow a working copy (`peer:`). This spec makes the guard's answer trustworthy at the close, which that change would need, and does not make the change.
- A borrower taking a claim in its lender's working copy; the `borrowing` line still holds the lender.
- Seeing an agent session that runs no `/orchestrate`, such as an owner working by hand; it takes no claim and stays a stated residual risk.
- Heartbeats or timeouts: a claim's age never makes it stale.
- Migrating sessions in flight under the old rules.
- Changing any agent definition.

## User stories

1. As an owner who relaunches a session that looked hung between waves, I want the new session to see the old one's claim and stop or ask, so that two sessions never act on one tree.
2. As an owner who relaunches a session that looked hung during the close, I want the same, so that the push and the review request are made once, by one session.
3. As an owner who relaunches before the first dispatch, I want the same, so that the cut and the first reconcile are made once.
4. As an orchestrator under herdr whose found claim names a pane that is gone or holds no agent, I want to take it over without asking, so that a crash costs no question.
5. As an orchestrator under herdr whose found claim names my own pane, I want to take it over, because the conversation that took it is gone.
6. As an orchestrator under herdr whose found claim names a pane whose agent is working, blocked, or idle on the pause line, I want to stop and name that pane, so that the owner ends that session first.
7. As an orchestrator outside herdr, or facing a claim without a pane or a pane herdr cannot classify, I want to ask the user inside the guard's one question, merged with the question about open tickets' worktrees.
8. As an orchestrator that finds another run's claim, or a claim file it cannot read, I want to stop and report the file, so that the owner removes it.
9. As an orchestrator that finds a claim line on the map with no claim file in this working copy, I want to judge it by its pane where it names one and ask otherwise, because it is a claim from another working copy or a stale line.
10. As one of two launches started at the same moment, I want the exclusive create to let only one proceed and the other stop.
11. As an orchestrator whose turn ends on `orchestrate: done` or `orchestrate: stopped — …`, I want to release my claim as the last act before the outcome line, so that a relaunch after a stop costs no question.
12. As an orchestrator whose turn ends on `orchestrate: waiting on executors`, I want to keep my claim, because I am still in flight.
13. As an orchestrator answered after a stop, I want to take my claim again through the guard's read and run Stage 1's reads again before acting on the answer, so that I never act on a view another session changed meanwhile; what the user already answered in my conversation is not asked again.
14. As an orchestrator, I want to check at each tree preflight, at each close step and before release that the claim file still carries my token, and to stop without writing anything more where it does not, so that a mistaken take-over costs at most the work in flight.
15. As a conductor, I want every repository's claim read at every recompute and judged as the guard would judge it, so that a repository whose session runs outside my panes is occupied, and a stale claim does not hold a launch whose guard would clear it.
16. As a borrowing orchestrator or a conductor, I want a lender holding a claim to fail the borrow check's second condition, so that a lender's session between waves is seen.
17. As an owner running `+ check` on either skill, I want the claim file, the claim line and the pane's verdict reported, and nothing taken, released or taken over.
18. As an owner updating the skills, I want the changelog to tell me to finish or stop every session in flight first, because a session on the old rules takes no claim and a session on the new rules cannot see it.
19. As a reader of the glossary, I want *Working-copy claim* defined, so that "claim", "take" and "release" mean one thing everywhere.

## Implementation decisions

**The claim file.** One file per clone, named `working-copy-claim`, at the top of the clone's git common directory (`git rev-parse --path-format=absolute --git-common-dir`). Why there: it is host-neutral, so a Claude Code session and a Codex session see each other, which `.claude/` and `.codex/` would not give; it never shows in `git status`, so the tree preflight and the borrow check's first condition are untouched; every worktree of the clone shares it; and the run already writes `info/exclude` in the same directory. Its content, one field per line:

```
token: <host>-<UTC time taken, compact>-<8 random hex digits>
run: <run slug>
map: <map reference>
host: claude | codex | <other>
since: <UTC time taken, ISO 8601>
pane: <HERDR_PANE_ID>        (only where it is set)
```

It is created **exclusively** — in bash a `set -C` (noclobber) redirection, in PowerShell `New-Item` without `-Force` — so of two sessions taking at once, one fails, and that one stops. A take-over removes the stale file and creates it again exclusively. Why a file and not only a tracker line: a tracker write is not atomic, and the guard's question is about this working copy.

**The claim line.** On the map's execution progress, beside the other live-state lines:

```
claimed: <token> since <time> · <host>[ · pane <id>]
```

It carries no path and no machine name, because the map is public on a public repository. Take writes the file, then the line; release removes the line, then the file, so a crash between them leaves the local file, the stronger evidence. The line is written at take, before any other write, and removed at release, after the last one. Why a tracker copy at all: `/conduct` and `+ check` already read the map, it reaches a session started outside herdr, and nothing is true until it is on the tracker.

**Lifecycle.** The claim is taken when the guard clears: before the reconcile and before *A borrowed walk that died*. It is held while the launch is in flight in `/conduct`'s sense, through every turn that ends on `orchestrate: waiting on executors`. It is released as the last act before any other outcome line — `orchestrate: done` or `orchestrate: stopped — …`, a stop that asks a question included. A later turn of the same session, such as an answer to its stop, takes the claim again through the guard's read and runs Stage 1's four reads again before acting on the answer; an answer the user already gave in that conversation is not asked again. Why turn-scoped: a claim held across a stop would cost a question at every relaunch after one outside herdr, and would make "idle after a stop" mean live under herdr. Held only while in flight, the claim means exactly what `/conduct` calls in flight. `+ check` never takes, releases or takes over a claim.

**The guard's table.** The guard reads `git worktree list`, the claim file and the map's claim line; the map is already read in Stage 1. Under herdr (`HERDR_ENV=1`) it reads the pane a claim names, read-only, with the herdr skill's read commands, as `/conduct` does: the agent's state and, for `idle` or `done`, its last outcome line as `/conduct`'s *Reading a session* reads it.

| Found | Under herdr | Outside herdr, or the pane unreadable |
|---|---|---|
| No claim file, no claim line | take | take |
| A claim file of another run or another map, or one that cannot be read | stop; report the file; the owner removes it | same |
| A claim of this run naming this session's own pane | stale: take over, name it in the report | — |
| A claim of this run naming a pane that is gone or holds no agent | stale: take over | ask |
| A claim of this run whose agent is `working` or `blocked` | live: stop, name the pane | ask |
| A claim of this run, `idle` or `done`, its last outcome line the pause line | live: stop | ask |
| A claim of this run, `idle` or `done`, any other last line or none | stale, its turn ended without release: take over | ask |
| `unknown`, or a claim without a pane | ask | ask |
| A claim line without a claim file | judged by the rows above by the line's pane where it names one; ask otherwise | ask |

"Gone" counts only where no other pane whose cwd is this working copy's root holds an agent that is `working`, `blocked` or idle on the pause line. A pane moved to another herdr workspace gets a new id, so its old id reads as gone while its session lives; where such a pane exists, the guard asks instead. The question is the guard's existing one, widened: one question covering the open tickets' worktrees and the claim, naming the claim's time, host and pane. Confirmed: take over. Not confirmed: stop. A take-over is named in the wave report. A stop of the guard's own takes nothing and cleans up nothing, as before.

**Ownership checks.** The tree preflight checks, before its first numbered step, that the claim file carries this session's token. Each close step begins with the same check, since the tree preflight does not run at the close, and so does release. A mismatch, or a missing file, is a stop: nothing more is written, neither the file nor the line is removed, and the report says another session took this working copy. No existing step or section is renumbered, since other passages cite them by number.

**The borrow check.** SESSIONS §6's second condition widens: no registered worktree besides the lender's main working copy, no claim file in the lender's git common directory, and no claim line on the lender's map, which the third condition already reads. The check still only reads. *A borrow that outlived its session* still waives only the first condition.

**`/conduct`.** Stage 1 reads every repository's claim: its claim line from the map it already reads, and its claim file through `git -C <folder> rev-parse --path-format=absolute --git-common-dir`. It judges each claim by the guard's table, read-only, with its own pane reads. A claim the table would take over leaves that repository's launch ready by the usual rule, and the launch's own guard takes it over. A claim the table would stop or ask on, that is not the claim of a launch `/conduct` has in flight or held there, makes the repository **occupied by a session outside the run order**: every launch occupying that repository waits, and `+ check` and every report name the claim and say that the owner ends that session or removes its claim file.

**`+ check`.** Both skills report the claim file's fields, the claim line and the table's verdict with the pane read behind it. Nothing is taken, released or taken over.

**What the protocol says about a second session.** The guard's closing sentence, "That is one cheap read, and if it is clear nothing else can collide with you here", is rewritten to say what the guard sees and what it cannot. SESSIONS §5's "a second agent session found in this working copy" counts a live claim. SESSIONS §6's residual risk narrows to two cases: an agent session that runs no `/orchestrate` takes no claim, so in a lender it is still seen only by `/conduct`'s pane read and not at all outside herdr; and a claim left by a session that died outside herdr costs the next session one question. `/grill-to-waves` Stage 5's *How this is executed* names the claim beside "one agent session per working copy".

**Glossary, changelog and README.** The glossary gains *Working-copy claim*: the record that one orchestrating session is acting in a working copy, held while its launch is in flight; a session that dies leaves it behind, and only its pane or the user can say it is stale. _Avoid_: lock, session lock, marker. "Lock" is avoided because git's own `*.lock` files and the index lock the borrow check stays off already use the word. The changelog gains a dated entry whose *After updating* says to finish or stop every `/orchestrate` session in flight before running the installer again. The README agrees where it describes one session per working copy.

**The parent.** #45 is this spec's parent item, so the close posts a delivery summary there and closes it.

## Testing decisions

A good test here checks what a session reading the skills will do, not how the text is worded. These skills have no unit under test; four seams cover them:

1. **The install test** (`bash tests/test-install.sh`), every wave. It catches a broken installer and the literals it asserts in the orchestrate skill (`.codex/worktrees`, `../grill-to-waves/`, and `$grill-to-waves` after the Codex rewrite), which must survive. It cannot catch a contradiction between rules.
2. **The consistency sweep**, at the close: a grep for the replaced wording ("if it is clear nothing else can collide with you here", and §6's "seen only by `/conduct`'s pane read, and not at all outside herdr" in its old, unnarrowed form), a check that every `§`, numbered-step and section reference still lands, then one read-only analyst reading the changed skills end to end, as a solo and as a paired session would, through five scenarios: a relaunch between waves, a relaunch at the close, a `/clear` and relaunch in the same pane, a session that died outside herdr, and a lender holding a claim. It catches contradictions and dangling references; it cannot catch behaviour only a real run shows.
3. **CI on the run's draft review request**: the docs check (no tier named with a version number, agent frontmatter YAML reads), shellcheck, PSScriptAnalyzer and the Windows install tests, which this machine cannot run. It cannot catch what a rule means.
4. **A sandbox run after the close**, in throwaway repositories, on the recipe of the previous run's: a claim file naming a closed pane, which the guard takes over; a live session interrupted after its cut, with a second launch in another pane, which stops; and `/conduct + check` over a repository holding a claim, which reads as occupied. It catches the real herdr reads and the exclusive create; it cannot catch Windows or Codex.

Prior art: the previous runs' maps (#16, #29, #44), their consistency sweeps (seam 2) and CI (seam 3), and #44's sandbox run (seam 4).

## Success criteria

- `/orchestrate`'s guard reads the claim file and the claim line beside `git worktree list` and applies the table, and its paragraph no longer says that nothing else can collide once that read is clear.
- A claim is taken exclusively when the guard clears, kept across the pause line, released before every other outcome line, and taken again by a later turn of the same session, which runs Stage 1's reads again.
- The tree preflight, each close step and release check the claim is the session's own, without renumbering a step; a mismatch stops with nothing written.
- SESSIONS §6's second condition reads the lender's claim; §5 counts a live claim as a second session; the residual risk names only sessions that run no `/orchestrate` and a stale claim outside herdr.
- `/conduct` reads every repository's claim, judges it by the guard's table, and names a repository occupied by a session outside the run order together with what clears it.
- `+ check` in both skills reports claims and writes nothing.
- The glossary defines *Working-copy claim*; the changelog has a dated entry with its *After updating*; the README agrees.
- The install test passes; CI is green on the draft review request; the consistency sweep reports no contradiction across its five scenarios.

## Out of scope

- A borrow by a check pinned to the close.
- A borrower's claim in its lender's working copy.
- Heartbeats, timeouts or any age-based staleness.
- Detecting agent sessions that run no `/orchestrate`.
- Any agent definition.
- The observation from #37's close that the map body is edited mid-batch although SESSIONS says only on a quiescent tree; it predates this run, and the claim line is written only at take and at release.

## Further notes

- Found by the second verification of #38 in run `stalls-and-exits` (map #44, spec #37), on `feat/stalls-and-exits` @ `5055f62`.
- After this spec, the precondition #45 names for letting a check pinned to the close borrow — a liveness test that holds at the close — is met. The change itself is a decision for a later run.
