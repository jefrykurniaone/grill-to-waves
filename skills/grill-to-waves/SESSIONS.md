# Sessions — the spec is the unit of splitting

One delivery run covers one or more specs. Each spec can be executed on its own, and the specs are
made **write-disjoint** at ticketing so that two people can execute two of them without corrupting
each other's work: `/grill-to-waves` constructs the proof (the surface block on every ticket, the
collision check, the map's Sessions table) and `/orchestrate` re-checks it before it dispatches. This
file is the protocol both skills share; they point here rather than restating it.

There are **two shapes**, and neither takes a lock:

- **solo** — one person, one session, wave by wave. The default and the right answer for most runs.
  One session owns every merge, so there is nothing to coordinate. `/orchestrate`'s solo sections are
  self-contained; the only thing solo owes this file is the surface and collision vocabulary its map
  was built from.
- **team** — several developers on their own machines, one spec row each. A second developer shares
  no working copy, no dev server and no dev database with you. What you share is `origin/main` and
  the tracker: `origin/main` is serialised by the forge's branch protection, and ownership is the
  tracker's assignee.

**Two agent sessions never share one working copy.** That is the case locks used to buy, and this
protocol no longer covers it: a second session in the same working copy contends on the tree, the
dev server and the dev database at once, and the only supported answer is a second clone. Splitting a
run means splitting it across working copies — one per developer — or not splitting it at all.

## Invariants

1. **Nothing is true until it is on the tracker.** Sessions share no context window. A fact that was
   never posted did not happen, and the next session redoes the work.
2. **One working copy, one session.** Merge, the whole completion gate, every write to the dependency
   tree, worktree teardown and pruning all assume nobody else is in this tree.
3. **Never install into, or generate into, a junctioned dependency tree.** It empties the shared copy
   for every worktree at once.
4. **When in doubt, stop and write down why.** A conservative stop with a posted reason beats a
   proceed-carefully.

## 1. Vocabulary

- **Run** — one pipeline invocation: its specs, tickets and map, grouped by the `run:<slug>` label.
- **Spec** — an item whose title begins `spec: `, carrying `spec:<slug>`. The **unit of splitting**.
- **Ticket** — an item carrying both an `executor:` and an `effort:` label. Specs and the map are
  never tickets, whatever else they carry. Every count and frontier in this protocol means tickets by
  this definition. An item under the run label with `ready-for-agent` but without the pair is a
  **mislabelled ticket**: report it by name as "unlabelled, not dispatchable", never file it silently
  under "probably a spec".
- **Map** — the run's execution plan item, titled `map: …`. Its body is a register: written once by
  the pipeline, edited afterwards only on a quiescent tree. Comments are append-only and safe.
- **Sessions table** — the map section assigning every ticket to one **row**: a spec row (one spec, or
  a fused group of specs one session executes) or the **tail** row. "The published split" means this
  table.
- **Session** — one agent context window (Claude Code, Codex, or another host) executing part of a map. Three kinds: **solo** (the
  whole map, wave by wave), **spec** (one spec row, team shape), and **tail** (the tail row, then the
  map close).
- **Write surface** — the paths and non-file resources a ticket may write (§2).
- **Run-exclusive** — a ticket whose surface is shared by everything: schema, migrations, lockfile,
  `package.json`, an environment target. It runs only in a solo or tail session, and in a team run it
  belongs to the **serial owner**.

## 2. The ticket surface block

Every ticket carries a `## Surface` section, written at ticketing:

```
## Surface

writes: src/lib/dashboard-data.ts, src/app/(admin)/admin/page.tsx
reads: src/lib/payments.ts, prisma/schema.prisma
runtime: dev-db
deps: shared
exclusive: no
```

- `writes:` is a **contract**. An executor that must write outside it stops and reports; it never
  widens the edit. The ticket's acceptance criteria say so. It covers tracked repository content
  only — the ticket's branch, its review request, its comments and anything gitignored are outside
  it. Generated output or a lockfile the ticket did not declare **is** a breach.
