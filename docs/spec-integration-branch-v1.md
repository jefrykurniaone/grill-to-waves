# spec: integration-branch v1 - every run delivers through one integration branch and one review request

Spec: [#11](https://github.com/jefrykurniaone/grill-to-waves/issues/11) · Map: [#16](https://github.com/jefrykurniaone/grill-to-waves/issues/16) · Tickets: [#12](https://github.com/jefrykurniaone/grill-to-waves/issues/12), [#13](https://github.com/jefrykurniaone/grill-to-waves/issues/13), [#14](https://github.com/jefrykurniaone/grill-to-waves/issues/14), [#15](https://github.com/jefrykurniaone/grill-to-waves/issues/15)

Copied 2026-11-16 onto `feat/integration-branch`. Below this header, the body of #11 verbatim; the issue, not this file, is the spec.

---

As of 2026-11-16: written against `main` @ `a497acc`.

## Problem statement

The owner plans delivery runs with `/grill-to-waves` and executes them with `/orchestrate`. Four things get in the way:

- **Planning opens its own docs pull request.** The spec mirrors are written on a `docs/` branch with a pull request of their own. In a recent run in another repository the owner had to merge that pull request by hand in the middle of the run, and the run's own pull request then carried the same commit again.
- **The default delivery pushes to the base branch.** `/orchestrate` merges every wave into the local `main` and pushes it, against the owner's standard: nothing is pushed to `main` directly; changes reach it by a pull request that passes CI. Repositories that follow the standard override the skill by hand, through project memory and per-map text.
- **Executors open one review request per ticket**, while those repositories deliver one review request per run.
- **The team shape is dead weight.** Several developers executing one map, one spec row each, has never been used, the owner has found no form of it that avoids conflicts, and it fills a large share of the text every planning and orchestrating session reads.

The vocabulary also disagrees with itself: "integration branch" is the long-lived branch in `/ship-it-to` and the glossary, and the per-run branch in the paired-run section.

## Solution

Every run delivers through one **integration branch**, cut from its **base branch**, kept local until the run's close, kept current with the base, and taken to the base in **one review request** that carries both the code and the spec mirrors. Planning commits nothing to the repository. A run is solo, or paired across repositories; the team shape is removed together with everything that only served it.

## Goals and non-goals

Goals:

- One delivery path for every run, solo and paired.
- Spec mirrors travel in the run's own review request: no docs branch, no docs pull request.
- Nothing is pushed before the run's close; executors push nothing and open no review request.
- A run stays current with its base branch, and a break caused by the base surfaces before the review request.
- The skill text loses the team shape and everything that only served it, and keeps every rule solo and paired runs still need.
- One meaning per word: *base branch* for the long-lived branch, *integration branch* for the per-run branch.

Non-goals:

- Any shape in which several developers execute one run.
- Repositories whose rules require each ticket to reach the base branch through its own review request merged by the forge.
- A backup push of the integration branch before the close.
- Changes to executor tiers, the effort ladder, the agent set, `/conduct`'s launch mechanics, or `/ship-it-to`'s promotion procedure beyond its vocabulary.

## User stories

1. As a run owner, I want planning to commit nothing to the repository, so that I never merge a docs pull request by hand in the middle of a run.
2. As a run owner, I want the spec mirrors to arrive in the same review request as the run's code, so that one review covers the whole delivery.
3. As a run owner, I want every run to work on an integration branch cut from the base branch, so that nothing reaches the base branch without a review request.
4. As a run owner, I want the base branch read from the repository's own rules, falling back to the remote's default branch, so that runs work where the base is `master`, `dev` or `stg`.
5. As a run owner, I want the map's header to name the integration branch and its base, so that a resuming session and a human reader know where the work lives.
6. As a run owner, I want nothing pushed until the run's close, so that the remote only ever sees finished, gated work.
7. As a run owner, I want executors never to push and never to open a review request, so that the run's review request is the only one.
8. As a run owner, I want the integration branch synced from the base branch whenever the base has moved — at every wave's preflight and once more before the review request — so that conflicts and semantic breaks surface while they are cheap and the review request is mergeable.
9. As a run owner, I want every sync done by a merge commit and followed by the whole gate, whichever files the base changed, so that a change in a file the run never touched cannot break it silently.
10. As an orchestrator, I want a sync conflict whose resolution needs a product decision to be a stop, so that I never decide a product question while merging.
11. As an orchestrator, I want the map to record the integration branch's last green commit after every green wave, so that a red gate has a reset point and the next wave a base, with no remote to provide them.
12. As a resuming orchestrator, I want to trust the local integration branch only when it contains the recorded green commit, so that a lost or rewritten branch is a stop rather than a silent restart.
13. As an orchestrator, I want to commit a spec's mirror onto the integration branch, as its own commit, in the batch where that spec's first ticket merges, so that the mirror carries the map and ticket references from its first write.
14. As a reader of a mirror, I want the spec item to state the date and commit it was written against, so that its "as of" claims can be checked although the mirror is written later.
15. As a run owner, I want the close to run in a fixed order — delivery notes, mirror pass, final sync, whole gate, push, one review request — so that the review request is current, gated and complete when it opens.
16. As a run owner, I want to choose at planning whether the run's review request opens as a draft, so that I can hold it for my own checks before anyone reviews it.
17. As the owner of a repository without a forge, I want the close to end at *branch ready* or *merged*, so that a run still closes where no review request can exist.
18. As a run owner, I want an irreversible ticket that Fable did not verify to wait for my go-ahead before its wave is recorded green, so that no later wave is built on work I have not approved.
19. As a planner, I want Stage 4 to compute the waves and settle the base and the close point without asking for an execution shape, so that planning asks nothing that only served a team.
20. As a maintainer of these skills, I want the team shape removed wherever only it used the text, and the shared rules kept and reworded, so that every session reads less and nothing solo or paired needs is lost.
21. As a planner of a paired run, I want every repository to have its own integration branch and review request, and a cross-repository edge released once the blocker is merged locally and closed, so that a paired run on one machine never waits on another repository's close.
22. As a reader of the glossary and of `/ship-it-to`, I want *base branch* for the long-lived branch and *integration branch* for the per-run branch, so that one word never names two things.
23. As an executor, I want my brief and my agent definition to say the same thing — commit on my ticket branch, never push, never open a review request, report the branch and the commit — so that I am never handed two delivery rules.
24. As a Codex user of these skills, I want the Codex executor definitions to carry exactly the same bodies as the Claude Code ones, so that both hosts deliver the same way.

## Implementation decisions

Modules touched: the `grill-to-waves` skill (its main document, SESSIONS, TRACKERS and DEFAULTS), the `orchestrate` skill, `conduct` (section references and the meaning of a released edge), `ship-it-to` (vocabulary only), the executor agent definitions on both hosts, the glossary, the README and the changelog.

### Integration branch and delivery

- **Base branch** comes from the repository's own rules (its `CLAUDE.md`, `AGENTS.md` or conventions document), otherwise the remote's default branch. Stage 4 settles it in the same exchange as the close point, and Stage 5 writes it into the map's header as `Integration branch: <name>, cut from <base>`.
- **The orchestrator cuts the integration branch** at the first wave's preflight, from `origin/<base>`, when it does not exist yet; a resuming session uses the existing local branch. It is named in the repository's branch-prefix vocabulary, `feat/<run-slug>` by default. Ticket branches never nest under its name, because git refuses `feat/x` and `feat/x/…` side by side. Planning cuts nothing.
- **Executors** commit on their ticket branch inside their worktree, never push, never open a review request, never touch the integration or the base branch, and report the branch and the commit. Fable's correctness argument goes into that report; the orchestrator posts it on the ticket and summarises it in the run's review request. The Codex caveat in which the orchestrator pushes and opens a request for an executor without network goes away. Claude Code and Codex agent bodies are edited identically, by hand, because nothing checks their parity.
- **Merges** are local `--no-ff` merges into the integration branch with `#<n>` in the subject. That subject is now the reconcile evidence on every tracker, not only the local one; per-ticket review requests no longer exist to be reconciled.
- **The last green point.** After every green wave the map's execution progress records `<integration branch> @ <sha>`, posted the moment it is true. The next wave's worktrees branch from that commit, and a red gate resets to it. Preflight asks for the integration branch checked out with `HEAD` at the recorded commit; before the first wave, for the branch absent or equal to `origin/<base>`. The runtime walk runs on the integration branch's `HEAD`.
- **Resume** trusts the local integration branch only when it contains the recorded commit; a missing branch or one without it is a stop with a report, never a rebuild. The map's *How this is executed* states the residual risk: until the close, the run's code exists only in this working copy.
- **Sync from the base.** Whenever `origin/<base>` holds commits the integration branch lacks — checked at every wave's preflight before dispatch, and once more before the review request — merge the base into the integration branch with a merge commit (never a rebase, never a force-push), then run the whole gate. A wave's own gate covers the sync at its preflight; the sync before the review request gets a gate of its own. The orchestrator resolves conflicts whose two sides it can attribute, such as append-plus-append; a conflict that needs a product decision is a stop. It syncs whichever files changed, because disjoint writes prove non-collision, never independence.
- **Irreversible tickets** that Fable did not verify wait for the user's go-ahead before their wave is recorded green. This replaces "before the push".

### Spec mirrors

- Planning, Stages 0 to 6, commits nothing to the repository.
- Stage 2 opens every spec body with one line, `As of <date>: written against <base> @ <sha>`, the anchor every "as of" claim in the body refers to. Stage 2 is done when every spec item exists and carries that line; the docs pull request leaves the done condition.
- In each merge batch, for every spec whose first ticket merges in that batch and whose mirror is absent from the integration branch, the orchestrator adds the mirror in one commit, after the batch's last merge and before its whole gate. The rule reads state, not a wave number, so it survives a reset and a resume. The clerk may do the copy; the orchestrator commits it.
- The mirror's header keeps the title line and links the spec, the map and the tickets from its first write, plus the date it was copied and the integration branch it was copied onto. The as-of line is part of the body and is copied verbatim with it. The existing rule stands: below the header, the mirror and the item's body diff empty.
- Stage 5's *Parent* names the mirror paths the run will write. The step "update each spec mirror's header with the map reference" is removed.

### Close

The close runs in this order: delivery notes on each spec item; the mirror pass as one commit; the final sync from the base; the whole gate; push the integration branch; open one review request to the base, as a draft or ready for review according to the close point, its body the execution record, with the walk's screenshots posted on it; wait to the close point; close the map.

`Run closes at:` choices are *draft review request opened*, *review request opened*, *merged* and *deployed*. In a repository without a forge they are *branch ready* (the integration branch pushed where a remote exists, the merge handed to the owner) and *merged* (the orchestrator merges into the base with `--no-ff` after the final gate and pushes the base where a remote exists). The map's close condition gains: the integration branch is synced with the base, pushed, and its review request is at the close point.

### Removing the team shape

Removed: `+ team`, `+ spec` and `+ tail`; the Sessions table, tail row, verdict line, Execution shape line and serial owner; Stage 4's execution-shape question; the map's Sessions section; Stage 6's team and fused-row launch lines, the gate-duration measurement and the human pre-flight; `exclusive:` in the surface block; assignee handling (self-assigning, skipping tickets assigned to others, dropping the assignee); the orchestrate *Team shape* section, its refusals and its retrofit; SESSIONS' ownership section, its resume section (a duplicate of orchestrate's Stage 1), the re-sequencing of a `writes:` breach (a breach is a plain stop), and its residual-risks section.

Kept and reworded:

- The surface block (`writes:`, `reads:`, `runtime:`, `deps:`) and the ticket-level overlap rule, which drive the wave order.
- "Two agent sessions never share one working copy", without "splitting a run means one developer per clone".
- `Run closes at:` and `Steps after close owned by:`.
- "Split with Stage 4 in mind", now because two specs that edit the same files cannot ship separately.
- The general rules inside the residual-risks section, each moved to where it applies: disjoint writes prove non-collision, never independence (the sync rule and the wave gate); surfaces are guesses (the surface section); a failed read is never "nothing to do" (orchestrate's Stage 1).

Naming: the SESSIONS document keeps its name, its sections are renumbered and every section reference to it is updated; Stage 4 is retitled *Waves*; worktrees live at `.claude/worktrees/<run-slug>/<ticket>`.

### Paired runs

Every repository has its own integration branch and its own review request. The paired-run mirror rule collapses into the general one. A cross-repository edge is released once the blocking ticket is merged locally and closed: the repositories are sibling working copies on one machine, so a dependent walk can use the blocker's working copy. `/conduct`'s launch mechanics are unchanged.

### Vocabulary

The glossary gains three entries, worded as agreed:

- **Base branch**: The long-lived branch a run is cut from and returns to — main, master, a staging or a development branch, as the repository names it. _Avoid_: trunk, main (as a generic).
- **Integration branch**: The branch a run cuts from its base branch, merges every ticket into, keeps current with the base branch, and returns to it in one review request. _Avoid_: run branch, docs branch.
- **Spec mirror**: The point-in-time copy of a spec item kept in the repository, written by the run that delivers the spec and regenerated from the item when that run closes; the item, not the mirror, is the spec. _Avoid_: docs copy, spec file.

*Promotion* moves from "the integration branch" to "the base branch", and `/ship-it-to` and the README use *base branch* for the long-lived branch.

## Testing decisions

A good test here checks what a user of the documents meets: an installed copy identical to the checkout, a Codex conversion that changes only the allowed tokens, and skill text a session can follow from start to close without meeting a contradiction. Four seams, highest first:

1. **The install test**, `bash tests/test-install.sh`, the local gate. It catches a broken Codex conversion, a lost required literal in orchestrate (`.claude/worktrees`, `/grill-to-waves`, `../grill-to-waves/`) and installed-copy drift. It misses contradictions in the text.
2. **A consistency sweep before the review request**: a search for leftovers of the old model (`origin/main` as a merge target, `+ team`, `+ tail`, `exclusive:`, a docs mirror branch, per-ticket review requests, stale section references), then one read-only reviewer reading the solo and the paired flow end to end. It catches contradictions; it misses behaviour.
3. **CI on the draft review request**: the docs check (version-numbered model names, agent frontmatter), PSScriptAnalyzer, shellcheck and the install tests on both operating systems. Not runnable on the owner's machine, which has neither PowerShell nor shellcheck.
4. **A sandbox run by the owner after the close, before merging**: install from the integration branch for Claude Code only, then one solo run in a throwaway repository with a bare remote and a local tracker, exercising the branch cut, no push before the close, the mirror commit, a sync after a deliberately moved base, and a close at *merged* or *branch ready*. The forge review-request path is not exercised.

Prior art: pull request #9 was tested the same way, in throwaway repositories with bare remotes and a local tracker.

## Success criteria

- A run planned and executed with the updated skills leaves no docs branch and no docs pull request, and its one review request contains the code and the mirrors.
- No skill text, agent definition or README passage instructs a push to the base branch, a push before the close, or an executor push or review request.
- No skill text, agent definition or README passage mentions `+ team`, `+ spec`, `+ tail`, the Sessions table, a serial owner or `exclusive:`.
- *Integration branch* means the per-run branch everywhere and *base branch* the long-lived one; the glossary defines both, and *Spec mirror*.
- Every section reference into SESSIONS points at the section it means.
- The Claude Code and Codex executor bodies are identical.
- The install test passes locally, and CI is green on the draft review request.
- The sandbox run shows the branch cut, no push before the close, the mirror commit, a sync merge after the moved base, and a close at *merged* or *branch ready*.

## Out of scope

- Any multi-developer shape.
- Repositories whose rules require each ticket to reach the base branch through its own forge-merged review request.
- A backup push of the integration branch before the close.
- Changes to executor tiers, the effort ladder, the agent set, `/conduct`'s launch mechanics, or `/ship-it-to`'s procedure beyond vocabulary.
- Mirrors of earlier runs.
- Steps after this run's close, owned by the owner: the sandbox run, merging, installing on both hosts, retiring the interim project memory in the other repository, and the vault worklog entry.

## Further notes

- Grilled on 2026-11-16, from the owner's request to stop separate docs pull requests. The paired-run section already had the orchestrator commit the mirrors; this spec makes that the rule for every run and widens it to the whole delivery path.
- **Bootstrap.** This run is executed by the installed `/orchestrate`, which still has the old delivery model. The run's map spells out the new protocol, and the orchestrator follows the map wherever the two differ.
- This repository has had no `docs/` folder. This spec's mirror will be its first file there, beside the tracker record `docs/agents/issue-tracker.md`.
- The changelog is dated rather than versioned; this run adds one entry.

