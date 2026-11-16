# Tracker mechanics

How each tracker implements the five operations the pipeline and the orchestrator need: **publish**
an item, **link as child**, **record a blocking edge**, **label**, and **read the frontier**. A repo's
own tracker record, `docs/agents/issue-tracker.md` (*The tracker record*, below), is read first and
governs which tracker is used and how items, labels and links are recorded on it; the commands stay
in this file, and only a tracker this file has no section of commands for has them described in its
record (*Other trackers*), which the owner writes before planning.

Each tracker's **Deliver** line covers only the run's close. Up to then delivery is the same on every
tracker: the orchestrator merges each ticket's branch into the run's integration branch locally, with
a merge commit whose subject starts `Merge #<n> ` (`#NN` on a local tracker) — the reconcile
evidence `/orchestrate`'s Stage 1 grep matches, anchored to that form and read only among the run's
own merges — and pushes nothing before the close.

## GitHub (`gh`)

- **Publish**: `gh issue create --title "..." --body-file <file>`. Author bodies to a scratch file;
  inline `--body` mangles multi-line text in PowerShell.
- **Label**: `gh label create <name> --description '...'` (check `gh label list` first), then
  `--label` on create or `gh issue edit <n> --add-label`. Single-quote a description containing a
  backtick or `$`.
- **Link as child** — native sub-issues, which nest (ticket under spec). The API takes the child's
  **database id**, not its number:

  ```
  gh api repos/<o>/<r>/issues/<n> -q .id
  gh api -X POST repos/<o>/<r>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>
  ```

- **Blocking edge** — same database-id rule:

  ```
  gh api -X POST repos/<o>/<r>/issues/<blocked>/dependencies/blocked_by -F issue_id=<blocker-db-id>
  ```

- **Frontier read** — one listing gives state, labels, bodies and the count of **open** blockers,
  which the `gh issue list` command cannot:

  ```powershell
  gh api -X GET 'repos/{owner}/{repo}/issues' -f 'labels=run:<slug>' -f state=open -f per_page=100 --paginate `
    --jq '.[] | {n: .number, title, blocked: .issue_dependencies_summary.blocked_by, labels: [.labels[].name], body}'
  ```

  `blocked_by` counts open blockers; `total_blocked_by` counts all.
- **Comment** — `gh issue comment <n> --body-file <file>`. Author the body to a scratch file; an
  inline multi-line body is mangled by PowerShell. Where a comment id is wanted, post through REST
  and quote the endpoint — bare `{owner}` is a script block to PowerShell:
  `gh api -X POST 'repos/{owner}/{repo}/issues/<n>/comments' -F "body=@$file" --jq .id`.
- **Deliver**: one pull request per run, from the integration branch to the base, opened by the
  orchestrator at the close once the branch is pushed:
  `gh pr create [--draft] --base <base> --head <integration branch> --title "..." --body-file <file>`,
  `--draft` when `Run closes at:` is *draft review request opened*. Tickets reach the integration
  branch by local merges and have no pull request of their own; executors open none.

## GitLab (`glab`)

- **Publish**: `glab issue create --title "..." --description "..."` (heredoc for multi-line).
- **Label**: `glab issue update <iid> --label "..."` — created on first use.
- **Link as child**: no native sub-issues on the free tier. `Part of #<parent>` at the top of the
  description, plus `glab api projects/:id/issues/<child>/links -f target_issue_iid=<parent>`.
- **Blocking edge**: the `/blocked_by #<n>` quick action as a note. Native blocking links are
  Premium; on the free tier a `Blocked by: #<n>, #<n>` line at the top of the description, and the
  frontier read parses it.
- **Comment**: `glab issue note <iid>`, or `POST projects/:id/issues/<iid>/notes` where a numeric `id`
  is wanted.
- **Deliver**: one merge request per run, from the integration branch to the base, opened at the
  close as on GitHub:
  `glab mr create [--draft] --source-branch <integration branch> --target-branch <base> --title "..." --description "..." --yes`
  (heredoc for the multi-line execution record).

## Local markdown (`.scratch/`)

One run per directory, `.scratch/<run-slug>/`.

- **Publish**: `spec-NN-<slug>.md` per spec, `map.md`, and one ticket file per ticket at
  `issues/NN-<slug>.md`, numbered from `01` in dependency order — never one combined file. `map.md`
  holds the run's live state only — the header lines, the execution-progress section and the
  planned sections — because `/orchestrate` reads it whole at every start; its log lives beside it
  in `map-log.md`.
- **Label**: header lines stand in — `Status:` (one of `ready-for-agent`, `ready-for-human`,
  `needs-info`, `wontfix`, `resolved`; `resolved` is the closed state everywhere this protocol says
  "closed"), `Run:`, `Spec:`, `Executor:`, `Effort:`. The `## Surface` block lives in the file
  verbatim.
- **Link as child**: a `Part of: <parent filename>` header line.
- **Blocking edge**: a `Blocked by: NN, NN` header line. A ticket is unblocked when every file it
  lists carries `Status: resolved`.
- **Comment**: append a `## <ISO date>` section to the item's file, written with the Write/Edit tools,
  never through a PowerShell round trip. A comment on the map — a wave report, a delivery note, any
  dated narrative — is appended to `map-log.md`, so `map.md` stays the state a session resumes from
  and `map-log.md` the history it reads only when a question needs it. The first `/orchestrate`
  session to meet a `map.md` that carries dated sections migrates it once, at Stage 1, before
  dispatching: move every dated section into `map-log.md` in its original order (creating the file),
  rewrite the execution-progress section to the bounded state `/orchestrate`'s *Record, close, tear
  down* prescribes, and say so in the wave report. Done when `map.md` has no `## <ISO date>` heading.
