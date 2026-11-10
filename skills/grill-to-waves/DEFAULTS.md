# Orchestration defaults

The model, effort and worktree rules both skills read. It travels with the skill, so a repository
needs no per-machine setup to run the pipeline. Where a repository or a user's own memory file states
something narrower, that wins — this file is the floor, not a ceiling.

## Model and effort

- **The session that plans, orchestrates and verifies runs on the frontier tier (Opus) at `high`.**
  That is the floor every step of the pipeline is written for: a more capable session model is the
  user's choice, and no step waits on one. `/orchestrate` stays at `high`, because effort is paid on
  every turn and most of an orchestrator's turns are mechanical. `/grill-to-waves` may run at `xhigh`
  for a paired run, a run of many specs, or one that settles a seam several tickets compose.
- **Executors: three tiers, chosen by the consequence and reach of an incorrect implementation.** The
  mid tier (Sonnet) for bounded work whose decisions were all made upstream; the frontier tier (Opus)
  for judgment inside a bounded blast radius, and for high-consequence work whose design is settled;
  the Fable tier for high-consequence work that leaves a decision open. Follow the ticket's
  `executor:` label where one exists.
- **Executor reasoning effort: `medium`, `high` or `xhigh`.** Follow the ticket's `effort:` label;
  default `high` when unlabelled. Two things set the level at ticketing time — how much the executor
  must *explore* before it can edit, and how many *decisions* it makes alone. Tier and effort are
  independent: risk selects the tier; workload selects the effort.
- **Verification of executor output is the orchestrator's job**, never left to the executor that
  produced it. Executor and orchestrator may be the same model; they are never the same context, and
  the orchestrator reads the diff itself. A high-consequence ticket gets a second verification in a
  fresh context — *Verifying a high-consequence ticket*.
- **The narrow tier (Haiku) runs two agents and no ticket**: the locate scout and the clerk.

### The effort ladder

| Level | Use when | Typical pairing |
|---|---|---|
| `medium` | The target is fully specified upstream and the exploration is narrow: the files are named or trivially found, the edit is mechanical, and no decision is left to make — a rename, a dead column removed at enumerated sites, a copy change, a docs mirror, a restyle onto a settled component. | Usually Sonnet `medium`; Opus `medium` for a large decision-free sweep, or for a high-consequence operation whose design is written out in the ticket |
| `high` | **The default, and the ceiling at ticketing time.** Judgment inside a bounded scope: a new surface on an existing seam, a route or form change, a multi-file feature whose *placement* needs reading breadth, any ticket that must discover its own call sites, a ticket whose invariant or correctness argument is the executor's to derive. | Sonnet `high` when decisions were made upstream; Opus `high` for decisions inside a bounded blast radius; Fable `high` for a high-consequence ticket with a decision open |
| `xhigh` | **Earned by a hand-back, never planned.** An attempt at `high` came back wrong for a reasoning failure — an invariant derived wrongly, a case missed — rather than for a wrong premise or a missing fact. The orchestrator re-dispatches the ticket at `xhigh` on the same tier and corrects the label. | Any tier, after its own attempt at `high` |

Choose the axes separately. **Consequence and reach** select the executor tier. **Exploration need and
unresolved decision complexity** select effort: narrow and decision-free → `medium`; everything else →
`high`. High consequence never raises effort by itself; a settled design lowers the tier from Fable to
Opus, never the verification the consequence calls for. Never pick a level merely to save tokens.

`low` and `max` are not executor levels. At `low` an agent on a long task is likelier to stop early,
skip a search or skip the check of its own change, and an executor's contract is to run the gate and
prove its claims. `max` does not exist on every host, so a map planned with it would not execute
everywhere.

### High-consequence tickets and the Fable tier

A ticket is **high-consequence** when an incorrect implementation can escape the net the pipeline
otherwise relies on — the gate, the orchestrator's verification, one hand-back. One of three clauses
makes it so:

- **Irreversible once landed.** A data migration or backfill, a rewrite of stored values, a destructive
  schema change — anything a reset of the branch does not undo because it ran against data.
- **Run-wide.** A seam, contract, type or stored enum that several specs or later waves compose. A wrong
  call is rebuilt by every downstream ticket, and the gate passes on each of them.
