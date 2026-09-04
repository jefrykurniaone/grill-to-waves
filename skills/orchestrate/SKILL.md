---
name: orchestrate
description: Execute an execution map from /grill-to-waves in one session — dispatching ticket executors as subagents, verifying their work, merging a whole wave under one gate, and closing specs and the map. A team can split a map by spec instead, one developer per row, opt-in.
disable-model-invocation: true
---

# Orchestrate

You are the orchestrator for a delivery run planned as an **execution map**: specs → tickets → waves.
`/grill-to-waves` produced it; this skill executes it. **Executors are subagents, not sessions**: you
brief them, they work in their own worktrees and report back, and you verify, merge and close.

## Two shapes

A run's shape is decided by **what is actually contended**, and the coordination must match it.

| Shape | Who | Working copies | What is contended | Coordination |
|---|---|---|---|---|
| **solo** | one person, one session | one | nothing | none |
| **team** | several developers, their own machines | several | `origin/main`, the tracker | the forge: branch protection and assignees |

**solo is the default, and this file is its whole protocol.** One session owns the map and runs it wave
by wave. There is no second session to coordinate with.

**team** scopes a session to one spec row while keeping solo's mechanics, because a second developer on
a second machine shares no filesystem with you. Ownership is the tracker's assignee; `origin/main` is
serialised by the forge, not by this skill. See **Team shape**, and
[../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) for surfaces, collision and ownership.

**Two agent sessions never share one working copy**, in either shape. Splitting a run means one
developer per clone. A second session found in this working copy is a stop, not a shape.

## Arguments

References are whatever the repo's tracker uses — an issue number, a GitLab iid, a Jira key, a file
path under `.scratch/`.

```
/orchestrate map <map>                       solo, the next unstarted wave  (`/orchestrate <map>` is the same)
/orchestrate map <map> + wave <k>            solo, one named wave
/orchestrate map <map> + all                 solo, every remaining wave in order, no stop between them
/orchestrate map <map> + check               read-only preflight, writes nothing

/orchestrate map <map> + spec <s>            one spec row, team shape (`+ team` is the same)
/orchestrate map <map> + spec <a> + spec <b> a fused row, every member named
/orchestrate map <map> + tail                the tail row, then the map close
```

`+ team` may also be given with `+ wave <k>` or bare, when a team divides a map by wave rather than by
spec. `+ check` reports the shape it would run without acting on it.

## Stage 0 — Resolve the tracker

Read `docs/agents/issue-tracker.md` in the repo; if it exists it governs reading, commenting,
labelling, linking and closing. Otherwise detect from `git remote -v` (GitHub → `gh`, GitLab → `glab`,
none → local markdown); a map reference that is a file path settles it. The frontier read that returns
labels, bodies and open-blocker counts is in
[../grill-to-waves/TRACKERS.md](../grill-to-waves/TRACKERS.md).

## Stage 1 — Orient

Four reads, then work. This is the whole resume, and it is enough after a context clear or a crash,
because the tracker and git already carry the state that matters.

1. **The map** — wave order, the contention table, the completion gate, what is out of scope, and any
   orchestrator-only checks pinned to a wave. Binding.
2. **One frontier listing** of every open item under `run:<slug>` — state, labels, bodies, open blocker
   counts.
3. **Git ground truth** — `git fetch --prune`, `git status --porcelain`, `git log --merges` on `main`,
   every open review request with its head branch, `git worktree list`.
4. **The repo's agent rules** — `CLAUDE.md`, `AGENTS.md`, and anything they include: the gate
   commands, the seams, the hard rules an executor brief has to carry.

**Reconcile before dispatching anything.** A merged review request on a still-open ticket means a
previous run died between merge and close: post the record and close it, never re-run it. A branch with
no review request and no worktree: inspect, salvage or delete, and say which. A worktree whose ticket is
closed: tear it down. Where there are no review requests the merge commit is the evidence —
`git log --merges -E --grep '#<n>([^0-9]|$)' main`, anchored, because `#25` also matches `#253`.

**The single-session guard.** It asks one question — is another *agent session* live in **this working
copy**? `git worktree list` showing a **registered** worktree outside this session's own directory says
yes: stop and report, because two sessions in one tree contend on the tree, the dev server and the dev
database at once. An empty leftover directory under `.claude/worktrees/` is not a registered worktree,
so read the list, never the filesystem. That is one cheap read, and if it is clear nothing else can
collide with you here.

**A human assignee is not a collision.** Assignees are how people divide work between themselves, and
on a team every ticket may carry one. Treat an assignee as **scope**: when the tickets in scope are
assigned to someone other than the user you are working for, say so and confirm before dispatching,
rather than stopping.

