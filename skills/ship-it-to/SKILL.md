---
name: ship-it-to
description: Promote the integration branch to staging or production — resolve the repo's own promotion contract, cut a pivot, gate it, say whose work is travelling, open the request, and stop where the forge says you must. Takes stg or prd.
disable-model-invocation: true
---

# Ship it to

```
/ship-it-to stg      promote to the staging branch
/ship-it-to prd      promote to the production branch
```

Where `/orchestrate` ends — a wave merged into the integration branch and pushed — this begins. It
is a separate skill because promotion is a different job: it happens once per release rather than
once per wave, its gate runs on a combination the integration branch never tested, and its failure
mode is a production deploy rather than a handed-back ticket.

**Nothing here is assumed from memory.** Every value below is read out of the repository or the
forge, because the last repo's answer is not this repo's answer:

| What | Where it comes from | Never |
|---|---|---|
| Source and target branch names | The repo's own conventions doc, then `git branch -r` | `dev`/`main` by habit |
| Gate command | The conventions doc, then `package.json` scripts, `Makefile`, `justfile` | `npm test` by habit |
| Remote name | `git remote -v` | `origin` by habit |
| Forge CLI | The remote's host: GitHub → `gh`, GitLab → `glab` | Assuming GitHub |
| Promotion shape | The conventions doc's promotion section | Inventing one |
| Who may merge | The forge's branch protection, and your own role | Assuming you may |

## Stage 0 — Resolve the promotion contract

1. **Read the repo's rules first.** `docs/steering/conventions.md`, `CONTRIBUTING.md`, `CLAUDE.md`,
   `AGENTS.md` — whichever exist. Look for the section that names the branches and describes how a
   change reaches the target.
2. **Detect what the docs do not say**: the remote and its host, the branches that exist, the gate
   command.
3. **Map the argument to a branch.** `stg` → the staging branch, `prd` → the production branch. If
   that branch does not exist, **stop and say so**. A pipeline can carry an environment whose branch
   was never created; the environment existing is not the branch existing.
4. **If the repo describes no promotion shape, ask** — pivot branch, a request straight from the
   integration branch, or a fast-forward. Do not pick one. The shape decides whether the target
   gains a merge commit, which decides whether the promoted commit keeps its sha, which decides
   whether an immutable image registry sees the same tag twice.

Done when: source, target, gate command, remote, forge CLI and promotion shape are each named in one
line, each with where it was read from.

## Stage 1 — Read the protections before planning anything

```
glab api projects/:id/protected_branches            # GitLab, plus:
glab api user                                       #   your id
glab api projects/:id/members/all/<id>              #   your access level
gh api repos/{owner}/{repo}/branches/<b>/protection # GitHub
```

Three facts decide where this run ends: whether you may **push the target**, whether you may
**merge into the target**, and whether you may **push the pivot**. A protected branch commonly
refuses a push while allowing a merge request — and often refuses the merge too, reserving it to a
higher role.

State it in one line before touching anything: *"you may open the request; a Maintainer must merge
it"*, or *"you may merge it yourself"*. A push you have established will be rejected is not a plan,
and a protection you cannot satisfy is never worked around — no force push, no second remote, no
direct commit on the target.

## Stage 2 — Cut the pivot and absorb the merge locally

```
git switch <target> && git pull
git switch -c pivot/<short-desc>
git merge <source>              # every conflict is resolved here, on the pivot
```

The pivot exists so the target is never the place a conflict is resolved, and so the request that
reaches it is already conflict-free and already gated. Reach for `resolving-merge-conflicts` when a
conflict is more than trivial. If the repo's contract says fast-forward instead, follow the repo.

## Stage 3 — Establish what is travelling, and whose it is

```
git log --format='%h | %an | %s' <target>..HEAD
git diff --shortstat <target>...HEAD
```

**Name every author out loud, before pushing.** A promotion that carries other people's commits is a
decision the user has to make, not a detail to mention afterwards: their work reaches production on
your run, under your request, and they were not asked.

If the user wants only some of it, **check dependency, not just authorship**:

- Test the cherry-pick on a scratch branch before promising it. A commit that edits a file, a
  comment block or a config another unpromoted commit introduced will conflict.
- A commit can apply cleanly and still be wrong on arrival. A document describing a pipeline that
  only exists in an unpromoted commit is false the moment it lands, and a document that contradicts
  the file next to it is worse than no document.
- Say which of the two you hit, and let the user choose: ship the subset that stands alone, or take
  the dependency with it.

Done when: the user has seen the commit list with its authors and agreed to it.

## Stage 4 — Gate on the pivot

Run the repo's own gate **on the pivot**, never on the source's last green run. The combination on
the pivot is one the source never tested whenever the promotion is partial or the target had
commits of its own. Install dependencies if the checkout has none. Report the command and its real
result — a gate nobody ran is not a green gate, and saying so costs less than a rollback.

## Stage 5 — Name the environment's configuration debts

Read the pipeline config for what the **target environment** needs and the others do not: registry
coordinates, cluster names, role ARNs, per-environment variables the file deliberately leaves out.
Check whether they exist. If the forge refuses to tell you — reading CI/CD variables is commonly
denied below Maintainer — **write that into the request as an unverified precondition** rather than
guessing. Never imply a deploy will succeed when you could not see what it needs.

## Stage 6 — Push, open the request, and stop where the rules say

Push the pivot, then open the request. Its body carries four things, because they are what the
person merging has to decide on:

1. **What is promoted** — the commits, with their authors.
2. **The gate** — the command, and its result.
3. **What merging actually does** — publishes an image, deploys unattended, or waits for a manual
   job. Say which; "merged" and "deployed" are different events.
4. **The configuration debts** from Stage 5, including the ones you could not verify.

Mechanics that bite:

- Non-interactive: `glab mr create … --yes`, `gh pr create …`. A multi-line body goes through a
  heredoc, a here-string or `--body-file` — never a double-quoted shell string, which eats
  backticks, `$name` and apostrophes.
- `glab mr merge <iid>` can answer `400 SHA must be provided when merging`. Pass the head sha:
  `glab api projects/:id/merge_requests/<iid>` → `.sha`, then `--sha <sha>`.
- `glab mr note --message` is deprecated in favour of `glab mr note create`.
- Merge only when Stage 1 said you may. Otherwise stop, and name the role that must.

## Stage 7 — After it merges

- Delete the pivot, on the remote and locally. It is a vehicle, not a branch.
- Bring the target back into the source if the repo says to — and remember that a protected source
  branch makes even that a merge request.
- Tell the user what is now running and what still needs a button pressed.

## Replacing a request you already opened

When a promotion is narrowed after the fact, **say why on the old request before closing it**, then
open the new one and point the old at it. A request that disappears without a reason reads as a
mistake to everyone who saw it.

## Red flags

- *"The integration branch was green yesterday"* → the gate runs on the pivot.
- *"Just push it"* → the branch is protected, and you knew that at Stage 1.
- *"I will drop the other authors' commits"* → dependency check first, on a scratch branch.
- *"Merged, so it is live"* → only if the pipeline says so. Check the job.
- A request body that lists no authors, or claims a gate that was not run.