- **Adversarial.** A security boundary (authentication, authorisation, tenancy, secrets) or a
  concurrency argument (a race, a lock order, an idempotency key) that the test suite cannot prove and
  a reviewer must reason about.

Its tier follows from what the ticket leaves open:

- **A decision is open** — the invariant, the migration or security strategy, or the correctness
  argument is the executor's to derive: `executor:fable`.
- **The design is settled** — the migration is written out, the contract fixed, the lock order named,
  and the executor implements it: `executor:opus`, at the effort its workload calls for.

Everything else that is judgment-heavy is Opus and carries no clause: a money rule inside one module,
a stored enum consumed inside one spec, a lock on one table, an additive migration the gate proves.
Exploration breadth alone never earns Fable — a large sweep is Opus at most.

Rules that follow:

- **Name every high-consequence ticket in the map**, whichever tier runs it, with the clause that
  makes it one. A wave normally holds one or two at most; a run where most tickets are
  high-consequence has been split too coarsely, or its specs have left their decisions to the
  executors.
- **High-consequence tickets sit early.** They are usually the seam others build on, so they belong
  in the wave that blocks the tickets composing them, never after those tickets.
- **Fallback.** Where the matching `executor-fable-<effort>` is missing or the Fable model is not
  available on the account, dispatch `executor-opus-<effort>` with the same brief, keep both labels,
  and record the substitution in the ticket's closing comment and the wave report.
- **Fable is never a scout.** Locating and sweeping are breadth, not judgment.

### Verifying a high-consequence ticket

Before its branch merges, a high-consequence ticket gets one verification in a fresh context, besides
the orchestrator's own reading of the diff. The brief writes nothing and carries the ticket, the diff
and the invariant to check:

- **Fable available**: `executor-fable-high`. A session that itself runs on Fable is this
  verification, and dispatches nothing.
- **Fable unavailable**: `scout-opus-high`.
- **The ticket is irreversible and Fable did not verify it**: stop before the push and get the
  user's go-ahead, naming the ticket and what a reset of the branch will not undo.

Record which of these ran in the ticket's closing comment.

### Scouts

Read-only sub-agents (fact-finding, code location, analysis) follow the same tiering. Always name the
agent rather than inheriting the session's model:

- **Locate a known symbol or file** (one grep, one read, cite `path:line`): `scout-haiku-medium`.
- **Judge one precise claim over a narrow evidence surface** (trace one known behaviour, answer one
  focused code question): `scout-opus-medium`.
- **Sweep many locations or naming conventions** (map a directory, list every caller, find where
  something lives when the name is unknown): `scout-sonnet-high`.
- **Analyse, judge or audit across a broad or uncertain surface** (root-cause analysis, security sweep,
  reviewing a diff for defects): `scout-opus-high`.
- **Adversarially verify subtle behaviour** (prove a race, a data-loss path, a money rule): an
  `executor-fable-high` brief that writes nothing (`executor-opus-xhigh` where Fable is unavailable),
  or the orchestrator session itself.

### The clerk

`clerk-haiku-medium` takes the orchestrator's chores that need no judgment, so they cost the narrow
tier's tokens instead of the session's: running a gate command and condensing its output, reading the
tracker into a table, writing a closing comment or a log entry from facts the brief supplies, copying
a spec body into its mirror. It returns exit codes, verbatim failures and the files it wrote. The
orchestrator judges pass and fail, posts every record and makes every commit.

Give each brief one chore and only the inputs that chore needs: the narrow tier's price per token
rises on a long prompt. Worktree teardown stays with the orchestrator or goes to
`executor-sonnet-medium`, because one wrong step in it empties the main tree's dependencies.

### How effort is applied

Effort is fixed in the agent definition, never passed per call, so one dispatch means the same thing
on both hosts: Codex's `spawn_agent` selects a custom agent whose file pins `model_reasoning_effort`,
and Claude Code's `Agent` tool takes a per-call effort only in recent releases. The definitions this repo installs are `executor-fable-{high,xhigh}`
and `executor-{opus,sonnet}-{medium,high,xhigh}` (every tool but sub-agent dispatch),
`scout-haiku-medium`, `scout-sonnet-high` and `scout-opus-{medium,high}` (read-only), and
`clerk-haiku-medium` — one set per host, same names, same bodies. Dispatch the agent named
`executor-<tier>-<effort>` matching the ticket's labels. If the matching Fable agent is missing, fall
back to `executor-opus-<effort>`. If any other agent is missing, use the host's general agent with the
mapped model and effort stated in the prompt. Every substitution is said in the wave report.

