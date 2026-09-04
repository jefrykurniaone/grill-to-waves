# Tracker mechanics

How each tracker implements the five operations the pipeline and the orchestrator need: **publish**
an item, **link as child**, **record a blocking edge**, **label**, and **read the frontier**. A repo's
own `docs/agents/issue-tracker.md` is read first and governs which tracker is used and its item,
label, link and close mechanics. Ownership in a team run is the tracker's assignee
([SESSIONS.md](./SESSIONS.md) §4); there is no agent-owned claim record.

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
- **Deliver**: pull request, `gh pr create --body-file <file>`. The orchestrator merges locally, never
  with `gh pr merge`.

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
- **Deliver**: merge request, `glab mr create --description`. Merged locally, as on GitHub.

## Local markdown (`.scratch/`)

One run per directory, `.scratch/<run-slug>/`.

- **Publish**: `spec-NN-<slug>.md` per spec, `map.md`, and one ticket file per ticket at
  `issues/NN-<slug>.md`, numbered from `01` in dependency order — never one combined file.
- **Label**: header lines stand in — `Status:` (one of `ready-for-agent`, `ready-for-human`,
  `needs-info`, `wontfix`, `resolved`; `resolved` is the closed state everywhere this protocol says
  "closed"), `Run:`, `Spec:`, `Executor:`, `Effort:`, `Assignee:`. The `## Surface` block lives in the
  file verbatim.
- **Link as child**: a `Part of: <parent filename>` header line.
- **Blocking edge**: a `Blocked by: NN, NN` header line. A ticket is unblocked when every file it
  lists carries `Status: resolved`.
- **Comment**: append a `## <ISO date>` section to the item's file, written with the Write/Edit tools,
  never through a PowerShell round trip.
- **Deliver**: no review request. The orchestrator merges the branch with a merge commit whose
  subject carries the ticket number — the only reconcile evidence this tracker leaves. References in
  the map and mirrors are file paths, not numbers.

## Other trackers (Jira, Linear, …)

`docs/agents/issue-tracker.md` describes the workflow in prose; follow it for publish, label, link,
edge and close. Two things to establish before the first run and record in the map's "How this is
executed" section: **how a comment is posted** (a REST call, or the CLI), and **what stands in for
labels and the assignee** (a field, a component, a tag). Everything else in
[SESSIONS.md](./SESSIONS.md) is tracker-neutral.
