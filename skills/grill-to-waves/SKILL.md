---
name: grill-to-waves
description: Run the delivery pipeline — grill the idea, write one spec per shippable slice, ticket each spec, prove the specs write-disjoint, publish the execution map — then stop for /orchestrate.
disable-model-invocation: true
---

# Grill to waves

One pipeline, seven stages (0 to 6), each gated by the one before it. Specs, tickets and the map
live on the repo's issue tracker; the repo gets a durable docs copy of each spec. The product record
(goals, constraints, success criteria) lives inside each spec — there is no separate PRD.

**A run is normally executed by one `/orchestrate` session, wave by wave.** That is the default and
the cheaper path: one session owns every merge, so there is nothing to coordinate. Stage 4 computes
the wave order, which is what that session executes.

**The spec is the unit of splitting when a team wants one.** Several developers can execute one map,
one spec row each **on their own clones**, and this pipeline is the half that makes that safe: Stage 3
gives every ticket a write surface, Stage 4 proves the specs disjoint (or fuses the ones that collide),
Stage 5 publishes the result as the map's Sessions table. Splitting only pays when executor time per
ticket clearly exceeds gate time — measure the gate at Stage 6 and say so. Two agent sessions never
share one working copy: a split means one developer per clone, never two terminals in one tree. The
protocol the split path needs — surfaces, collision, ownership, resume — is
[SESSIONS.md](./SESSIONS.md); per-tracker mechanics are [TRACKERS.md](./TRACKERS.md). This file points
at them rather than restating them.

Model and effort assignment follows [DEFAULTS.md](./DEFAULTS.md), which travels with this skill; a
repository's own `CLAUDE.md` or `AGENTS.md` overrides it where the two differ. Tracker text, specs and
mirrors are read by humans, so they stay normal prose whatever compression style the session uses.
Commits and pull request bodies follow the repository's own convention.

## Stage 0 — Resolve the tracker

1. Read `docs/agents/issue-tracker.md` in the repo. If it exists it is the answer: follow it for
   creating, reading, commenting, labelling, linking and closing.
2. Otherwise detect: `git remote -v` at GitHub → `gh`; at GitLab → `glab`; no remote → local markdown
   under `.scratch/`. Confirm in one line with the user and suggest `/setup-matt-pocock-skills`
   afterwards, which writes `docs/agents/issue-tracker.md` so the next run does not re-detect it.

Then make sure the repo carries the labels `meta:orchestration`, `ready-for-agent`, `executor:opus`,
`executor:sonnet`, `effort:medium`, `effort:high`, `effort:xhigh`. Create what is missing.

Done when: the tracker is named and the label vocabulary exists.

## Stage 1 — Grill

Invoke `mattpocock-skills:grilling` on the user's raw input, and `mattpocock-skills:domain-modeling`
whenever vocabulary is in play. Both are **required** — see [README](../../README.md); if either is
missing, stop and install the plugin rather than improvising a grill. Facts are yours to find: dispatch `scout-sonnet-medium` (one known
thing), `scout-sonnet-high` (a sweep) or `scout-opus-high` (a judgement) for anything the codebase
can answer, and put only decisions to the user.

Done when: no open question remains and the user has confirmed the consolidated understanding.

## Stage 2 — Specs

Consolidate the grilled understanding into one or more specs. A spec is a coherent, independently
shippable slice — split where the work serves different surfaces or could ship separately; a small
effort is legitimately one spec. **Split with Stage 4 in mind**: two specs that will edit the same
files are one spec wearing two titles.

Pick a run slug and create `run:<slug>` (description: "Belongs to delivery run <slug> - <title>").
Before writing, sketch the seams the work will be tested at — existing seams first, the highest seam
possible, ideally one — and confirm them with the user. Then write each spec on this template and
publish it with `ready-for-agent`, `run:<slug>` and its own `spec:<slug>` label (description:
"Belongs to spec <ref> - <title>"). No file paths and no code in a spec; those belong to tickets. The
exception is a prototype snippet that encodes a decision more precisely than prose (a state machine,
a schema, a type shape), trimmed to the decision.

```markdown
## Problem statement
From the user's perspective.

## Solution
From the user's perspective.

## Goals and non-goals
What this spec must achieve, and what it deliberately does not.

## User stories
A long numbered list: "As an <actor>, I want <feature>, so that <benefit>."

## Implementation decisions
Modules built or modified, their interfaces, schema changes, API contracts, architectural
decisions — each with the *why*, so it is not relitigated.

## Testing decisions
What a good test is here (external behaviour only), which modules are tested, prior art in the repo.

## Success criteria
Observable, checkable.

## Out of scope

## Further notes
```

