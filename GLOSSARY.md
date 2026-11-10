# Delivery Pipeline

This context names the concepts used to plan work and select the agents that execute it.

## Language

**Executor tier**:
The capability class selected from the consequence and reach of an incorrect implementation. It is
independent of reasoning effort.
_Avoid_: Model, effort tier

**Reasoning effort**:
The depth allocated to an executor from the exploration required and the decisions left for it to
make. It is independent of executor tier.
_Avoid_: Model tier, executor tier

**High-consequence ticket**:
A ticket whose incorrect implementation can escape the gate, the orchestrator's verification and one
hand-back, because it is irreversible, run-wide or adversarial. It gets a second verification in a
fresh context whichever tier runs it.
_Avoid_: Fable ticket, critical ticket, risky ticket

**Fable tier**:
The highest executor tier, for a high-consequence ticket that leaves a decision open to the executor.
With the design settled the same ticket runs on the frontier tier. It is independent of reasoning
effort and of which Fable generation the host currently serves.
_Avoid_: Fable model, xhigh tier, a tier named with a version number

**Session floor**:
The least capable model and effort the planning and orchestrating session is written for: the
frontier tier at `high`. A more capable session is the user's choice, never a requirement.
_Avoid_: Orchestrator model, required model

**Narrow tier**:
The tier of the two agents that run no ticket and make no decision: the locate scout and the clerk.
_Avoid_: Haiku executor, cheap tier

**Clerk**:
The narrow-tier agent that does one of the orchestrator's chores needing no judgment and returns the
result for the orchestrator to judge. It posts nothing and commits nothing.
_Avoid_: Helper, assistant, mini-executor

**Promotion**:
Moving what already landed on the integration branch to a staging or production branch. It is one
act per release, distinct from the per-wave merge an orchestration run performs.
_Avoid_: Deploy, release, merge to main

**Pivot branch**:
The short-lived branch cut from the promotion target that absorbs the merge locally, so the target
is never where a conflict is resolved and the request reaching it is already gated. It is deleted
once merged.
_Avoid_: Release branch, integration branch

**Paired run**:
One run slug delivered in several repositories, each with its own working copy, tracker, map and
orchestrator session. The lead map holds the run order across the repositories.
_Avoid_: Multi-repo run, cross-repo map

**Conductor**:
The one session that starts each repository's orchestrator of a paired run in the run order and
relays the user's decisions to them. It executes, verifies and decides nothing itself.
_Avoid_: Orchestrator, coordinator

**Promotion contract**:
What a repository states about how a change reaches a target branch — the branches, the gate, the
shape of the promotion, and who may merge. It is read per repository, never carried over from
another one.
_Avoid_: Branch strategy, git flow