**Another developer on another machine is also not a collision.** They have their own working copy,
their own dev server and their own dev database; nothing you do here reaches them. The only thing you
genuinely share is `origin/main`, and the way to serialise that across machines is the forge's own
branch protection — required status checks plus "require branches up to date". Push, and if the push is
rejected because they landed first, pull, re-merge, re-run the gate, push again.

**Cross-run gates.** Where the map, its comments, or another open map says this run waits on another
run's tickets, verify it by reading those tickets' states — never by trusting the prose that describes
it. An unsatisfied gate is a wait, not a failure: say what it waits on and stop.

**The tree preflight**, run once before the first dispatch and again before each merge batch — not
before every step:

1. `git fetch --prune` exits 0 (retry a few times; a persistent failure is a wait, never a pass).
2. `git status --porcelain` is empty.
3. No `MERGE_HEAD`, `rebase-merge`, `rebase-apply` or `CHERRY_PICK_HEAD` under `.git`.
4. `HEAD` equals `origin/main`, on branch `main`.
5. Where the repo generates a database client or other build-time artifact into the dependency tree,
   it is present. Missing → repair it before anything else, because it misattributes every failure
   downstream of it.

**`+ check`** runs Stage 1 read-only and prints: the waves with each ticket's state and open blockers,
what the guard found, what the preflight found, cross-run gates with the tickets they wait on, and the
line to run next. It writes nothing.

## Model and effort

[../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md) is the source of truth, overridden only
by the repository's own `CLAUDE.md` or `AGENTS.md`. Executors are Opus or Sonnet at `medium`,
`high` or `xhigh`, from the ticket's labels; default `high` when unlabelled; re-grade only when the body
contradicts the label (a `medium` ticket that touches money, a stored enum or a shared seam is
dispatched at `xhigh`, the label corrected, one line saying why). Dispatch with
`subagent_type: executor-<model>-<effort>`; scouts are `scout-sonnet-medium`, `scout-sonnet-high`,
`scout-opus-high`. If a type is missing, fall back to `general-purpose` with `model` set and the effort
stated in the prompt, and record the fallback in the report.

## Dispatch the whole wave at once

A ticket is dispatchable iff it is open, `ready-for-agent`, carries both an `executor:` and an `effort:`
label, has zero open blockers on the tracker's own edge read live, and belongs to this wave. A
mislabelled item — `ready-for-agent` without the pair — is reported by name, never guessed at.

**Dispatch every dispatchable ticket in the wave in one message, so the subagents run concurrently —
up to the in-flight ceiling.** The ceiling is **three tickets by default and five at the absolute
maximum**: a map may raise it to four or five with a named reason, never past five, and a wave holding
more dispatchable tickets than the ceiling goes out in successive batches of at most that many, each
batch dispatched in one message. The waves exist precisely to separate contended files, so there is
normally no overlap to serialise. Two exceptions, both read off the map: if two tickets in the wave
declare overlapping `writes:`, or the contention table names a file they share, the second waits for
the first to merge. Honour a ceiling lower than three only where the map states one and gives a reason.

Then, in one pass:

1. **Worktrees** at `.claude/worktrees/<row>/<ticket>` — `solo` as the row name in a solo run — one
   branch per ticket in the repo's prefix
   vocabulary, off `origin/main` as just fetched — never off local `main`. `deps: shared` → copy
   the local environment file and link the dependency tree (a junction on Windows, a symlink
   elsewhere); **no install and no code generation inside it, by anyone,
   orchestrator included**, because the generator empties the shared copy for every tree at once.
   `deps: own` → copy the whole dependency tree, install and generate inside the copy only.
2. **Briefs** — the ticket body verbatim; the repo's hard rules (seams, gate, i18n, security,
   accessibility); the gate commands; the delivery contract (Conventional Commits in the repo's style,
   review request via `--body-file`, never merge, never touch `main`, report the gate start time); the
   prohibition on installing or generating in a junctioned worktree; that **`writes:` is a contract** —
   a tracked file it must change outside the block is a stop-and-report, never a widening; and that
   **executors start no dev server, run no migration or seed, and touch no shared database** — one-shot
   gate commands only, because the running app and the dev database are yours.

## Verify — yours, never the executor's

An executor's account of its own work is a claim, not evidence. Before a branch merges:

- **Read the diff yourself.** Confirm it touches the `writes:` set and nothing else.
- **A wrong ticket premise is the common failure**, and an executor that refuses its own ticket is
  usually right. Verify the claim against the code; if the ticket is wrong, correct its body and any
  acceptance criterion quoting it, record why, and re-dispatch. That is not a hand-back.
