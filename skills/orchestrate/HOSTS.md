# Hosts without subagent dispatch

Where the host has no subagent tool — a Codex CLI too old to expose `spawn_agent`, a Codex
configuration with agents disabled, or another agent CLI — everything in [SKILL.md](SKILL.md) holds except the fan-out:
the session **is** the executor, one ticket at a time, in the ticket's own worktree, and the walker
too; the installed agent definitions are read as role briefs rather than dispatched. The in-flight
ceiling is then 1, so a wave is executed serially in wave order. Verification does not become optional
because the same session did the work — read the diff, run the gate, walk the runtime by the walk
brief's own rules, and say in the report that executor, walker and verifier were the same context.

Where the host does dispatch but its sub-agents share the parent's working directory (Codex), every
executor brief names the worktree's absolute path and tells the executor to work only there; the
worktree sits inside the repository (`.codex/worktrees/…` on Codex) precisely so a workspace-scoped
sandbox can write to it.
