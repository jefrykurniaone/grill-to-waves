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
The top executor tier for work whose failure is irreversible, run-wide, or adversarial. A host maps
this tier to its own top-capability model.
_Avoid_: xhigh tier, Fable model