- `reads:` is informational and never used for collision.
- `runtime:` is `dev-db`, `dev-server` or `none` — what the **orchestrator's verification** of the
  ticket needs. Executors never touch the dev server or the dev database (no migrations, no seeds);
  only the orchestrator does. A `dev-server` verification is driven by **Playwright MCP**
  (`mcp__playwright__*`) where that server is connected, and by the scripted Playwright fallback or
  plain HTTP where it is not — which of the two was used is stated in the report, never left implied.
- `deps:` is `shared` (junctioned dependency tree) or `own` (a full copy; required for any ticket
  that changes the schema or a dependency).
- `exclusive:` is `no` or `run`. Set to `run` for any ticket writing a database schema, a migration
  directory, `package.json`, a lockfile, an environment target, or a tracker item of another run.
- Non-file resources compare like paths, with a scheme prefix: `db:schema`, `db:dev-data`,
  `tracker:#231`, `label:<name>`, `env:vercel`.

Surfaces are declared before code is read, so they are the weakest link in the proof — which is why
a breach is a stop, never a widening. **A path that does not yet exist is declared exactly**, never
as a directory glob, and each new test file is listed by name: a directory glob fuses the ticket to
every other ticket touching that directory. A ticket with no block is treated as `exclusive: run` by
a spec session (skipped and reported by name) and as `exclusive: no` by a solo session; the tail
session runs it.

## 3. Collision — can these specs run apart?

Two tickets **collide** when their write surfaces overlap: equal paths, or one is a glob whose root
prefixes the other, compared case-insensitively on repo-relative POSIX paths (`git ls-files` is the
authority on casing; two paths differing only in case are one file on Windows). `src/**` overlaps
`src/lib/**`; `src/lib/**` and `src/app/**` do not. Two tickets under one directory stay disjoint
only when both declare exact paths and no third ticket declares a glob over that directory.

Two **specs collide** when a ticket of one collides with a ticket of the other. The pipeline resolves
every collision at ticketing, in this order of preference:

1. **Move the ticket** to the spec whose surface it really belongs to.
2. **Mark it run-exclusive** if it is the schema/lockfile/environment class anyway — it leaves the
   spec rows and joins the tail.
3. **Fuse the two specs** into one row (`spec A + spec B`). A fused row is still two spec items on
   the tracker; one session executes both.

The result is the Sessions table: one row per session, listing its specs, its tickets, and the exact
`/orchestrate` line that launches it, plus the tail row (present even when empty — the tail session
also closes the map), and a **verdict line**: `splittable N ways` or
`not splittable: <fusing surface>`. Documentation, standards and repo-wide sweeps almost always land
on `not splittable`.

Blocking edges are **not** collisions: a cross-spec `blocked_by` means one session waits, not that
two sessions contend. List them in the row so the user knows a session may idle.

