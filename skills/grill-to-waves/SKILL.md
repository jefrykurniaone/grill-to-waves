---
name: grill-to-waves
description: Run the delivery pipeline — grill the idea, write one spec per shippable slice, ticket each spec, check the tickets for collisions and order them into waves, publish the execution map — then stop for /orchestrate.
disable-model-invocation: true
---

# Grill to waves

One pipeline, seven stages (0 to 6), each gated by the one before it. Specs, tickets and the map
live on the repo's issue tracker; planning commits nothing to the repository, and the run that
delivers a spec writes its durable docs mirror. The product record (goals, constraints, success
criteria) lives inside each spec — there is no separate PRD.

**A run is executed in one of two shapes.** **Solo**, for work in one repository: one `/orchestrate`
session, wave by wave, which owns every merge, so there is nothing to coordinate. **Paired**, for work
that lands in several repositories: one `/orchestrate` session per repository, driven by `/conduct`
(Stage 0 says how it is planned). Stage 3 gives every ticket a write surface, and Stage 4 turns the
surfaces and the blocking edges into the wave order those sessions execute.

Two agent sessions never share one working copy: a second session in the same tree contends on the
tree, the dev server and the dev database at once. The protocol both skills share — surfaces,
collision, worktrees, paired runs — is [SESSIONS.md](./SESSIONS.md); per-tracker mechanics are
[TRACKERS.md](./TRACKERS.md). This file points at them rather than restating them.

This session runs on the frontier tier at `high` or above. Model and effort assignment follows
[DEFAULTS.md](./DEFAULTS.md), which travels with this skill; a
repository's own `CLAUDE.md` or `AGENTS.md` overrides it where the two differ. Tracker text, specs and
mirrors are read by humans, so they stay normal prose whatever compression style the session uses.
Commits and pull request bodies follow the repository's own convention.

## Stage 0 — Resolve the tracker

1. Read `docs/agents/issue-tracker.md` in the repo. If it exists it is the answer: follow it for
   creating, reading, commenting, labelling, linking and closing.
2. Otherwise detect: `git remote -v` at GitHub → `gh`; at GitLab → `glab`; no remote → local markdown
   under `.scratch/`. Confirm in one line with the user, and record the detected tracker in the
   map's *How this is executed* (Stage 5); planning writes no file. Where the detected tracker is
   local, first make sure `.scratch/` is ignored, before anything is written there, as
   [SESSIONS.md](./SESSIONS.md) §4 *The run's own paths stay ignored* says. The run's orchestrator writes
   `docs/agents/issue-tracker.md` from that record and commits it onto the integration branch with
   the first merge batch's mirror commits (`/orchestrate`, *Merge the batch*), so the next run does
   not re-detect it. Outside a run, `/setup-matt-pocock-skills` from the required Matt Pocock skills
   writes that file.

Then make sure the repo carries the labels `meta:orchestration`, `ready-for-agent`,
`ready-for-human`, `executor:fable`, `executor:opus`, `executor:sonnet`, `effort:medium`,
`effort:high`, `effort:xhigh`. Create what is missing.

**Work that lands in more than one repository is a paired run**, planned by this one session from
the lead repository. This stage then runs once per repository, and every later stage changes as
[SESSIONS.md](./SESSIONS.md) §6 *Planning a paired run* says: read it before going on.

Done when: every repository's tracker is named and carries the label vocabulary.

## Stage 1 — Grill

Call the Skill tool for `/grilling` on the user's raw input, and again for `/domain-modeling`
whenever vocabulary is in play; naming a skill in prose does not reliably load it. Both are
**required** — see [README](../../README.md); if either is missing, stop and install it (the README
says how on each host) rather than improvising a grill.
Facts are yours to find: dispatch `scout-haiku-medium` (one known thing), `scout-sonnet-high` (a
sweep), `scout-opus-medium` (one precise judgment over narrow evidence) or `scout-opus-high` (a broad
or uncertain analysis) for anything the codebase can answer, and put only decisions to the user.