- **Measure, do not eyeball.** A claim about type, size, spacing or contrast is settled by
  `getComputedStyle` or a computed value, not by comparing screenshots — a screenshot pair can be clean
  and still hide the defect.
- **Drive the browser with Playwright MCP** (`mcp__playwright__*`) whenever it is connected. It is the
  default for every runtime check: `browser_navigate`, `browser_snapshot` for the accessibility tree,
  `browser_evaluate` for the `getComputedStyle` measurement above, `browser_console_messages` for the
  console-error count, `browser_take_screenshot` only as a record of what was measured. Sign in through
  `/auth/dev` by clicking the user whose role the check needs.
- **When the MCP server is not connected, say so in the wave report** and fall back to the npx-cached
  Playwright scripts under `.claude/scratch/`, or to plain HTTP where the check does not need a DOM.
  A fallback is a stated fact, never a silent substitution — and never a reason to skip the walk.
- **An artifact a route returns is verified by fetching it**, not by reasoning about the library that
  produced it. Where the output is an image or a file rather than a page, fetch it and look at it, and
  settle any "does this declaration take effect" question by rendering twice with only that declaration
  changed and comparing hashes. Identical bytes mean the declaration is inert.

## Merge the batch — one gate, and nothing pushed until it is green

One session owns every merge in this working copy, so the whole gate runs once per batch rather than
after every merge:

1. Preflight the tree.
2. For each green branch, in wave order: `git merge --no-ff` with the ticket number in the merge
   subject, then the **fast** part of the gate only — the test suite — so a break is attributed to the
   merge that caused it. Resolve append-plus-append catalogue conflicts yourself.
3. After the last merge, the **whole** gate once: lint, type check, tests, build. Restore any file the
   test run dirties before judging the tree.
4. **Then the runtime walk**, on merged `main`, for every ticket whose `runtime:` is not `none` and for
   every check the map pins to this wave — **Playwright MCP** where it is connected, its scripted
   fallback or plain HTTP where it is not, credentials from env by name, sentinel data wiped afterwards
   and the wipe proven.
5. **Push once, only when the gate and the walk are both green.** Nothing reaches `origin/main` before
   then, so a bad ticket costs `git reset --hard origin/main` and a re-merge without it — there is no
   revert to publish and no ungated commit on the shared branch. Re-gate what remains and hand the
   failing ticket back.

A red gate after the last merge points at that merge first; reset, re-merge the others, re-gate.

## Record, close, tear down

Per ticket, **one comment**: what landed, the gate result with its start time, the runtime finding, the
merge sha and the review request. Then close it, and drop the assignee if the tracker set one. Per
wave, **one comment on the map**: the tickets with their shas, the decisions taken, the defects filed,
and what the next wave waits on. **That is the entire tracker footprint of a run.**

Rework goes back to the introducing executor — by `SendMessage` where the host has it, otherwise as a
fresh dispatch carrying the original brief plus the finding — at most twice; the third failure is a stop
and a report. A defect found in code a ticket did not own is **filed as its own item**, never an
opportunistic fix and never a hot fix on `main`.

Tear down every worktree of the wave in one pass, by the junction-safe procedure in
[../grill-to-waves/DEFAULTS.md](../grill-to-waves/DEFAULTS.md): unlink every reparse point or symlink
deepest-first — the `.next/node_modules/*` junctions a
build leaves, then `node_modules` — confirm none remain, then remove, `git worktree prune`, and confirm
the generated client is still present. Delete each branch on both sides.

## Closing upward

**A spec closes** when every one of its tickets is closed and every orchestrator-only check the map
pinned to it is recorded done. Post its completion record — what landed against its implementation and
testing decisions, with tickets, review requests and merge commits — and close it. A spec another open
map is still executing stays open, and the record says so.

**The map closes** when: zero open tickets under the run label; zero open non-ticket items under it
other than the specs and the map (a mislabelled item is resolved or re-labelled first); every spec
closed with its record; every orchestrator-only item pinned to the close done, runtime verification
included; and the mirror pass from `/grill-to-waves` Stage 2 run over every `docs/spec-*` this run
produced. Then post the execution record, close the map, and where a spec has a parent item above it,
post a delivery summary there and close it too. Closing upward is part of finishing.

## Stop rule

**Stop after the wave, and report.** `+ all` is the exception: continue through every remaining wave in
order without a further go-ahead, and stop early only on a third hand-back, a `writes:` breach, a gate
that stays red after the reset, or a decision that is the user's. The closing chain above always runs
without a further go-ahead.