Mirror each spec into the repo as `docs/spec-<spec-slug>-v<N>.md` — a header linking the spec and
map items (updated as later stages create them), then the body verbatim — on a `docs/` branch merged
by pull request. A mirror is a point-in-time copy that the spec's own run will falsify, so write its
claims to survive delivery: "as of <date>, X" rather than "X is", and never renumber a `path:line`
citation later — the quoted text is the evidence, the number is only its address at writing time.
Whoever closes the run re-reads every mirror it produced and past-tenses or marks each claim the
run's tickets reversed, deleting nothing.

Done when: every grilled decision is owned by exactly one spec, every spec item exists, the docs
pull request is open or merged.

## Stage 3 — Tickets

Break each spec into **tracer-bullet** tickets: each a narrow but complete path through every layer
(schema, API, UI, tests), demoable on its own, sized to one fresh context window, prefactoring first.
A **wide refactor** — one mechanical change whose blast radius spans the codebase — is the exception:
sequence it expand → migrate in batches → contract, each batch its own ticket blocked by the expand.
Look for prefactoring that makes the change easy before making the easy change.

**Quiz the user** with the proposed breakdown as a numbered list — title, blocked by, what it
delivers — and iterate on granularity and edges until approved. Then publish in dependency order
(blockers first) on this template:

```markdown
## Parent
The spec item.

## What to build
The end-to-end behaviour this ticket makes work, from the user's perspective.

## Acceptance criteria
- [ ] …
- [ ] An executor that must write outside `writes:` stops and reports; it never widens the edit.

## Blocked by
Each blocking ticket, or "None (can start immediately)".

## Execution
executor: opus | sonnet · effort: medium | high | xhigh — one line saying which axis (exploration
or decision weight) set the level, per the effort ladder in [DEFAULTS.md](./DEFAULTS.md).

## Surface
writes: …
reads: …
runtime: dev-db | dev-server | none
deps: shared | own
exclusive: no | run
```

The surface block follows SESSIONS.md §2 in full. A ticket without a surface cannot join a spec
session, so there are no exceptions.

A `runtime:` of `dev-server` means the orchestrator walks the app for that ticket, and the walk is
driven by **Playwright MCP** where the server is connected — the executor never starts a dev server.
Write the ticket's runtime criterion as what a walk must *observe*, not as an instruction to the
executor: the surface to open, the role to sign in as at `/auth/dev`, the property to measure, and
the value it must hold. A criterion an executor cannot satisfy and a walk cannot check is not a
criterion.

Label every ticket `ready-for-agent`, `run:<slug>`, its spec's `spec:<slug>`, its `executor:` and
`effort:`, plus the repo's own area/type/priority vocabulary. Link it as a child of its spec and
record every blocking edge, cross-spec edges included, per TRACKERS.md.

Done when: every ticket is a child of its spec, carries executor, effort and run labels, declares a
surface, and has its edges recorded.

## Stage 4 — Sessions

Run the collision check of SESSIONS.md §3 over the tickets and resolve every collision by its three
remedies, saying which you applied and why. Then compute, for the solo path, a **wave order**: no two
tickets in one wave share a surface, blocking edges respected. Nothing is committed and no tooling is
added to the repo.

Emit the **Sessions table** — one row per session with its specs, tickets, cross-row blocking edges
it may idle on, and the exact `/orchestrate` launch line — the **tail** row, present even when empty,
and the **verdict line** (`splittable N ways` or `not splittable: <fusing surface>`).

### Ask the user the execution shape

The table says what *can* run apart; only the user knows who will run it. Ask once, in one question,
and recommend the first unless the answer is obvious from what they have already said:

- **solo** — one person, one session, wave by wave. The default, and the right answer for most runs.
- **team** — several developers on their own machines, one spec row each. Choose this when there is
  genuinely a second developer with their own clone, not merely a second terminal: two agent sessions
  in one working copy contend on the tree, the dev server and the dev database, and that is a stop.

A `not splittable` verdict answers the question by itself: the run is solo, and a second developer
would be an audience rather than a second pair of hands. Say so rather than asking.

**If the answer is team**, settle two things now and write both into the table:

1. **Who owns which row.** Record it as the assignee on each spec item and on its tickets — that is the
   ownership signal `/orchestrate + team` reads.
2. **Who is the serial owner**, named once for the whole run. Every `exclusive: run` ticket — schema,
   migrations, `package.json`, the lockfile, an environment target — belongs to that one person,
   whichever row it came from, because two developers migrating in the same week produce divergent
   histories that do not reconcile. Move those tickets into the tail row and assign them.

