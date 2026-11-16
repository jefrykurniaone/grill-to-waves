# Issue tracker

This repository's tracker is **GitHub issues**, driven through `gh` on `jefrykurniaone/grill-to-waves`.
A session that plans or orchestrates a run here uses it as recorded and does not re-detect it.

## Structure

- Specs and tickets are linked as **native sub-issues**: a ticket is a sub-issue of its spec, and a
  spec's own parent nests the same way.
- Blocking edges are **native GitHub dependencies** (`blocked_by`), not lines in a body.

## Labels

- `meta:orchestration`: an execution map item, not a ticket.
- `ready-for-agent`, `ready-for-human`, `needs-info`, `wontfix`: a ticket's state.
- `run:<slug>`: belongs to the delivery run `<slug>`.
- `spec:<slug>`: belongs to the spec `<slug>`.
- `executor:<tier>` and `effort:<level>`: the planned executor and reasoning effort.

Check `gh label list` before creating one.

## Operations

The commands for each live in `skills/grill-to-waves/TRACKERS.md`, under *GitHub (`gh`)*. Read them
there; they are not restated here.

| Operation | Where |
| --- | --- |
| Publish an item | TRACKERS.md, *GitHub*, **Publish** |
| Link as child | TRACKERS.md, *GitHub*, **Link as child** |
| Record a blocking edge | TRACKERS.md, *GitHub*, **Blocking edge** |
| Label | TRACKERS.md, *GitHub*, **Label** |
| Read the frontier | TRACKERS.md, *GitHub*, **Frontier read** |
| Comment | TRACKERS.md, *GitHub*, **Comment** |
| Deliver the run | TRACKERS.md, *GitHub*, **Deliver** |
