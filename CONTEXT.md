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

**Fable tier**:
The highest executor tier, for work whose failure is irreversible, run-wide, or adversarial. It is
independent of reasoning effort and of which Fable generation the host currently serves.
_Avoid_: Fable model, xhigh tier, Fable 5.1 tier

**Promotion**:
Moving what already landed on the integration branch to a staging or production branch. It is one
act per release, distinct from the per-wave merge an orchestration run performs.
_Avoid_: Deploy, release, merge to main

**Pivot branch**:
The short-lived branch cut from the promotion target that absorbs the merge locally, so the target
is never where a conflict is resolved and the request reaching it is already gated. It is deleted
once merged.
_Avoid_: Release branch, integration branch

**Promotion contract**:
What a repository states about how a change reaches a target branch — the branches, the gate, the
shape of the promotion, and who may merge. It is read per repository, never carried over from
another one.
_Avoid_: Branch strategy, git flow