Done when: no open question remains, every repository the work lands in is named, and the user has
confirmed the consolidated understanding. A repository named here for the first time gets its
Stage 0 now.

## Stage 2 — Specs

Consolidate the grilled understanding into one or more specs. A spec is a coherent, independently
shippable slice — split where the work serves different surfaces or could ship separately; a small
effort is legitimately one spec. **Split with Stage 4 in mind**: two specs that will edit the same
files cannot ship separately, so they are one spec wearing two titles.

Pick a run slug and create `run:<slug>` (description: "Belongs to delivery run <slug> - <title>").
Before writing, sketch the seams the work will be tested at — existing seams first, the highest seam
possible, ideally one, each with a one-line note on what it catches and what it misses — and confirm
them with the user. Then write each spec on this template, opening it with the as-of line — in a
paired run followed by its `Paired specs` line ([SESSIONS.md](./SESSIONS.md) §6) — and publish it
with `ready-for-agent`, `run:<slug>` and its own `spec:<slug>` label (description: "Belongs to spec <ref> - <title>"). No
file paths and no code in a spec; those belong to tickets. The exception is a prototype snippet that
encodes a decision more precisely than prose (a state machine, a schema, a type shape), trimmed to
the decision.

```markdown
As of <date>: written against <base> @ <sha>.

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

The as-of line is the anchor of every "as of" claim in the body: `<base>` is the branch the repository
was read on and `<sha>` its commit then, so a reader of the mirror can check the claims although the
mirror is written later.

**The repository keeps a mirror of each spec** as `docs/spec-<spec-slug>-v<N>.md`, and planning
writes none: the orchestrator of the run that delivers the spec adds it onto the integration branch
in the batch where the spec's first ticket merges, and regenerates it at the close, so it travels in
the run's one review request (`/orchestrate`, *Merge the batch* and *Closing upward*). There is no
`docs/` branch and no docs pull request. Its header is the title line, links to the spec, the map
and the tickets from its first write, the date it was copied and the integration branch it was
copied onto; below the header, the item's body verbatim, the as-of line included. A mirror is a
point-in-time copy that the spec's own run will falsify, so write its claims to survive delivery:
"as of <date>, X" rather than "X is", and never renumber a `path:line` citation later — the quoted
text is the evidence, the number is only its address at writing time. **The spec item is the one
written copy.** Whoever closes the run writes the delivery notes there — past-tensing or marking each
claim the run's tickets reversed, deleting nothing — and then regenerates each mirror whole from it:
the mirror keeps its own header (the title line and the note above the body: the links, the date
copied, the integration branch, the lineage of earlier versions) and takes the item's body below that
header verbatim — on the local tracker, everything under the item's header lines and above its first
dated section, which stays on the item. Done when the mirror below its header and the item's body
diff empty.

Done when: every grilled decision is owned by exactly one spec, every spec item exists and
carries its as-of line.

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
Each blocking ticket, or "None (can start immediately)". Omit this section where the tracker records
the edge natively (GitHub, GitLab Premium): the edge is what the frontier read counts, and a copy in
the body drifts from it.

## Execution
executor: fable | opus | sonnet · effort: medium | high — one line saying which axis (exploration
or decision weight) set the level, per the effort ladder in [DEFAULTS.md](./DEFAULTS.md). For a
high-consequence ticket, name every clause it meets (irreversible, run-wide or adversarial) and
say whether a decision is open (`fable`) or the design is settled (`opus`). Choose tier and
effort independently. `xhigh` is never planned: `/orchestrate` reaches it by a hand-back.

## Surface
writes: …
reads: …
runtime: dev-db | dev-server | none[, peer:<folder>, …]
deps: shared | own
```

The surface block follows SESSIONS.md §2 in full. A ticket without a surface cannot be placed in a
wave, so there are no exceptions.

