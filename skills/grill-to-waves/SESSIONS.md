# Sessions — surfaces, waves and paired runs

One delivery run covers one or more specs. Every ticket declares at ticketing what it may write, and
those surfaces order the run: `/grill-to-waves` writes the surface block on every ticket and runs the
collision check that computes the waves, and `/orchestrate` keeps overlapping tickets out of flight
together. This file is the protocol both skills share; they point here rather than restating it.

A run is executed in one of **two shapes**:

- **solo** — the single-repository shape: one `/orchestrate` session, wave by wave. One session owns
  every merge, so there is nothing to coordinate.
- **paired** — the multi-repository shape: one run slug across several repositories, one
  `/orchestrate` session in each repository's own working copy, driven by `/conduct` in the lead
  map's run order ([PAIRED.md](./PAIRED.md)).

**Two agent sessions never share one working copy.** A second session in the same working copy
contends on the tree, the dev server and the dev database at once, so finding one is a stop (§5).
Work that needs a second session gets a second working copy — in a paired run, each repository's
own.

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
- **Spec** — an item whose title begins `spec: `, carrying `spec:<slug>`: one coherent, independently
  shippable slice of the run.
- **Ticket** — an item carrying both an `executor:` and an `effort:` label. Specs and the map are
  never tickets, whatever else they carry. Every count and frontier in this protocol means tickets by
  this definition. An item under the run label with `ready-for-agent` but without the pair is a
  **mislabelled ticket**: report it by name as "unlabelled, not dispatchable", never file it silently
  under "probably a spec".
- **Map** — the run's execution plan item, titled `map: …`. Its body is a register: written once by
  the pipeline, edited afterwards only on a quiescent tree. Comments are append-only and safe.
- **Session** — one agent context window (Claude Code, Codex, or another host) executing a map, or
  part of one, wave by wave: the run's map when it is solo, its own repository's map when it is
  paired.
- **Write surface** — the paths and non-file resources a ticket may write (§2).
- **Wave** — the tickets a session dispatches together: no two of them collide (§3), and every
  ticket that blocks one of them sits in an earlier wave.

## 2. The ticket surface block

Every ticket carries a `## Surface` section, written at ticketing:

```
## Surface

writes: src/lib/dashboard-data.ts, src/app/(admin)/admin/page.tsx
reads: src/lib/payments.ts, prisma/schema.prisma
runtime: dev-db
deps: shared
```

- `writes:` is a **contract**. An executor that must write outside it stops and reports; it never
  widens the edit. The ticket's acceptance criteria say so. It covers tracked repository content
  only — the ticket's branch, its comments and anything gitignored are outside it; a ticket has no
  review request of its own. Generated output or a lockfile the ticket did not declare **is** a
  breach.
- `reads:` is informational and never used for collision.
- `runtime:` is `dev-db`, `dev-server` or `none` — what the **orchestrator's verification** of the
  ticket needs — and `dev-db` or `dev-server`, never `none`, may be followed by any number of
  `peer:<folder>` entries, so a ticket with one is always walked. Each `peer:` entry names, by its
  folder, a repository of the paired run whose running app that verification needs, and makes the ticket's
  launch borrow that repository's working copy ([PAIRED.md](./PAIRED.md)): `runtime: dev-server, peer:payments-service`.
  A `peer:` entry takes no part in collision, since different working copies share no file.
  Executors never touch the dev server or the dev database (no migrations, no seeds);
  only the orchestrator does. A `dev-server` verification is driven by **Playwright MCP**
  (`mcp__playwright__*`) where that server is connected, and by the scripted Playwright fallback or
  plain HTTP where it is not — which of the two was used is stated in the report, never left implied.
- `deps:` is `shared` (junctioned dependency tree) or `own` (a full copy; required for any ticket
  that changes the schema or a dependency).
- Non-file resources compare like paths, with a scheme prefix: `db:schema`, `db:dev-data`,
  `tracker:#231`, `label:<name>`, `env:vercel`.

**Surfaces are guesses**, derived from prose before code is read, so they are the weakest link in
the wave order — which is why a breach is a stop, never a widening. **A path that does not yet exist
is declared exactly**, never as a directory glob, and each new test file is listed by name: a
directory glob collides with every other ticket touching that directory. Every ticket carries the
block: a ticket without one cannot be placed in a wave, so planning publishes none, and a ticket
added after planning gets its block before it joins a wave.

## 3. Collision — which tickets may be in flight together

Two tickets **collide** when their write surfaces overlap: equal paths, or one is a glob whose root
prefixes the other, compared case-insensitively on repo-relative POSIX paths (`git ls-files` is the
authority on casing; two paths differing only in case are one file on Windows). `src/**` overlaps
`src/lib/**`; `src/lib/**` and `src/app/**` do not. Two tickets under one directory stay disjoint
only when both declare exact paths and no third ticket declares a glob over that directory.

Two tickets that overlap are never in flight together: planning puts them in different waves, and
`/orchestrate`'s frontier rule holds the second until the first has merged.