Write the answer as an **Execution shape** line under the verdict: the shape, the reason, and for team
the row-to-developer assignment and the serial owner.

Done when: every ticket appears in exactly one row and exactly one wave, the table is written, and the
shape is recorded.

## Stage 5 — Map

Author one execution map for the run as its own item, titled
`map: <run-slug> delivery - execution plan for run <run-slug>`, labelled `run:<slug>`. Mirror the
repo's most recent map (search `map in:title`) for shape. It carries, in order:

1. **Parent** — the spec items, their docs mirrors, binding ADRs and seams, and any
   cross-run gate ("must not start until run X closes"), each gate naming the tickets whose closed
   state satisfies it and carrying a real blocking edge on the tickets it gates.
2. **How this is executed** — point at the tickets' labels for model and effort; one worktree per
   ticket at `.claude/worktrees/<row>/<ticket>`; `deps: shared` worktrees never install or generate;
   serial merge-commit-only merges on a quiescent tree, and teardown likewise; no dev server from
   executors; check-versus-fix ownership; the per-wave in-flight ceiling (default three, hard maximum
   five — raise it to four or five only for a named reason, and never past five; lower it below three
   for a named reason such as heavy installs or a rate limit); one agent session per working copy; the
   write-through rule — every fact the next session needs is posted the moment it becomes true.
3. **Known shared-file contention** — the files parallel branches will collide on inside a session
   and how each collision is handled (append-plus-append catalogue, wave separation, stop-and-report).
4. **Sessions** — Stage 4's table, tail row, verdict line and **Execution shape** line verbatim,
   heading text beginning `Sessions` (admission matches on the word). Where the shape is team, this
   section is also where the row-to-developer assignment and the **serial owner** are written down, so
   a session that picks up an `exclusive: run` ticket can see in one read whether it may run it.
5. **Waves** — the solo order, numbered globally; every ticket line carries its spec. Orchestrator-only
   work pinned to a wave (a baseline, a runtime check) names its owner: a session row, or `tail`. A
   pinned runtime check states **how it is driven**: Playwright MCP (`mcp__playwright__*`) is the
   default — `browser_navigate`, `browser_snapshot`, `browser_evaluate` for a `getComputedStyle`
   measurement, `browser_console_messages` for the console-error count — with the scripted Playwright
   fallback or plain HTTP named only where the check does not need a DOM, or where the check produces
   an artifact rather than a page and is settled by fetching it.
6. **Why the executors split this way** — one paragraph naming every ticket not at `high` and the
   axis that moved it.
7. **Completion gate** — the repo's one-shot gate commands and quality bars, from its `CLAUDE.md` or `AGENTS.md`.
8. **Rework protocol** — hand-backs to the introducing executor, at most twice; gate re-runs whole;
   post-merge defects become new issues; the mirror pass from Stage 2 runs before the map closes.
9. **Out of scope** — carried from the specs so no executor picks it up opportunistically.

Update each spec mirror's header with the map reference. Done when: the map item exists and every
ticket appears in exactly one wave and one session row.

## Stage 6 — Stop

The pipeline ends here, hard: no dispatch, no worktree, no executor, however ready it looks.
Execution belongs to a fresh session. Report the tracker references (specs, map, tickets per wave and
per row) and print the launch lines ready to copy, **the solo lines first, because they are the
default**:

```
/orchestrate map <map> + check                             # read-only preflight, writes nothing
/orchestrate map <map>                                     # one session, wave by wave
/orchestrate map <map> + all                               # one session, every wave, no stop between
```

Then the lines for the shape Stage 4 recorded, one per Sessions row plus the tail — **team**, one line
per developer, each run in that developer's own clone:

```
/orchestrate map <map> + spec <spec-a> + team              # dev A
/orchestrate map <map> + spec <spec-b> + team              # dev B
/orchestrate map <map> + tail                              # the serial owner, once every row is closed
```

A fused row names every member on one line:

```
/orchestrate map <map> + spec <spec-b> + spec <spec-c> + team      # dev B, a fused row
```

**Measure the gate once and print its duration beside the lines.** A solo session runs the whole gate
once per wave; a team session runs it once per merge and again after every rejected push. Below roughly
the executor time per ticket, splitting is not worth the extra context windows. Say which you
recommend, and state the residual risks from SESSIONS.md §7 whenever you recommend team.

**For a team run, also print the pre-flight the humans owe**, because no skill can do it for them:
branch protection on the default branch with required status checks and *require branches to be up to
date before merging*; whether CI's checks are weaker than this map's completion gate, naming which
commands are missing; whether the developers share one dev database, and if so who owns migrations;
and the serial owner's name.
