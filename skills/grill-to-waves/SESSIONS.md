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
  map's run order (§6).

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
  launch borrow that repository's working copy (§6): `runtime: dev-server, peer:payments-service`.
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
writes in a paired run (§6) — run the same test there with `git -C ../<folder>`, and take that
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
by its registered worktree, or by a live working-copy claim (`/orchestrate` Stage 1, *The
single-session guard*).

## 6. Paired runs — one run across repositories

Work that lands in several repositories is a **paired run**: the same run slug in every repository,
and in each its own tracker, map, `/orchestrate` session, integration branch and review request to
its own base branch — one session per working copy, as everywhere. Each integration branch is named
in its own repository's prefix vocabulary, as Stage 4 settles it per repository. One
of the maps, the **lead map**, also carries what crosses them:

- **A `Paired runs` line** under its header lines: `Paired runs (same run slug, each its own
  tracker, map, integration branch and review request):`, then every other repository's
  map — a path relative to the lead repository (`../billing-service/.scratch/<slug>/map.md`), or, where the tracker is remote, a
  tracker reference prefixed by the repository's folder (`billing-service#41`). Every other map's
  header names the lead map the same way.
- **A section titled *Run order across repositories*** — the schedule:

  ```
  | Step | Repository · wave · tickets | Released by |
  |---|---|---|
  | G1 | billing-service · 1 · 01; ledger-service · 1 · 01 | — |
  | G2 | payments-service · 1 · 01–03 | billing-service 01; ledger-service 01 |
  | G3 | portal · 1 · 02, 04 · borrows payments-service | payments-service wave 1 |
  ```

  A row lists every repository wave its step starts, `;`-separated, each with that repository's own
  wave number. *Released by* names what must be closed first: tickets as `<repository> <ticket>`, a
  whole wave as `<repository> wave <k>`, or the owner's go-ahead — a decision. `—` is released from
  the start. A blocker is released once it is merged onto its own repository's integration branch,
  locally, and closed — long before that repository's close. Repositories are named by their folder names, the lead's included; *this repository* in the table
  means the lead map's. A row may name part of a wave: its launch still runs the whole wave, whose
  orchestrator dispatches only the tickets with no open blocker, and a later row takes the rest.

  A launch **borrows** a repository's working copy when any ticket of the repository wave it runs
  names that repository as `peer:<folder>` in its `runtime:` (§2) — any ticket of the whole wave, not
  only those its row names, because the launch runs the whole wave. The borrows are written after its
  tickets as `· borrows <folder>[, <folder>]`: `portal · 1 · 02, 04 · borrows payments-service`,
  several as `· borrows billing-service, payments-service`. It is a suffix, not a column, because one
  row holds several launches and only some of them borrow. The repository a launch borrows is its
  **lender**. **The borrowing
  rule:** the launch occupies each working copy it borrows for its whole duration, as it occupies
  its own, so no session of that repository runs meanwhile and the borrower's session is the only
  one there; its walk uses that working copy only while the lender passes the borrow check below,
  and writes nothing to its tracked tree but the one restoring `/orchestrate` *The runtime walk*
  names. `/orchestrate` *The runtime walk* has the walk's procedure, and `/conduct` Stage 2
  when a launch is ready. A dependent uses another repository's working copy only by borrowing it.

  **The borrow check** says whether a lender is somewhere a walk can use. `/conduct` runs it when
  it computes a borrowing launch's readiness, and the borrower runs it before its walk, the same
  way. A lender passes when all three hold:

  1. `git --no-optional-locks -C ../<folder> status --porcelain` is empty. The option keeps the
     read off the lender's index lock, which a merge under way there needs.
  2. The lender shows no session: it passes this condition only with all three of these:
     - `git -C ../<folder> worktree list` shows no registered worktree besides the lender's main
       working copy;
     - no claim file, `working-copy-claim`, sits at the top of the lender's git common directory
       (`git -C ../<folder> rev-parse --path-format=absolute --git-common-dir`);
     - its map carries no claim line, `claimed: …`, which the third condition's read of the map
       already gives.

     They are the lender's single-session guard's own reads (`/orchestrate` Stage 1, *The
     single-session guard*, *The working-copy claim*): a registered worktree is a live session or
     its leftover, a claim is a live session from its guard to its outcome line or one that died
     holding it, and each is the lender's own business first. This condition reads whether a claim
     stands, never whether it is stale: a stale claim fails it too, until the lender's next session
     takes it over or the owner removes it — its claim file and, where its map carries one, the
     map's claim line. A `working-copy-claim.<token>` file beside it is a take-over's or a
     release's leftover, never a claim file.
  3. Its `HEAD` (`git -C ../<folder> rev-parse HEAD`) matches its map's state, the map read through
     the lender's own tracker ([TRACKERS.md](./TRACKERS.md) *Across repositories*):
     - while its map is open and records a cut, `HEAD` equals its recorded commit;
     - once its map is closed, `HEAD` holds its last recorded commit, an ancestor of `HEAD` or
       equal to it (`git -C ../<folder> merge-base --is-ancestor <that commit> HEAD`), which also
       covers a no-forge *merged* close whose `HEAD` is on the base;
     - while its map records no cut, `HEAD` equals that clone's `origin/<base>` as last fetched,
       the base its map names, or the local base where there is no remote.

  The check only reads: neither the borrower nor the conductor fetches anything in the lender, and
  a read that keeps failing fails its condition, never passes it. A live `/orchestrate` session
  in the lender shows in its claim at every moment of its turn, and a live wave in its registered
  worktrees too, which is what the second condition reads. **The residual risk** is what no claim
  can show, and only that:
  - an agent session that runs no `/orchestrate`, such as the owner working by hand, makes no
    worktree and takes no claim, so in a lender it is seen only by `/conduct`'s pane read, and not
    at all outside herdr;
  - a claim left by a session that died outside herdr cannot be told stale without the user, so it
    costs the next session in that lender one question (`/orchestrate` Stage 1, *The question is
    the guard's one question*), or under `/conduct` the owner's removing it — its claim file and,
    where its map carries one, the map's claim line (`/conduct` Stage 2, *Occupied by a session
    outside the run order*), and until then it fails the second condition.

  **A borrow that outlived its session.** A borrower's map carries `borrowing <folder> since <time>`
  from before it starts a lender's app until that walk's leftovers are dealt with (`/orchestrate`
  *The runtime walk*). While the line stands the lender is still lent, whatever became of the
  borrower's session: its app may be running there and its dev database may hold the walk's data.
  No session of the lender starts, and no other launch borrows it, until the line is gone, which
  is the work of the next session of the borrower's repository (`/orchestrate` Stage 1, *A
  borrowed walk that died*). For that session's launch alone, whoever starts it waives the check's
  first condition on that lender, because the app's own rewrites are what its cleanup restores. The
  other two still hold, since a registered worktree, a claim or a moved `HEAD` is no walk's
  leftover — a borrower takes no claim in its lender — and its next walk runs the whole check.

  Released launches of different repositories run at the same time when they occupy no repository
  in common; one repository's waves run one after another, in its one session.

