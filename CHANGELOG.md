# Changelog

What changed in the pipeline's rules and agent set, newest first. The repository carries no version
tags, so entries are dated. Tiers are named by alias only, as everywhere else in this repository.

## 2026-11-13 — A narrower second verification

The second verification of a high-consequence ticket was a full review on the most expensive tier.
In one five-ticket run it cost close to half of what the five executors cost together, mostly in
reading and in re-running gates the batch gate runs anyway. It now checks what can escape the net,
on the tier that check needs.

### After updating

Run the installer again (`./install.ps1 -Target both` or `./install.sh --target both`). An open map
needs no edit; a ticket whose map names one clause keeps the verifier that clause selects.

### Changed

- **The verifier follows the strongest clause.** Adversarial, irreversible, or a decision left to the
  executor: `executor-fable-high`, as before. Run-wide only, with the design settled in the ticket:
  `scout-opus-high`, because checking an implementation against a written design is a diff review.
- **The brief lists its checks.** The invariant each clause names, and each decision the executor
  made that the ticket did not settle. Scope against `writes:`, layering, regenerated files and lint
  stay with the orchestrator's diff read and the batch gate. A probe runs only where reading leaves a
  check undecided, and the verifier is done when every listed check has a verdict with its evidence.
- **A re-verification reads the delta**: the diff since the verified commit, the findings to close,
  and the original checks for whatever the rework touched, on the same agent.
- **The map names every clause a ticket meets**, since the verifier follows the strongest.

## 2026-11-10 — Opus session floor, Fable per ticket, Haiku for narrow agents

The most capable model is now spent per ticket instead of per session, so the pipeline runs on an
account without Fable and costs less on one that has it.

### After updating

1. Run the installer again (`./install.ps1 -Target both` or `./install.sh --target both`) and
   restart the session. It installs the two new agents and removes the two retired ones, backing
   them up first.
2. Replace `scout-sonnet-medium` with `scout-haiku-medium` wherever a repository's own `CLAUDE.md` or
   `AGENTS.md` names it.
3. An open map needs no edit. A ticket still labelled `executor:fable` + `effort:medium` falls back to
   `executor-opus-medium`, which is where the new rule sends it, and a ticket planned at
   `effort:xhigh` still dispatches.
4. Optional, Claude Code only: `/advisor fable` in a session below Fable.
5. `/conduct <lead map>` now launches what is ready and stops. Add `+ watch` for the earlier
   behaviour of running the whole order, and `+ sessions <n>` for more than two repositories at once.

### Changed

- **Session floor.** The session that plans, orchestrates and verifies runs on the frontier tier
  (Opus) at `high`. It replaces "the most capable model available — Fable, then Opus": no step
  requires Fable. `/orchestrate` stays at `high`; `/grill-to-waves` may run at `xhigh` for a paired
  run, a run of many specs, or one that settles a seam several tickets compose.
- **The Fable tier is narrower.** A ticket is *high-consequence* when it is irreversible, run-wide or
  adversarial. It is `executor:fable` only when it also leaves a decision open to the executor. With
  the design settled it runs on Opus.
- **Every high-consequence ticket gets a second verification** in a fresh context before it merges,
  whichever tier ran it: `executor-fable-high` with a brief that writes nothing, or `scout-opus-high`
  where Fable is unavailable. An irreversible ticket that Fable did not verify waits for the user's
  go-ahead before the push.
- **`xhigh` is earned, never planned.** Tickets are planned at `medium` or `high`. A hand-back for a
  reasoning failure at `high` is re-dispatched at `xhigh` on the same tier. `low` and `max` are not
  executor levels, and `DEFAULTS.md` now says why.
- **An executor that stops on a decision reports one question.** The orchestrator re-grades the
  ticket to Fable where Fable is available, and otherwise decides and names the decision in the wave
  report.
- **Executors dispatch no sub-agents**: `disallowedTools: Agent` on Claude Code, and the executor
  body's own instruction on both hosts.
- **`/orchestrate + check`** also prints the session's model and effort, the advisor, any environment
  variable that overrides an agent file, and every high-consequence ticket with the executor and the
  second verification it will get.
