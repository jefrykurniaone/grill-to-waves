---
name: daily-recap
description: "Write the end-of-day work recap you post to your team: Done / Next / Blocker, from the day's commits, agent sessions and meetings."
argument-hint: "[today | yesterday | 2026-09-22]"
disable-model-invocation: true
---

# Daily recap

The recap is posted into a team channel at the end of the day, beside colleagues' recaps. It is read
by people who do not have this machine, this checkout, or any of its local files. Write for them.

This skill is not part of the plan → execute → promote pipeline. It reports on whatever the day
held, a pipeline run included.

## Steps

1. **Resolve the day.** The argument, or today when there is none.

2. **Collect the evidence.** From the skill directory:

   ```powershell
   powershell -File scripts/collect-evidence.ps1 -Date <today|yesterday|YYYY-MM-DD> [-Root <work dir>]
   ```

   ```bash
   ./scripts/collect-evidence.sh --date <today|yesterday|YYYY-MM-DD> [--root <work dir>]
   ```

   Read-only, and it needs `git` (plus `jq` for the bash one). It prints the day's commits per
   repository, marking which are this machine's own, and then each coding-agent session of that
   day — what it was asked for and its closing report — from `~/.claude/projects` (Claude Code) and
   `~/.codex/sessions` (Codex). Both default to repositories under the current directory; pass the
   root where the day's work actually lives, more than once if it spans several.

3. **Read what the evidence points at**, only where the recap needs it: an execution map for what
   comes next, an open merge or pull request, a spec that was written. Do not re-derive the day's
   work from the code.

4. **Draft the recap** with the rules and template below. Draft before asking anything — people
   correct a draft faster than they recall a day.

5. **Ask once, in one short line**, for what no file records: calls and meetings, discussions,
   reviews, anything done away from the keyboard, and whether anything is blocking them. Fold the
   answer in and reprint the whole recap.

## Rules

- **Plain business language**, in the language the team's channel uses. Short bullets, one line
  each. No headings beyond the three sections, no sub-bullets, no closing summary.
- **Nothing that exists only on this machine.** No file paths, commit hashes, branch names, local
  ticket or issue numbers, wave or run names, model or agent names. A shared merge request may be
  mentioned as "MR open, waiting for review", without its number, unless the user asks for it.
- **Name the outcome, not the artefact.** "Removed validations from rules", not "resolved ticket 03".
- **One outcome per bullet.** Several commits serving one goal are one bullet.
- **The user's work only.** Drop teammates' commits and upstream or vendor commits.
- **Meetings are Done items**, named the way the invite named them.
- **Never invent.** Only what the evidence shows or the user confirms. When a bullet would need a
  guess, ask instead.
- **Done** is 3 to 7 bullets, **Next** 2 to 4, **Blocker** the real ones or `None`.
- A blocker says what is stuck and what would unblock it, including a personal one — a usage limit,
  a licence, an access request.

## Template

```
<D Mon YYYY>

**Done**
- <outcome>

**Next**
- <what is picked up next>

**Blocker**
- <what is stuck, and what it needs> | None
```

## Example

A day of one syncup, one discussion call, a database sync, a planning session, and three tickets
merged across two branches:

```
22 Sept 2026

**Done**
- Daily syncup with the Payments team
- Call to discuss the refund policy for partial shipments
- Synced the local billing-service database with the latest migrations
- Planned how billing-service will match the platform template: removing the direct connector, moving data access to the shared query layer, adding invoice paging and filters, and outbox messaging
- Aligned the billing-service dev workflow with the team git strategy, and moved the test database into Docker Compose (MR open, waiting for review)
- Removed validations from rules

**Next**
- Remove the connector and its mock from billing-service
- Migrate data access to the shared query layer

**Blocker**
- Staging credentials for the broker are still missing; raised with platform ops
```