A `runtime:` of `dev-server` means the orchestrator walks the app for that ticket, and the walk is
driven by **Playwright MCP** where the server is connected — the executor never starts a dev server.
Write the ticket's runtime criterion as what a walk must *observe*, not as an instruction to the
executor: the surface to open, the role to sign in as, the property to measure, and the value it
must hold. A criterion an executor cannot satisfy and a walk cannot check is not a
criterion. In a paired run, a walk that needs another repository's running app declares it on the
same line, one `peer:<folder>` entry per repository (`runtime: dev-server, peer:payments-service`):
the launch then borrows that working copy (SESSIONS.md §2 and §6), and an undeclared need stops the
walk.

Label every ticket `ready-for-agent`, `run:<slug>`, its spec's `spec:<slug>`, its `executor:` and
`effort:`, plus the repo's own area/type/priority vocabulary. Link it as a child of its spec and
record every blocking edge, cross-spec and cross-repository edges included, per TRACKERS.md.

Done when: every ticket is a child of its spec, carries executor, effort and run labels, declares a
surface, and has its edges recorded.

## Stage 4 — Waves

Run the collision check of SESSIONS.md §3 over the tickets, then compute the **wave order**: no two
tickets in one wave collide, blocking edges respected. A high-consequence ticket is
usually the seam later tickets compose, so it sits in the wave that blocks them; check the edges say
so. Nothing is committed and no tooling is added to the repo.

### Settle the base and where the run closes

Every run delivers through one **integration branch**, cut from the run's **base branch**, merged
into locally ticket by ticket, kept current with the base, pushed only at the close and taken to the
base in one review request (`/orchestrate`, *The integration branch*). Read the base from the
repository's own rules (`CLAUDE.md`, `AGENTS.md`, a conventions document), otherwise take the
remote's default branch (`git ls-remote --symref origin HEAD`); with no remote, ask. Name the
integration branch in the repository's branch-prefix vocabulary, `feat/<run-slug>` by default.
Planning cuts nothing: `/orchestrate` cuts it at the first wave.

Then ask the user once, in one question, confirming the base with it: `Run closes at:` —
*draft review request opened*, *review request opened*, *merged* or *deployed*; in a repository
without a forge, *branch ready* (the integration branch pushed where a remote exists, the merge
handed to the owner) or *merged* (`/orchestrate` merges it into the base with `--no-ff` after the
final gate and pushes the base where a remote exists) — and `Steps after close owned by:`, the
person who takes what follows (the merge, the deploy, a data cleanup, a seed). Stage 5 writes these
as the map's header lines, and `/orchestrate` reports every step past that point as handed over to
that person, so a run that ends at an open review request says so from the start rather than closing
"waiting on" a step that was never its own.

Done when: every ticket appears in exactly one wave, and the base, the integration branch, the close
point and its owner are recorded — in a paired run, for every repository, with the run order derived
from the cross-repository edges.

## Stage 5 — Map

Author one execution map for the run as its own item, titled
`map: <run-slug> delivery - execution plan for run <run-slug>`, labelled `run:<slug>`. Mirror the
repo's most recent map (search `map in:title`) for shape, keeping only the sections listed below:
an older map can carry a Sessions section and push-per-wave text. Under the title, the header lines
from Stage 4: `Run closes at:`, `Steps after close owned by:`, and beside them
`Integration branch: <name>, cut from <base>`. Then, in order:

1. **Execution progress** — first, above everything else, because it is the first thing a resuming
   session reads. At publication it is one line: the run has not started, wave 1 is next, and this
   section is rewritten whole in the map's body by `/orchestrate` after every wave, carrying the
   integration branch's cut, `<integration branch> cut at <sha>`, and, once one is recorded, its
   last green point, `<integration branch> @ <sha>`. It is live state,
   never a log: wave reports and dated notes go to the comment thread, or beside a local map to
   `map-log.md` ([TRACKERS.md](./TRACKERS.md)). Leaving the slot empty invites the progress to live
   in that log instead, where the next session acts without it.