### Hosts

The names in the labels (`fable`, `opus`, `sonnet`) and agent names are stable tiers, not model
generations. Claude Code agents use the host's model aliases (`fable`, `opus`, `sonnet`, `haiku`), so
each tier follows the current generation without an edit; Codex maps the three executor tiers to
Astra, Sol and Terra, and the narrow tier to Luna. The labels stay the same so a map planned on one
host executes on the other. On Codex a plan without access to a pinned model may be served a cheaper
one silently (openai/codex#46632 reports `gpt-6-astra` answered by `gpt-5.6-luna` on a Plus plan); a
Fable-tier ticket on such a plan is running one tier lower than its label says, so check the plan
before trusting the tier.

On Claude Code a per-invocation model override takes precedence over the agent file, and the agent
file over `CLAUDE_CODE_SUBAGENT_MODEL`. Two environment variables defeat the agent file instead:
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` makes every sub-agent ignore its `model` field, and
`CLAUDE_CODE_EFFORT_LEVEL` overrides every `effort` field. With either set, the tier or effort a
label names is not the one that runs.

| | Claude Code | Codex CLI |
|---|---|---|
| Session (plan, orchestrate, verify) | Opus at `high` or above | GPT-5.6 Sol (`gpt-5.6-sol`) at `high` or above |
| Fable tier (`fable`) | Fable (alias `fable`) at `high` / `xhigh` | GPT-6 Astra (`gpt-6-astra`) at the same effort |
| Frontier tier (`opus`) | Opus at `medium` / `high` / `xhigh` | GPT-5.6 Sol (`gpt-5.6-sol`) at the same effort |
| Mid tier (`sonnet`) | Sonnet at `medium` / `high` / `xhigh` | GPT-5.6 Terra (`gpt-5.6-terra`) at the same effort |
| Narrow tier (`scout-haiku-medium`, `clerk-haiku-medium`) | Haiku at `medium` | GPT-5.6 Luna (`gpt-5.6-luna`) at `medium`, the narrowly scoped work Luna is positioned for; the clerk runs `workspace-write` |
| Sonnet scout (`scout-sonnet-high`) | Sonnet at `high` | GPT-5.6 Terra (`gpt-5.6-terra`) at `high` |
| Opus scouts (`scout-opus-*`) | Opus at `medium` / `high` | GPT-5.6 Sol (`gpt-5.6-sol`) at the same effort |
| Optional vault scribe (`vault-scribe`) | Sonnet at `medium` | GPT-5.6 Luna (`gpt-5.6-luna`) at `medium`, `workspace-write`; vault writes require session permission for the target path |
| Advisor, optional | A session below Fable sets Fable as its advisor: `/advisor fable`, the `advisorModel` setting, or `claude --advisor fable`. Sub-agents inherit it, and the host checks the pairing against each one's own model | none |
| Executors dispatch no sub-agents | `disallowedTools: Agent` in the executor's frontmatter | the executor body's own instruction |
| Agent definitions | `~/.claude/agents/<name>.md` — YAML frontmatter `model`, `effort`, `tools`, `disallowedTools` | `~/.codex/agents/<name>.toml` (or `.codex/agents/` in a project) — `model`, `model_reasoning_effort`, `sandbox_mode`, `developer_instructions` |
| Dispatch | `Agent` tool with `subagent_type: <name>` | `spawn_agent` naming the custom agent; `wait_agent` to collect; `followup_task` for rework on the same executor |
| Message a running executor | `SendMessage` | `send_message` |
| In-flight ceiling | the map's (default five; more only on the user's word) | the map's, and never above `agents.max_concurrent_threads_per_session` in `~/.codex/config.toml` |
| Skill invocation | a slash command: the skill name after `/` | a skill mention: the skill name after `$` |
| Agent directory in the repo | `.claude/` — `worktrees/<row>/<ticket>` and `scratch/` under it | `.codex/` — the same two paths under it, inside the workspace so a `workspace-write` sandbox can write there |
| Required Matt Pocock skills | `grilling`, `domain-modeling` and `setup-matt-pocock-skills`, fetched by this repo's installer from the latest release of the `mattpocock/skills` GitHub repository into the project or user `.claude/skills/` directory — never the plugin, whose `mattpocock-skills:<name>` names the skill text does not use | `$grilling`, `$domain-modeling`, and `$setup-matt-pocock-skills`, fetched from the same release into the project or user `.agents/skills/` directory |
| Read-only scouts | `permissionMode: plan` in the frontmatter (Write and Edit denied by the host; a shell command outside the built-in read-only set is reviewed or prompted, never silently run) plus the tool list | by `sandbox_mode = "read-only"` |

**The advisor is a host capability, and no step depends on it.** Where it is on, an Opus or Sonnet
executor consults Fable at a decision point without the ticket moving tier, and each consultation is
billed at the advisor's rate. It is experimental on Claude Code, needs the Anthropic API rather than a
cloud provider's, is chosen by the model rather than by a rule, and cannot be set per sub-agent:
`CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` turns it off for the whole session. A consultation settles a
decision inside one ticket; it replaces neither the second verification of a high-consequence ticket
nor a re-grade.

The skill text in this repo is written in Claude Code's vocabulary; the installer rewrites the
invocation prefix and the agent directory when it installs for Codex, and nothing else. Codex
sub-agents share the parent's working directory, so an executor brief on Codex names the worktree's
absolute path and tells the executor to work only there. A Codex executor in a `workspace-write`
sandbox may have no network: when it cannot push or open the review request, the orchestrator does
both from the executor's branch, and the ticket's record says so.

## Worktree teardown — the junction trap

Applies wherever a worktree's dependency tree is a link (a Windows junction, or a symlink) to the main
tree's copy rather than its own installed copy — what `deps: shared` means in a ticket's surface block.

**The trap.** A build inside the worktree can write *further* links back into the main tree — a
Next.js/Turbopack build writes `<worktree>/.next/node_modules/` filled with junctions to the main
tree's server externals (`@prisma/client-<hash>`, `pg-<hash>` observed). A recursive delete, including
`git worktree remove --force`, follows those links and **empties the targets in the main tree**.
Unlinking only the top-level `node_modules` link is not enough; the ones under the build cache remain.
Symptoms land everywhere at once: `Cannot find module '@prisma/client'`, unrelated test files failing,
`Module not found` mid-build, a broken dev server. Some packages survive, so spot-checking one package
proves nothing.

**Teardown procedure — every time, never skipped.** Unlink every reparse point / symlink inside the
worktree **deepest first**, confirm none remain, and only then remove the worktree.

PowerShell (Windows):

```powershell
$wt = "<repo>\.claude\worktrees\<row>\<ticket>"
$links = Get-ChildItem -Path $wt -Recurse -Force -Attributes ReparsePoint |
    Sort-Object { $_.FullName.Length } -Descending
foreach ($l in $links) { (Get-Item -LiteralPath $l.FullName -Force).Delete() }
if (-not (Get-ChildItem -Path $wt -Recurse -Force -Attributes ReparsePoint)) {
    git worktree remove $wt --force
}
git branch -D <branch>
```

POSIX (macOS, Linux):

```bash
wt="<repo>/.claude/worktrees/<row>/<ticket>"
find "$wt" -depth -type l -delete
[ -z "$(find "$wt" -type l -print -quit)" ] && git worktree remove "$wt" --force
git branch -D <branch>
```

`.Delete()` on the `DirectoryInfo` unlinks without following the link, which is the whole point;
`Remove-Item -Recurse` and `rm -rf` do follow. Clear a build cache with
`[System.IO.Directory]::Delete((Resolve-Path .next).Path, $true)` on Windows.

**Repair if it already happened:** reinstall in the **main** tree and re-run the code generator
(`npm install`, whose `postinstall` usually covers it), then restart any dev server that was running
while the gutting happened.

**Executor briefs must say:** never run an install or a code generator inside a `deps: shared`
worktree — a generator that writes into the shared dependency tree clears it first, emptying it for
every tree at once. A ticket that changes the schema or a dependency gets `deps: own`: a full copy of
the dependency tree, never the link.

## Verification gate before each completion gate

Before judging the main tree green, confirm the generated database client (Prisma or equivalent) is
present where the repo has one. Missing → repair it before anything else, because every downstream
failure it causes is misattributed.