## 4. Worktrees

Every ticket runs in its own worktree at `.claude/worktrees/<run-slug>/<ticket>`, under about 120
characters end to end; set `core.longpaths true` on the clone before the first run that uses them.
Each ticket gets its own branch, named in the repository's prefix vocabulary and cut from the run's
recorded commit on its integration branch (`/orchestrate`, *The integration branch*). Ticket
branches never nest under the integration branch's name, because git refuses `feat/x` and
`feat/x/…` side by side: with `feat/<run-slug>` as the integration branch, a ticket branch is
`feat/<n>-<short-slug>`, never `feat/<run-slug>/<n>`. A worktree whose
dependency tree is a link is torn down only by the junction-safe procedure in
[DEFAULTS.md](./DEFAULTS.md).

**The run's own paths stay ignored.** They are the worktree and scratch folders under the host's
agent directory — `.claude/worktrees/` and `.claude/scratch/` on Claude Code, `.codex/worktrees/`
and `.codex/scratch/` on Codex ([DEFAULTS.md](./DEFAULTS.md) *Hosts*) — and `.scratch/` where the
tracker is local. Test each with `git check-ignore -q <path>x`, which holds even when the folder does
not exist yet; one that is not reported as ignored (exit 1) is appended, as its own line with the
trailing slash, to the clone's local exclude file: `info/exclude` under `git rev-parse
--git-common-dir`, created if missing. That file sits in the common git directory, so it covers every
worktree of the clone, and nothing is committed. In bash:

```sh
git check-ignore -q .claude/scratch/x || echo '.claude/scratch/' >> "$(git rev-parse --git-common-dir)/info/exclude"
```

In PowerShell:

```powershell
git check-ignore -q .claude/scratch/x; if ($LASTEXITCODE -ne 0) { Add-Content -Path (Join-Path (git rev-parse --git-common-dir) 'info/exclude') -Value '.claude/scratch/' }
```

For a repository other than the current folder — another repository's local tracker that planning
writes in a paired run ([PAIRED.md](./PAIRED.md)) — run the same test there with `git -C ../<folder>`, and take that
clone's exclude file as an absolute path, because `--git-common-dir` is otherwise relative to
`../<folder>`, not to the current folder:

```sh
git -C ../<folder> check-ignore -q .scratch/x || echo '.scratch/' >> "$(git -C ../<folder> rev-parse --path-format=absolute --git-common-dir)/info/exclude"
```

```powershell
git -C ../<folder> check-ignore -q .scratch/x; if ($LASTEXITCODE -ne 0) { Add-Content -Path (Join-Path (git -C ../<folder> rev-parse --path-format=absolute --git-common-dir) 'info/exclude') -Value '.scratch/' }
```

Not a committed ignore entry: it would arrive with the first merge batch, after the first preflight
had already met the untracked paths.

## 5. Breach and stop

An executor that must write outside `writes:` stops and reports. A surface breach, whether the
executor reports it or the diff the session reads shows it, is a re-planning decision, never a
widening: the session swaps the ticket's `ready-for-agent` for `ready-for-human`, posts a comment
naming the ticket and the path, and drops it from the batch. A ticket's third failure is handed to a
human the same way: every hand-back counts toward its two, a merge conflict's included, the count
kept on the map's execution progress so it survives the session (`/orchestrate`, *Record, close,
tear down*), and on the third failure the session swaps its `ready-for-agent` for `ready-for-human`,
posts on it the findings that failed it, and drops it from the batch (`/orchestrate`, *Record,
close, tear down*). Either way, the batch's other green tickets merge, gate, walk and record green
as usual, the wave is torn down — the dropped ticket's worktree with it, its uncommitted work
committed as one work-in-progress commit and its branch kept and named (`/orchestrate`, *Record,
close, tear down*) — and the session stops at the end of that wave, under `+ all` too. The label is
what keeps a later session from merging it: a resuming session's reconcile reads a surviving
`ready-for-agent` worktree as an executor's lost report, or, where the map counts hand-backs for it,
as rework in progress — either way, work it may verify and merge.

Stop and hand the decision to the user, with the reason posted on the ticket or the map, for: a
non-quiescent tree that cannot be cleaned, or a second agent session found in this working copy —
by its registered worktree, or by a working-copy claim its guard reads as live or the user does not
confirm stale, whether the claim file, the claim line or a move-aside file holds it (`/orchestrate`
Stage 1, *The single-session guard*). What the guard cannot see, or cannot judge without asking,
is the residual risk `/orchestrate`'s CLAIMS.md states (*Its residual risk*), and for a lender in a
paired run, [PAIRED.md](./PAIRED.md).

## 6. Paired runs

A run across several repositories — its format, the borrow check, borrowing, and how it is planned —
is [PAIRED.md](./PAIRED.md). Read it when the run spans more than one repository, or a ticket's
`runtime:` carries `peer:<folder>`.
