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

**Fable 5.1 tier**:
The highest executor tier, reserved for demanding long-horizon work where the Fable tier at higher
effort is known or expected to fall short. It is independent of reasoning effort.
_Avoid_: Latest tier, xhigh tier

**Fable tier**:
The executor tier for work whose failure is irreversible, run-wide, or adversarial, below the Fable
5.1 tier. It is independent of reasoning effort.
_Avoid_: Fable model, xhigh tier