- **Deliver**: no review request — the no-forge close. The run ends at *branch ready*, the
  integration branch pushed where a remote exists and the merge handed to the owner, or at *merged*,
  the orchestrator merging it into the base with `--no-ff` after the final gate and pushing the base
  where a remote exists. References in the map and mirrors are file paths, not numbers.

## Other trackers (Jira, Linear, …)

Planning's Stage 0 never detects such a tracker. It is used only where `docs/agents/issue-tracker.md`
already names it, written before planning by the owner or by `/setup-matt-pocock-skills`, in the
layout of *The tracker record*'s last paragraph; `/orchestrate` writes no record for it. The record
describes the workflow in prose; follow it for publish, label, link,
edge and close. Two things to establish before the first run and record in the map's "How this is
executed" section: **how a comment is posted** (a REST call, or the CLI), and **what stands in for
labels** (a field, a component, a tag). Everything else in
[SESSIONS.md](./SESSIONS.md) is tracker-neutral.

- **Deliver**: the forge's *Deliver* above for the repository's remote — GitHub's or GitLab's;
  without a forge remote, the no-forge close of *Local markdown*.

## Across repositories

A paired run ([SESSIONS.md](./SESSIONS.md) §6) writes trackers other than the working directory's
and records blocking edges between them. Its repositories are sibling folders, each named by its
folder.

- **Name the other repository on every call**: `gh … -R <owner>/<repo>`,
  `glab … -R <group>/<project>`, and an `api` endpoint spelled out in full
  (`repos/<owner>/<repo>/…`, `projects/<url-encoded path>/…`), because `{owner}`, `{repo}`, `:id` and `:fullpath` resolve to the working directory's repository. A
  local tracker is a path, `../<folder>/.scratch/<run-slug>/`, written only as SESSIONS.md §6
  allows.
- **The blocking edge lives on the blocked ticket**, in the form its own tracker's frontier read
  counts:
  - **GitHub to GitHub**: native, by the blocker's URL —
    `gh issue edit <n> -R <owner>/<repo> --add-blocked-by https://github.com/<owner>/<other>/issues/<m>`.
    The REST form above takes the other repository's issue too, by its database id. As of
    2026-10-23 both forms held across two repositories of one owner: the frontier read's
    `blocked_by` counted the open blocker and dropped to 0 once it closed. Across owners it is
    untested; where GitHub refuses that blocker, write the line of *any other pair* instead.
  - **GitLab to GitLab**: on Premium, a native link naming the other project —
    `glab api -X POST projects/<url-encoded path>/issues/<iid>/links -f target_project_id=<url-encoded other path> -f target_issue_iid=<m> -f link_type=is_blocked_by`.
    On the free tier, the `Blocked by:` line with GitLab's cross-project reference,
    `<group>/<project>#<m>`.
  - **Local to local**: the `Blocked by:` header line names the blocker by its path from this
    repository's root, `../<folder>/.scratch/<run-slug>/issues/NN-<slug>.md`, released as always by
    that file's `Status: resolved`.
  - **Any other pair** (a local tracker and a remote one, or two forges) shares no edge. The blocked
    ticket carries a `Blocked by:` line, a header line on a local tracker and the first line of the
    body on a remote one, naming the blocker as `<folder>#<m>`, or by its path where the blocker's
    tracker is local. The frontier read parses that line beside the tracker's own count, resolves
    `<folder>` to `../<folder>`, and reads the blocker's state through that repository's tracker.
- **A blocker that cannot be read is open.** A failed read in another repository is a wait, never a
  release.

## The tracker record

`docs/agents/issue-tracker.md` names a repository's tracker, so that planning and orchestration do
not detect it again, and says how items, labels and links are recorded on it. The mechanics, the
commands that carry the operations out, stay in this file for every tracker it has a section of
commands for. Where the repository has none, `/orchestrate` writes it from the map's record of the
tracker planning's Stage 0 detected — GitHub, GitLab or local (its *Merge the batch*, step 3) — in
this layout:

1. **A title**: `# Issue tracker`.
2. **One paragraph** naming the tracker, its CLI where it has one, and the repository or project it
   is driven on — for a local tracker, the `.scratch/` folder — and saying that a session that plans
   or orchestrates a run here uses the tracker as recorded and does not re-detect it.
3. **`## Structure`**: how children and blocking edges are recorded on that tracker — on GitHub,
   native sub-issues and native dependencies; on GitLab, the `Part of` line with its link, and the
   native link or the `Blocked by:` line; on a local tracker, the `Part of:` and `Blocked by:`
   header lines.
4. **`## Labels`**: the vocabulary, each label with its meaning — `meta:orchestration`, the ticket
   states `ready-for-agent`, `ready-for-human`, `needs-info` and `wontfix`, `run:<slug>`,
   `spec:<slug>`, `executor:<tier>` and `effort:<level>` — and, on a local tracker, the header lines
   that stand in for them.
5. **`## Operations`**: a table of the operations — publish an item, link as child, record a
   blocking edge, label, read the frontier, comment, deliver the run — each row pointing at that
   tracker's section of `TRACKERS.md` in the `grill-to-waves` skill and, where the section has one,
   the operation's bold name there, never at a repository path, because the skill is installed
   outside the repository. A row whose operation has no bold entry in its section (GitLab and local
   markdown have no **Frontier read**) points at the section alone. The commands are not restated.

For any other tracker, whose section here is *Other trackers* and carries no commands, the record,
which the owner writes by hand before planning and `/orchestrate` never writes (*Other trackers*),
describes each operation in prose instead of pointing at one — publish, link, blocking edge, label,
frontier read and close — and says **how a comment is posted** and **what stands in for labels**,
the two facts that section requires; its *Operations* row for delivering the run points at that
section's **Deliver**.