Leave nothing half-held: no worktree for a closed ticket, and no branch that is green but unmerged
without saying so by name. The report names the tickets closed with their merge shas and
review requests, the hand-backs, the defects filed, anything outstanding for the user, and the next
wave with what it waits on.

## Team shape — `+ team`

**Scope is one spec row; mechanics are solo's.** A developer on another machine shares no filesystem,
no dev server and no dev database with you. You share `origin/main` and the tracker, and nothing else.
Read [../grill-to-waves/SESSIONS.md](../grill-to-waves/SESSIONS.md) §2–§4 for the surface block, the
collision rule and ownership. Six differences from solo, and they are the whole of it:

1. **Frontier is the spec row, not the wave.** A ticket is in scope when it carries a `spec:` label in
   this row; the map's waves are advice about ordering, not a filter. In-row overlaps still never run
   together: two of your own tickets that declare overlapping `writes:` go one after the other.
2. **Ownership is the tracker's assignee**, the mechanism people already use. Assign yourself before
   dispatching, and **skip any ticket assigned to someone else**, naming it in the report.
3. **Refuse every `exclusive: run` ticket unless the map names you the serial owner** — schema,
   migrations, `package.json`, the lockfile, an environment target. Two developers running the
   migration tool in the same week produce divergent migration histories that do not reconcile
   cleanly, and no protocol here can undo that. Report it and hand it to the serial owner.
4. **A rejected push is normal, not a failure.** Someone landed first. Pull, re-merge onto the new
   `origin/main`, **re-run the whole gate** — their change plus yours is a combination neither of you
   has gated — and push again. Never force-push, and never skip the second gate.
5. **Pull and gate before you dispatch**, every session, not only when something looks wrong. Disjoint
   writes prove non-collision, never independence: a shared type, a translation key or a seam contract
   can move under you with no file conflict at all.
6. **A defect in another row's surface is filed, never fixed.** You cannot see what they are mid-way
   through changing.

**The forge is the serialiser.** Branch protection with required status checks and *require branches to
be up to date before merging* is what makes a team's merges safe. Check it once at Stage 1 and say so
plainly if it is missing or if the required checks are weaker than the map's completion gate — a gate
you ran locally proves your merge, not the combination that lands after someone else's.

## Refusals and retrofit — every `+ spec` run

The map's **Sessions table** decides which rows are legal. Refusals, all hard stops:

1. **`+ spec` names something that is not a whole spec row** — a member of a fused row, a spec of another
   run, a slug the map does not know. Print the corrected line from the table.
2. **`+ spec` on a map with no Sessions table.** Offer the retrofit below, or the solo line.
3. **The verdict is `not splittable`.** Print the fusing surface and offer the solo line. A run whose
   specs fuse does not become splittable by handing it to a second developer — it becomes one person's
   work with an audience.
4. **An `exclusive: run` ticket in scope and you are not the serial owner.** Name it and hand it on.
5. **The collision re-check disagrees with the published table.** Post the disagreement on the map and
   stop. Never proceed on a freshly derived split.
6. **Another agent session's worktrees are registered in this working copy** — the single-session
   guard. One developer per clone.
7. **`+ tail` before every spec row's spec item is closed.** List what is outstanding.

**Retrofit — a map that predates surfaces.** When `+ spec` is given and any open ticket under the run
label has no `## Surface` block, derive one for each from its acceptance criteria and the map's
contention table, and `runtime:`, `deps:` and `exclusive:` from the map's execution section. **Show the
derived blocks to the user and get confirmation before writing anything** — the whole split rests on
them, and every glob you are tempted to write is a decision that fuses specs. Then, on a quiescent
tree, write each block into its ticket, run the collision check, and append a `## Sessions` section to
the map body in the format `/grill-to-waves` Stage 4 prescribes. Stop with a named list of any ticket
whose surface cannot be derived — that ticket is the user's to write. Do the retrofit **once**, by
agreement, before anyone dispatches; two developers retrofitting the same map at once is the one race
the tracker cannot arbitrate.

## Hosts without subagent dispatch

Where the host has no subagent tool (Codex CLI today), everything above holds except the fan-out: the
session **is** the executor, one ticket at a time, in the ticket's own worktree, and the agent
definitions under `agents/` are read as role briefs rather than dispatched. The in-flight ceiling is
then 1, so a wave is executed serially in wave order. Verification does not become optional because
the same session did the work — read the diff, run the gate, walk the runtime, and say in the report
that executor and verifier were the same context.

**A spec row closes** by posting the spec's completion record and closing the spec item; the closed
spec item is the signal every other row reads, and the report names it. The map itself closes in the
tail run, once every row is done.
