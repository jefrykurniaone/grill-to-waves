# spec: claim-identity v1 - Pane identity, renewal and take-over recovery for the working-copy claim

Spec: [#58](https://github.com/jefrykurniaone/grill-to-waves/issues/58) · Map: [#62](https://github.com/jefrykurniaone/grill-to-waves/issues/62) · Tickets: [#59](https://github.com/jefrykurniaone/grill-to-waves/issues/59), [#60](https://github.com/jefrykurniaone/grill-to-waves/issues/60), [#61](https://github.com/jefrykurniaone/grill-to-waves/issues/61)

Copied 2026-11-18 onto `feat/claim-identity`. Below this header, the body of #58 verbatim; the issue, not this file, is the spec.

---

As of 2026-11-17: written against `main` @ `bff9fffb3afa527d2ea5561ec5e3a9d3467df78c`.

## Problem statement

The owner runs delivery runs with `/orchestrate`, one session per working copy, and `/conduct` when a run spans several repositories. As of `bff9fff`, a session marks the working copy it acts in with a working-copy claim (spec #50, delivered by run `working-copy-claim`, map #54): a claim file in the clone's git common directory, which is the only mutual exclusion, and a `claimed:` line on the map. Under herdr, the guard reads the pane a claim names to tell a live claim from a stale one.

The close of that run, and two later verifications, found that the guard can still be wrong about who holds a claim (#56):

1. **A pane id belongs to one herdr server.** As of `bff9fff` a claim records `pane: <HERDR_PANE_ID>` and nothing about the server that id belongs to. A claim written under another herdr server or on another machine names an id that reads as gone here, so the guard takes over a claim that may be live. That is the case spec #50's story 9 expects the claim line to catch.
2. **`HERDR_PANE_ID` is inherited by nested terminals.** A session started in tmux, screen, zellij or an editor's terminal inside a herdr pane carries that pane's id. Its guard reads a live claim of the outer pane as "this session's own pane", and takes it over without asking.
3. **The "gone" rule counts only panes whose cwd is the working copy's root.** A live session in a pane whose cwd is a subdirectory is not counted, so a claim can read as gone while its session lives.
4. **The worktree question still stands beside a stale claim under herdr.** A session that died mid-wave, its pane showing it gone, still costs the next session one question about the open tickets' worktrees. That falls short of #50's goal of no question under herdr where the pane shows the session gone.
5. **A take-over that loses the race and dies mid-move** leaves the winner's live claim only as a `working-copy-claim.<token>` leftover. The winner's next ownership check finds no claim file and stops, and every reader reports the live claim as a leftover.
6. **One conversation resumed in two processes can both proceed** in three cases: both start a turn at once, before either writes; the other pane reads `unknown` and the user confirms; or the claim names no pane. As of `bff9fff` a claim carrying the conversation's own token is *held still*, which writes nothing, so nothing decides between the two.
7. **A rewrite of the execution progress can stop the rightful holder.** A taken-over session that re-read the map before the take-over keeps its own `claimed:` line in its rewrite, writing it back over the new holder's line, and the new holder's next rewrite then finds another token and stops.

## Solution

A claim names its pane together with the herdr server that pane belongs to, and a session counts a pane as its own only where it runs in that pane directly. A pane on another server, or a claim from before this change, is never read: the guard asks. The "gone" rule counts every pane at or under the working copy's root. The guard asks about leftover worktrees only when it already asks about the claim.

Every later turn that finds its own claim renews it, taking it over from itself with a new token. The rename that a take-over makes is the one act only one process can make, so of two processes of one conversation, one proceeds and the other stops, under herdr or outside it. A take-over reads the file before it moves it. A session whose live claim was left only in a move-aside file recovers it at its next ownership check, and every reader judges such a file as a claim. Every rewrite of the execution progress first checks the claim file and then writes the session's own line, so a line written back by a taken-over session heals at the holder's next rewrite.

## Goals and non-goals

Goals:

- A claim written under another herdr server or on another machine is never taken over without asking.
- A session in a terminal nested inside a herdr pane never takes over a claim of that pane without reading it as another pane.
- A live session whose pane's cwd is anywhere inside the working copy keeps a claim from reading as gone.
- A claim left by a session that died under herdr, its pane showing it gone, costs no question, its open tickets' worktrees included.
- Of two processes of one conversation, at most one proceeds past its guard.
- A take-over that dies mid-move never stops the live holder for good, and no reader takes the holder's claim for a leftover.
- A session taken over by mistake cannot make the holder stop by writing its old line back.

Non-goals:

- Reading a pane on another machine through herdr's remote machine commands.
- Heartbeats, timeouts or any age-based staleness of a claim.
- Seeing an agent session that runs no `/orchestrate`.
- Detecting a nested terminal that sets none of the variables named below; it stays a stated residual risk.
- Migrating sessions in flight under the old rules.
- Changing any agent definition.

## User stories

1. As an orchestrator under herdr that finds a claim written under another herdr server, I want to ask the user rather than take it over, because its pane id means nothing here.
2. As an orchestrator that finds a claim line on the map from a working copy on another machine, I want to ask the user, so that two working copies never run the same run unseen.
3. As an orchestrator that finds a claim written before this change, naming a pane without a server, I want to ask the user, because I cannot tell which server that pane belongs to.
4. As an orchestrator started in tmux inside a herdr pane, I want to know that I have no own pane, so that a live claim of the outer pane is read as another session's and stops me.
5. As an orchestrator whose own pane cannot be established, I want to write no pane into my claim, so that no reader judges me by a pane I do not run in.
6. As an orchestrator facing a claim whose pane is gone, I want a live session in a pane whose cwd is a subdirectory of this working copy to count, so that I ask instead of taking over.
7. As an orchestrator under herdr that takes over a claim whose pane shows its session gone, I want the open tickets' worktrees reconciled without a question, because a live session would hold the claim.
8. As an orchestrator that finds no claim at all beside open tickets' worktrees, I want them reconciled without a question, for the same reason.
9. As an orchestrator outside herdr facing a claim, I want the open tickets' worktrees in the same one question as the claim, as before.
10. As one of two processes of one conversation, in two panes, I want the claim carrying our token to be mine only where it names my own pane, so that the other process's pane is read before I proceed.
11. As one of two processes of one conversation, I want every later turn to renew the claim with a new token through the take-over's exclusive rename, so that only one of us proceeds, under herdr or outside it.
12. As a session whose claim names a pane, I want the ownership check and release to compare that pane with my own pane as well as the token, so that a process of my conversation in another pane fails them.
13. As an orchestrator taking over a stale claim, I want to read the file before I move it and move it only where it still carries the stale token, so that I rarely touch a fresh claim at all.
14. As an orchestrator taking over, I want the move-aside file named by the token I have just minted, so that no plain rename overwrites a leftover of an earlier take.
15. As a live holder whose claim file a dying take-over left only under a move-aside name, I want my next ownership check to restore it and go on, so that I am not stopped by a crash that was not mine.
16. As a guard, a conductor or `+ check` that finds a move-aside file holding a claim of this run, I want it judged by the guard's table like a claim, so that a live holder is not reported as a leftover and taken over.
17. As a borrowing orchestrator or a conductor, I want a move-aside file that a second read still finds to fail the lender's borrow check, as a claim does.
18. As a holder whose `claimed:` line was written back by a session taken over by mistake, I want my next rewrite of the execution progress to check the claim file and write my own line, so that I am not stopped and the line heals.
19. As a conductor, I want claims judged with the same server and own-pane rules, and a launch's own claim recognised by its server and pane, so that my reads agree with each launch's guard.
20. As an owner updating the skills, I want the changelog to tell me to finish or stop every session in flight first, and to say that every later turn now renews the claim.
21. As a reader of the glossary, I want *Own pane* defined, so that "this session's own pane" means one thing everywhere.

## Implementation decisions

**The server fingerprint.** Under herdr, a session's server fingerprint is the first 8 hexadecimal digits of the SHA-256 of the text `<host name>:<herdr socket path>`: the machine's host name and the socket path herdr gives the session. Why: herdr's own documentation says pane ids and agent names are scoped to one server, and two machines can both have `w1:p1`; the socket path tells two herdr sessions on one machine apart and the host name tells two machines apart, and hashing them keeps both out of a map that may be public. Where the socket path is unset or no SHA-256 tool is at hand, the session has no fingerprint.

**The own pane.** A session's own pane is the herdr pane it runs in directly, on its own server. It has one only where all of these hold: it is under herdr, it has a server fingerprint, the terminal program it runs in is herdr itself, and no nested multiplexer's marker is set (tmux, screen or zellij). Otherwise it has none, and is read as outside its pane: the inherited pane id is another session's pane, read like any other. Why a heuristic: a nested terminal cannot be detected from inside in general, but every common one replaces the terminal program's name or sets its own marker; one that does neither is a stated residual risk.

**The claim's fields.** The claim file gains `server:`, and the claim line names the pane with its server. Both are written only where the session has an own pane, and never one without the other:

```
token: <host>-<UTC time of this take, compact>-<8 random hex digits>
run: <run slug>
map: <map reference>
host: claude | codex | <other>
since: <UTC time of this take, ISO 8601>
server: <server fingerprint>      (only with pane:)
pane: <HERDR_PANE_ID>             (only where the session has an own pane)
```

```
claimed: <token> since <time> · <host>[ · pane <server>/<pane id>]
```

**Reading a claim's pane.** A pane a claim names is read only where the claim's server equals this session's fingerprint. A claim whose server differs, or that names a pane without a server (one written before this change), is judged in the table's *pane unreadable* column, as is every claim where this session has no fingerprint. A claim names *this session's own pane* only where both its server and its pane equal this session's own pane. Why ask rather than read remotely: reading another machine's panes needs herdr's remote machine profiles, which a session cannot assume.

**The "gone" rule.** A pane counts toward it where its cwd is the working copy's root or any path under it, compared whole path component by whole path component, so a sibling folder whose name begins with the root's name never counts. Its other conditions stand.

**The worktree question.** The question about open tickets' worktrees is asked only where the guard asks about a claim, and is then the same one question as before. Wherever the claim's verdict needs no question — no claim found, a stale claim taken over, or this conversation's own claim renewed — those worktrees go to the reconcile without one. Why: every live `/orchestrate` session holds the one claim and takes it before it registers any worktree, so with no claim standing, or a claim shown stale, no live session can own them. A session on the old rules takes no claim, which the changelog's *After updating* covers. The lifecycle's comparison of Stage 1's reads still decides whether Stage 1 runs in full.

**This conversation's own claim.** A claim carrying the conversation's latest token is its own only where its pane equals this session's own pane, or where neither names one. Its own claim is **renewed**, never held still: the session mints a new token and takes the claim over from itself, by the take-over's own steps below, the moved file required to carry its previous token, and replaces the claim line. Where the token is its own but the panes differ — another pane named, or one named where this session has none, or none named where it has one — the claim is judged as any claim of this run, its pane read under the rules above: a live reading stops and names the pane, and where the guard clears, it is taken over with a new token. Why renewal: holding still writes nothing, so two processes of one conversation that start a turn at once both pass; the take-over's rename lets only one of them through, outside herdr too. Its cost, accepted: one write to the map's claim line on every later turn that finds its own claim, which includes every turn following the pause line.

**The ownership check and release** compare the claim file's token with the conversation's latest token, and, where the file names a pane and this session has an own pane, that pane with the own pane. Either mismatch is the existing stop.

**The take-over.** It mints the new token first and names the move-aside file `working-copy-claim.<the token this take-over has just minted>`. Before the move, it reads the claim file, and moves it only where it still carries the token of the claim being taken over; where it carries another, another session took the working copy meanwhile, nothing is moved, and the session stops. The rest stands: read the moved file, delete it where it carries the expected token, create the claim exclusively, replace the line; otherwise write the moved file back by the exclusive create and stop. Why a read first: it narrows the window in which a take-over can move a fresh claim, which nothing on a plain file system can close.

**Recovery from a move-aside file.** Where the ownership check finds no claim file, and a move-aside file that a second read still finds carries this session's token (and its own pane, under the rule above), the session restores it: it creates the claim file exclusively with that content, deletes the move-aside file and goes on. Where that create fails, it stops as a failed ownership check does, and keeps the move-aside file.

**A move-aside file as evidence.** The guard, `/conduct` and `+ check` read every `working-copy-claim.<token>` file beside the claim file. One that a second read still finds and that holds a claim of this run is judged by the guard's table beside the claim file and the claim line, and the strictest verdict holds: a stop over a question, a question over a take-over. One judged stale stays a leftover the owner removes, and the guard neither takes it over nor removes it. Any other such file is a leftover, as before. The borrow check's second condition counts a move-aside file that a second read still finds as a claim standing, since it reads whether a claim stands and never whether it is stale.

**Rewriting the execution progress.** Every rewrite of the execution progress other than a take, a take-over or a release runs the ownership check on the claim file first, and stops with nothing written where it fails. Where it passes, the rewrite writes this session's own `claimed:` line from its token, never the line as re-read. Why: the file is the authority; comparing the line lets a line written back by a session taken over by mistake stop the rightful holder, while writing the holder's own line heals it.

**`/conduct`.** It judges claims with the same rules: pane reads only on its own server, by its own fingerprint, the "gone" rule by path component, and move-aside files as evidence. A launch's own claim is one of this run that names the server and pane of the session running that launch. The own-token rule and the own-pane row stay the guard's alone, as before.

**Residual risk** narrows and gains two stated cases, wherever the skills state it: an agent session that runs no `/orchestrate`; a claim left by a session that died outside herdr, or written under another herdr server or on another machine, which costs the next session one question; a nested terminal that neither renames the terminal program nor sets a multiplexer's marker, which reads as the outer pane; and the window between a take-over's read and its move.

**Glossary, changelog and README.** The glossary gains *Own pane*: the herdr pane a session runs in directly, on the herdr server it runs under; a session in a terminal nested inside a pane has none. _Avoid_: current pane, focused pane. The changelog gains a dated entry whose *After updating* says to finish or stop every `/orchestrate` session in flight before running the installer again, and which says that a later turn now renews its claim with a new token, where the earlier entry left the held case unstated. The README agrees.

**The parent.** #56 is this spec's parent item, so the close posts a delivery summary there and the review request closes it.

## Testing decisions

A good test here checks what a session reading the skills will do, not how the text is worded. These skills have no unit under test; four seams cover them:

1. **The install test**, every wave. It catches a broken installer and the literals it asserts in the orchestrate skill, which must survive. It cannot catch a contradiction between rules.
2. **The consistency sweep**, at the close: a grep for the replaced wording (the claim held still, the "gone" rule counting only the root, a rewrite keeping the `claimed:` line as re-read), a check that every `§`, numbered-step and section reference still lands, then one read-only analyst reading the changed skills end to end, as a solo and as a paired session would, through these scenarios: a claim from another herdr server; a session in tmux inside a herdr pane facing the outer pane's live claim; one conversation resumed in a second pane, both starting a turn at once; a take-over that dies mid-move after renaming a fresh claim; a session that died mid-wave under herdr, with open tickets' worktrees; a session taken over by mistake rewriting the execution progress; a lender whose only claim is a move-aside file. It catches contradictions and dangling references; it cannot catch behaviour only a real run shows.
3. **CI on the run's draft review request**: the docs check, shellcheck, PSScriptAnalyzer and the Windows install tests, which this machine cannot run. It cannot catch what a rule means.
4. **A sandbox run after the close**, in throwaway repositories, on the recipe of the previous runs': a claim whose server is another's, which the guard asks about rather than takes over; a session started in tmux inside a herdr pane facing a live claim of that pane, which stops; a stale claim of a closed pane beside an open ticket's registered worktree, which is taken over and reconciled with no question; and a live claim left only in a move-aside file, which stops a second launch. It catches the real herdr reads and the environment a nested terminal sets; it cannot catch Windows or Codex.

Prior art: the previous runs' maps (#44, #54), their consistency sweeps (seam 2), CI (seam 3) and sandbox runs (seam 4).

## Success criteria

- A claim carries its server beside its pane, and a pane on another server, or a pane without a server, is never read: the guard asks.
- A session with no own pane writes no pane and is never judged by the own-pane row.
- The "gone" rule counts every pane at or under the working copy's root by whole path components.
- The worktree question is asked only together with a claim question.
- A claim carrying the conversation's token is renewed through the take-over's exclusive rename on every later turn, and one naming another pane is read before anything proceeds; the ownership check and release compare the pane.
- A take-over reads before it moves and names the move-aside file by its own new token; the ownership check recovers its own claim from a move-aside file; the guard, `/conduct` and `+ check` judge a move-aside file of this run as a claim; the borrow check fails on one.
- Every rewrite of the execution progress runs the ownership check on the file and writes the session's own claim line.
- `/conduct` reads claims by the same rules and recognises a launch's own claim by its server and pane.
- The residual risk is stated as above wherever the skills state it; the glossary defines *Own pane*; the changelog has a dated entry with its *After updating*; the README agrees.
- The install test passes; CI is green on the draft review request; the consistency sweep reports no contradiction across its scenarios.

## Out of scope

- Reading panes on another machine through herdr's remote machine commands.
- Heartbeats, timeouts or any age-based staleness of a claim.
- Detecting agent sessions that run no `/orchestrate`.
- Detecting a nested terminal that sets none of the markers named above.
- A borrow by a check pinned to the close, and a borrower's claim in its lender's working copy.
- Any agent definition.

## Further notes

- Filed as #56 by the consistency sweep at the close of run `working-copy-claim` (map #54, spec #50), with two comments from the second verification and the delta re-verification of #55.
- Grilled with the owner on 2026-11-17, who chose, among the alternatives: a hashed server fingerprint over the raw herdr session name or never taking over a line-only claim; renewal on every later turn over accepting the two-process window as a residual risk; and waiving the worktree question wherever the claim needs no question, not only beside a stale claim under herdr.
