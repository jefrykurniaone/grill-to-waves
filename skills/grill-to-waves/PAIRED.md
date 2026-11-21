# Paired runs — one run across repositories

This is §6 of the session protocol, held apart because only a run across several repositories, or a
ticket whose `runtime:` borrows another repository's app, reaches it. Its §1–§5 are
[SESSIONS.md](./SESSIONS.md).

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
  names that repository as `peer:<folder>` in its `runtime:` ([SESSIONS.md](./SESSIONS.md) §2) — any ticket of the whole wave, not
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
  2. The lender shows no session: it passes this condition only with all four of these:
     - `git -C ../<folder> worktree list` shows no registered worktree besides the lender's main
       working copy;
     - no claim file, `working-copy-claim`, sits at the top of the lender's git common directory
       (`git -C ../<folder> rev-parse --path-format=absolute --git-common-dir`);
     - no move-aside file, `working-copy-claim.<token>`, sits beside it where a second read still
       finds it;
     - its map carries no claim line, `claimed: …`, which the third condition's read of the map
       already gives.

     They are the lender's single-session guard's own reads (`/orchestrate` Stage 1, *The
     single-session guard*, *The working-copy claim*): a registered worktree is a live session or
     its leftover, a claim is a live session from its guard to its outcome line or one that died
     holding it, and each is the lender's own business first. This condition reads whether a claim
     stands, never whether it is stale: a stale claim fails it too, until the lender's next session
     takes it over or the owner removes it — its claim file and, where its map carries one, the
     map's claim line. A `working-copy-claim.<token>` file beside the claim file that a second read
     still finds is a claim standing too: it is the name a take-over or a release passes the claim
     file through, and a take-over that died mid-move can leave a live claim only there
     (`/orchestrate`'s CLAIMS.md, *A move-aside file*). No other session's guard removes one, stale or
     not: its holder's next guard or ownership check restores it as the claim file, or deletes it
     once the claim file carries the holder's token again, or the owner removes it. One that a
     second read no longer finds was another session's take-over or release passing through.
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
  worktrees too, which is what the second condition reads. **The residual risk** is what the claim
  cannot show, or cannot judge without asking, and only that (`/orchestrate`'s CLAIMS.md, *Its
  residual risk*):
  - an agent session that runs no `/orchestrate`, such as the owner working by hand, makes no
    worktree and takes no claim, so in a lender it is seen only by `/conduct`'s pane read, and not
    at all outside herdr;
  - a claim left by a session that died outside herdr, or one written under another herdr server or
    on another machine, whose pane no session here reads, cannot be told stale without the user,
    so it costs the next session in that lender one question (`/orchestrate`'s CLAIMS.md, *The
    question is the guard's one question*), or under `/conduct` the owner's removing it — its
    claim file and, where its map carries one, the map's claim line (`/conduct` Stage 2, *Occupied
    by a session outside the run order*), and until then it fails the second condition;
  - a terminal nested inside a herdr pane that neither renames the terminal program nor sets a
    multiplexer's marker reads that pane as its own pane (`/orchestrate` Stage 1, *The own pane*),
    so its session's guard reads a live claim of the outer pane as one naming its own pane, and
    takes it over without asking;
  - in the window between a take-over's read of the claim file and its move, a fresh claim another
    session has just written can be moved aside; the take-over writes it back, and where it dies
    first, the claim is left in a move-aside file, which its holder's next guard or ownership check
    restores and which fails the second condition meanwhile.

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
  `git -C ../<folder>` as [SESSIONS.md](./SESSIONS.md) §4 says. While the run has not started there, that folder belongs to no
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