The run order is the schedule, never the proof. Each repository's map still records its own
cross-repository blocking edges on its tickets, so its orchestrator verifies them itself
(`/orchestrate` Stage 1, *Cross-run gates*). `/conduct` executes the run order from one herdr pane.

### Planning a paired run

One `/grill-to-waves` session plans the whole run, from the **lead repository**: the one whose spec
carries the user-facing story, usually the user interface, and whose map becomes the lead map. The
run's repositories are sibling folders, which is how the maps and the run order name them. Reading
another repository, by this session or its scouts, is always safe; writing into one follows the rule
below. The stages change in these ways and no others:

- **Stage 0, once per repository.** Each repository's tracker is resolved from its own
  `docs/agents/issue-tracker.md` or its own remote, and each tracker gets the label vocabulary; the
  trackers may differ. A repository that grilling adds later gets its Stage 0 before Stage 2.
- **Writing into another repository.** A remote tracker is written by naming the repository on every
  call ([TRACKERS.md](./TRACKERS.md) *Across repositories*), which touches no working copy. A local
  tracker is written only inside this run's own `.scratch/<run-slug>/` folder, beside the one entry
  that keeps `.scratch/` ignored in that repository's clone, appended to its local exclude file with
  `git -C ../<folder>` as §4 says. While the run has not started there, that folder belongs to no
  session, so planning writes it even while another run's session works in the same working copy.
  Once that repository's map records a started wave, the folder is its orchestrator's: a later
  change goes to the user, never straight into the folder.
- **Stage 2, specs per repository.** Every spec belongs to one repository, because its tickets, its
  map and the session that closes it are that repository's. The lead's spec carries the user-facing
  story; every other spec, what its repository does for it. A contract between repositories (an API,
  an event, a stored shape) is owned by the spec of the repository that provides it, and the others
  name that spec rather than restate it. Every spec opens with its as-of line, then lists the run's
  other specs on a `Paired specs` line, in the notation of the *Paired runs* line. `run:<slug>` is
  the same in every tracker, and every `spec:<slug>` is unique across the run. Each repository's mirrors follow the
  general rule of Stage 2, written onto its own integration branch.
- **Stage 3, edges across repositories.** The edge lives on the blocked ticket only, in the form
  [TRACKERS.md](./TRACKERS.md) *Across repositories* gives for that pair of trackers, so the blocked
  repository's frontier read counts it live. Blockers-first publishing spans the repositories.
- **Stage 4, per repository, then the run order.** Collision and waves are each repository's alone:
  different working copies share no file. The base, the integration branch and the close lines are
  settled in one exchange and answered per repository, since each has its own base branch,
  integration branch, review request and reviewer. Then derive the run order. A
  launch is one repository wave, and it goes one step after the latest of its own repository's
  previous wave and every launch holding a cross-repository blocker of one of its tickets; a launch with neither goes in G1. *Released by*
  names those blockers. Where only some tickets of a wave wait, the others may start a step
  earlier, as a row naming part of the wave. Every `peer:` entry of every ticket in the repository
  wave a launch runs, not only of the tickets its row names, is carried onto that launch as its
  `· borrows` suffix, each folder once: two rows naming parts of one wave each carry the whole
  wave's borrows.
- **Stage 5, a map per repository**, in its own tracker, each with every section Stage 5 lists for
  that repository alone. Its *Parent* names the paired specs, and every cross-repository edge its
  tickets carry is listed there as a cross-run gate. The lead map adds the *Paired runs* line and the
  run order; every other map's header names the lead map.