2. **Parent** — the spec items, the mirror paths the run will write
   (`docs/spec-<spec-slug>-v<N>.md`), binding ADRs and seams, and any
   cross-run gate ("must not start until run X closes"), each gate naming the tickets whose closed
   state satisfies it and carrying a real blocking edge on the tickets it gates.
3. **How this is executed** — the integration branch from the header, cut by `/orchestrate` at the
   first wave's preflight, merged into locally, synced from the base and pushed only at the close,
   and its residual risk: until the close, the run's code exists only in this working copy; the
   tracker Stage 0 detected, where the repository had no `docs/agents/issue-tracker.md`; point at
   the tickets' labels for model and effort; one worktree per
   ticket at `.claude/worktrees/<run-slug>/<ticket>`, its branch never nested under the integration
   branch's name; `deps: shared` worktrees never install or generate;
   serial merge-commit-only merges on a quiescent tree, and teardown likewise; no dev server from
   executors; check-versus-fix ownership; the per-wave in-flight ceiling (default five; above five only
   on the user's word, written as the number and the reason; below five for a named reason such as
   heavy installs or a rate limit); one agent session per working copy; the
   write-through rule — every fact the next session needs is posted the moment it becomes true.
4. **Known shared-file contention** — the files parallel branches will collide on inside a session
   and how each collision is handled (append-plus-append catalogue, wave separation, stop-and-report).
5. **Waves** — Stage 4's wave order, numbered globally; every ticket line carries its spec.
   Orchestrator-only work pinned to a wave (a baseline, a runtime check) names its owner: the session
   that runs that wave, or the close. A pinned runtime check states **how it is driven**: Playwright
   MCP by default, the scripted Playwright fallback or plain HTTP only where the check does not need a
   DOM, or where it produces an artifact
   rather than a page and is settled by fetching it. `/orchestrate`'s walk brief carries the check
   verbatim, so write it as what the walker must open, measure and find.
6. **Why the executors split this way** — one paragraph naming every ticket not at `high` and the
   axis that moved it, and every high-consequence ticket, whichever tier runs it, with every clause
   it meets (irreversible, run-wide or adversarial) and the second verification it will get.
7. **Completion gate** — the repo's one-shot gate commands and quality bars, from its `CLAUDE.md` or `AGENTS.md`.
8. **Rework protocol** — hand-backs to the introducing executor, at most twice; gate re-runs whole;
   post-merge defects become new issues; the mirror pass of `/orchestrate`'s close order (rules in Stage 2) runs before the map closes.
9. **Out of scope** — carried from the specs so no executor picks it up opportunistically.

**A paired run** — work that lands in more than one repository — has one map per repository, each in
that repository's own tracker, and the lead map also carries the *Paired runs* line and the *Run order
across repositories* section, all as SESSIONS.md §6 says.

Done when: the map item exists and every
ticket appears in exactly one wave.

## Stage 6 — Stop

The pipeline ends here, hard: no dispatch, no worktree, no executor, however ready it looks.
Execution belongs to a fresh session. Report the tracker references (specs, map, tickets per wave)
and print the solo launch lines ready to copy:

```
/orchestrate map <map> + check                             # read-only preflight, writes nothing
/orchestrate map <map>                                     # one session, wave by wave
/orchestrate map <map> + all                               # one session, every wave, no stop between
```

**A paired run** prints, in place of the solo lines, the run order as launch lines: every
repository's `+ check` line, then one line per launch grouped by step, each led by the folder of the
repository it runs in, because each repository has its own session started there:

```
billing-service   /orchestrate map <its map> + check
portal            /orchestrate map <its map> + check
# G1
billing-service   /orchestrate map <its map> + wave 1
# G2, once billing-service 01 is closed
portal            /orchestrate map <its map> + wave 1
```

Then the lines that make those launches from one herdr pane, run from the folder that holds the
repositories:

```
/conduct <lead map> + check                                # read-only, starts nothing
/conduct <lead map>                                        # launch what is ready now, then stop
/conduct <lead map> + watch                                # every step of the run order, waking as sessions settle
```