- **Precedence.** `DEFAULTS.md` names `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` and
  `CLAUDE_CODE_EFFORT_LEVEL`, which override an agent file's `model` and `effort`.
- `SESSIONS.md` states the one-session-per-working-copy rule without reference to an earlier
  protocol.

### Changed — `/conduct`, sized for one laptop

- **No watcher unless asked.** Plain `/conduct` launches what is ready, reports, and stops; Stage 1
  and `+ check` never arm one. `+ watch` keeps the run going.
- **One watcher for the whole run** instead of one process per session. It takes every session as
  `<name>:<seq>`, polls once a minute instead of every twenty seconds, exits after an hour without a
  settle instead of waiting indefinitely, and waits through `orchestrate: waiting on executors` by
  itself, so a pause no longer costs the conductor a turn. A held session gets no watcher, and none
  outlives the stop.
- **One tab, split.** The sessions `/conduct` starts run in panes split from its own tab — the
  conductor on the left, two slots stacked on the right, labelled `conduct:<folder>` — instead of
  one new tab per repository. A slot is closed and reused for the next repository once its session
  is free. `+ tabs` keeps the earlier layout, and a session beyond the second gets a tab.
- **Two sessions in flight** by default instead of five; `+ sessions <n>` changes it.
- **Five executors per session**: the launch line carries `+ ceiling 5` when a map plans more.
- **Ticket states** are read through `clerk-haiku-medium` where it is installed.
- **The stop report** marks the sessions whose repository has no launch left as safe to close.
- `watch.ps1` takes `-Sessions <name>:<seq>,…` and `watch.sh` takes `<name>:<seq> …`; the earlier
  `-Agent`/`-AfterSeq` and positional forms are gone.

### Fixed

- **A merge subject carries the ticket as `#<n>`**, on a local tracker too. `/orchestrate`'s
  reconcile grep matches that form, and a sandbox run showed one orchestrator writing
  `merge ticket 02 …` instead, which the grep would not have found.
- **`tests/check-docs.ps1` also checks agent frontmatter.** A plain YAML value holding a colon
  followed by a space fails to parse, and the host then registers no agent for that file, silently.
  Two descriptions written for this change had one, and the test run caught it.

### Added

- **`scout-haiku-medium`** — the locate scout, on the narrow tier (Luna on Codex).
- **`clerk-haiku-medium`** — runs a gate command and condenses its output, reads the tracker into a
  table, drafts a closing comment or log entry from facts the brief supplies, copies a spec body into
  its mirror. It decides, posts and commits nothing; the orchestrator judges and posts.
- **The advisor as a host capability** in the `Hosts` table: a Claude Code session below Fable may
  set Fable as its advisor, and its sub-agents inherit it. No step depends on it.
- `GLOSSARY.md`: *High-consequence ticket*, *Session floor*, *Narrow tier*, *Clerk*.
- This file.

### Removed

- **`executor-fable-medium`** — a fully specified high-consequence ticket runs on Opus.
- **`scout-sonnet-medium`** — replaced by `scout-haiku-medium`, the same job on the narrow tier.

Both are on the installers' retired list, so a copy left by an earlier install is removed.

### Unchanged

The three executor tiers and their labels, Opus as the default tier for judgment, the rule that
Fable is never a scout, the Codex mapping of the three executor tiers, and worktree teardown, which
stays with the orchestrator or `executor-sonnet-medium` and is never a clerk chore.

### Sources

Host facts were read from the Claude Code documentation on 2026-11-10: the advisor tool and its
pairing rules, sub-agent frontmatter (`disallowedTools`, `effort`), sub-agent nesting, and the model
and effort precedence.

### Tested

On 2026-11-10, before the merge, against three throwaway repositories with one paired run on a local
tracker, under herdr with Claude Code: `/orchestrate + check`, `/conduct + check`, `/conduct`,
`/conduct + watch` through to the close of all three repositories, and one `/orchestrate` run on an
Opus session whose high-consequence ticket was verified by `executor-fable-high`. Not exercised: Codex,
a remote tracker, a runtime walk, a hand-back to `xhigh`, an account without Fable, and a session
that sits `idle` at the pause line — herdr kept reporting `working` while executors ran.