Collision inside one row is that session's own problem: two of its tickets that overlap are never in
flight together (`/orchestrate`'s frontier rule). `/orchestrate` re-derives the cross-row check from
live ticket bodies at admission; a disagreement with the published table is a stop, never a silent
re-split.

## 4. Ownership in a team run

- **The assignee is the ownership signal**, the mechanism people already use. A developer assigns
  themselves the spec item and its tickets before dispatching, and **skips any ticket assigned to
  someone else**, naming it in the report. There is no agent-owned claim and no `claimed` label.
- **An assignee is scope, not a lock.** When the tickets in scope are assigned to someone other than
  the user you are working for, say so and confirm before dispatching, rather than stopping.
- **The serial owner** is named once for the whole run, in the map's Sessions section. Every
  `exclusive: run` ticket belongs to that one person, whichever row it came from, because two
  developers running a migration in the same week produce divergent histories that do not reconcile
  cleanly. Those tickets sit in the tail row.
- **The forge is the serialiser.** Branch protection with required status checks and *require branches
  to be up to date before merging* is what makes a team's merges safe. Check it once and say plainly
  if it is missing or if the required checks are weaker than the map's completion gate.
- **A rejected push is normal, not a failure.** Someone landed first: pull, re-merge onto the new
  `origin/main`, re-run the **whole** gate — their change plus yours is a combination neither of you
  has gated — and push again. Never force-push, and never skip the second gate.
- **A defect in another row's surface is filed, never fixed.** You cannot see what they are mid-way
  through changing.

Worktrees live at `.claude/worktrees/<row>/<ticket>`, under about 120 characters end to end; set
`core.longpaths true` on the clone before the first run that uses them. Branch names carry no row
marker.

## 5. Resume — rebuild state from the tracker and git

Four entry points: first start, context clear, crash, interrupted turn. Nothing local is trusted, no
prior report is trusted, no executor's account of worktree state is trusted.

1. **Map** — run slug, Sessions table and verdict, waves, contention table, gate, out of scope.
2. **Map comments and other open maps** naming this run — cross-run gates are written as prose on the
   *other* run's map. A gate is verified by reading the named tickets' states.
3. **Tickets** — one listing of every item under the run label with state, labels, body and open
   blockers (TRACKERS.md's frontier read returns the body too); classify by §1; the surface blocks
   feed the collision re-check.
4. **Git ground truth** — `fetch --prune`, `status --porcelain`, last commits on `main`, every review
   request with state, head branch and merge commit, `git worktree list`. Where there are no review
   requests, the merge commit is the evidence: `git log --merges -E --grep '#<n>([^0-9]|$)' main`,
   anchored, because `#25` also matches `#253`.
5. **Reconcile** per open in-scope ticket, before dispatching anything: merged review request and open
   ticket → post the record and close it, do not re-run; an open review request → read the diff, adopt
   or close it, saying which; a branch with no review request and no worktree → inspect, salvage or
   delete, announced; nothing → a normal frontier candidate.
6. **Worktrees** — list them; one whose ticket is closed is torn down by the junction-safe procedure
   in [DEFAULTS.md](./DEFAULTS.md), then `git worktree prune`, then repair the generated client if it
   is missing.
7. Compute the frontier and dispatch.

Deliberately not reconstructed: the previous session's reasoning, executor transcripts, intermediate
verification.

## 6. Breach and stop

An executor that must write outside `writes:` stops and reports. The session then: if the path is
inside its own row's surface union, re-sequences and continues; otherwise it swaps the ticket's
`ready-for-agent` for `ready-for-human`, posts a comment naming the ticket and the path, and stops —
a surface breach across rows is a re-planning decision, not a widening.

Stop and hand the decision to the user, with the reason posted on the ticket or the map, for: a third
hand-back, a non-quiescent tree that cannot be cleaned, a collision the re-check found that the
published table does not have, or a second agent session found in this working copy.

## 7. What this does not protect against

Say these to the user when a run is split.

- **Disjoint writes prove non-collision, never independence.** Two specs can share a type, a
  translation key, a seam contract. Serial merges plus a whole-gate re-run after each merge is the
  only net, and it catches only what the gate catches.
- **Surfaces are prose-derived guesses** made before code is read.
- **Splitting buys executor parallelism only.** It pays when executor time per ticket clearly exceeds
  gate time. Measure the gate once and say so, and budget the map's in-flight ceiling — three by
  default, five at the hard maximum — against that measurement.
- **Each session pays the full protocol read** — three sessions are three context budgets.
- **A team's dev databases are separate, and its migrations are not**: the serial owner owns every
  migration, and a row that assumes a column another row has not migrated yet fails at the gate.
- **A single sweep ticket collapses the split**, and that is the common case for docs and standards
  runs.
- **Polling costs API calls.** Retry a failed read; never treat an API or fetch error as "nothing to
  do" or "main is unchanged".
