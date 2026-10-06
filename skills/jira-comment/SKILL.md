---
name: jira-comment
description: "Draft the Jira comment for a ticket whose fix has moved: request opened, deployed, or promoted. State, cause and fix, retest steps, what was verified and where, ready to paste."
argument-hint: "[TICKET-KEY ...]"
disable-model-invocation: true
---

# Jira comment

The comment is read on the ticket by testers, analysts and a project manager: people who have the
tracker and the deployed environments, and nothing of this machine. It tells them what state the fix
is in, how to retest it, and what was and was not verified. **The session drafts; the user pastes.**
Nothing here posts to Jira.

This skill sits beside the plan → execute → promote pipeline. It follows whatever moved the ticket:
an `/orchestrate` run that ended in a request, a `/ship-it-to` promotion, or a fix made by hand.

## Steps

1. **Resolve the tickets.** The arguments, or the keys in the branch name, the commit subjects and
   the request title. One comment per ticket asked for; a ticket that only travels in the same
   request is named inside that comment.

2. **Read the event from the forge**: what has happened to the change since the last comment. The
   request and its state, the commit it landed as, that commit's pipeline job by job, and the
   address of the environment it deploys to. Done when a row of *Events* is chosen and each of its
   facts carries where it was read.

3. **Verify the state word** the lead line will carry, by *State words are claims*.

4. **Collect what the comment reports**: cause and fix from the request's description and the
   commits; the retest path from the acceptance criteria or the walk that verified the fix; what
   was checked, on which environment; the gate's result from this session's run or the pipeline.

5. **Settle the language**, by *Language*, and draft each comment from the template.

6. **Print each draft in its own fenced block**, ready to copy. Where the work has a local tracker
   directory (`.scratch/<run>/`), save each beside it as `jira-comment-<event>-<language>.md`. A
   draft file already there stays as it is, because it may have been pasted: a later comment gets
   a file of its own.

## Events

| Event | The lead line says | The body carries |
|---|---|---|
| Request opened | **fixed**, with the request and its reviewer | Cause, Fix, Also fixed, Not done, Retest, the gate |
| Merged and deployed | **on `<env>`, ready for retest**, with the environment's address | Retest on that environment, Checked, Not checked, the gate |
| Promotion request opened | where the fix runs now, with the promotion request | Also carries, Checked, Not checked |

Several events since the last comment make one comment, in the table's order. A later comment
reports its events only: cause and fix are said once, in the first. When no first comment was
drafted, tell the user and offer to fold both into one.

## State words are claims

- **fixed**: the request is open and its gate ran green, in this session or in its pipeline.
- **merged**: the forge reports it merged. Name the commit.
- **deployed**, **ready for retest**: the pipeline of the merge commit has *finished* green, its
  deploy job included, and where the environment is reachable from this machine, the page was
  loaded and shows the fix. An environment serves the previous build until that pipeline ends, so a
  comment written in the minutes after a merge sends the tester to the old build and the ticket
  comes back as "not fixed".
- **checked on `<env>`**: what was exercised there, and nothing wider.

A state that cannot be verified is written as what is known: "merged; the deploy job was still
running at 14:10".

## Rules

- **Shared identifiers only**: ticket keys, request numbers with their links, short commit shas,
  pipeline numbers, environment addresses. What exists only on this machine stays here: file paths,
  local ticket and wave numbers, script names, agent and model names.
- **Retest is the shortest path with its expected result**: where to open, what to choose, what
  must be seen, and whether an account or data is needed. Screen labels are written exactly as the
  screen shows them.
- **Checked and Not checked name their environment.** What could not be verified is listed with its
  reason in a few words.
- **Name what else travels.** Other tickets in the same request or promotion, by key.
- **A note for testers is for a trap**: data a retest leaves behind on a shared environment, a rate
  limit, a prerequisite account. No trap, no note.
- **One screen.** A bold label and one sentence, or bullets of one line each; 10 to 20 lines in
  all. The gate is the last line.
- **Numbers are measured.** A suite or test count comes from this session's run or the pipeline's
  log, or it is left out.

## Language

- **English** by default.
- **When the ticket's own description is in another language, two drafts**: that language first,
  English second.
- **The other-language draft is mixed, the way the team's developers write**: its sentences in that
  language, standard development terms in English. In Indonesian: "siap di-retest", "sudah
  ter-deploy", "pipeline success", "fix validation message", "step 1", "viewport", "tester",
  "dummy data", "shared environment", "build pass". "Siap di-retest" over "siap diuji ulang": a
  draft translated term by term reads as written by nobody on the team.
- **When the ticket's language is not known**, print the English draft and ask for it in one line.

## Template

```
**<KEY>: <state>.** <the request or the environment, with its link> (<reviewer, or pipeline result>)

**Cause:** <one sentence>

**Fix:** <one sentence>

**Also fixed:**
- <one line each>

**Not done:** <what was left out, and what it waits on>

**Retest on <env>:** <where to open and what to choose>: <what must be seen>. <Account needed or not.>

**Checked:**
- On <env>: <what was exercised>

**Note for testers:** <the trap>

**Not checked:** <what, and until when or why>

<Type check, tests and build: result.> <Pipeline: result.>
```

Keep the labels the event's row names and drop the rest; a label with nothing true under it is
dropped too. A promotion's comment says **Also carries** where the first says **Also fixed**.

## Example

The first comment, for a ticket written in English:

```
**SHOP-412: fixed.** MR to `dev`: !57, https://git.example.com/shop/storefront/-/merge_requests/57 (reviewer: dina)

**Cause:** the progress bar drew 6 steps from an old constant, while checkout walks 4.

**Fix:** the progress bar shows 4 steps for Card and Bank transfer, 3 for Cash on delivery.

**Also fixed:**
- The promo code field keeps its value when the buyer goes back a step.
- At 390 px the order summary no longer overlaps the pay button.

**Not done:** refusing an expired promo code on step 1 (needs a backend change).

**Retest:** open Checkout with any item in the cart and choose Card: 4 steps, "Step 1 of 4". Cash on delivery: 3 steps. No account is needed.

Type check, tests and build pass; the MR pipeline succeeded.
```

The follow-up after the merge, deploy and promotion request, for a ticket written in Indonesian
(its English twin follows it in the same reply):

```
**SHOP-412: sudah di `dev`, siap di-retest.** MR !57 sudah di-merge (`4c1e9ab`) dan sudah ter-deploy di https://shop-dev.example.com (pipeline #903 success).

**Promote ke `stg`:** MR !58, https://git.example.com/shop/storefront/-/merge_requests/58 (belum di-merge). MR ini juga membawa SHOP-398 dan SHOP-405.

**Retest di dev:** buka Checkout dengan satu item di cart, pilih Card: 4 step, "Step 1 of 4". Cash on delivery: 3 step. Tidak perlu akun.

**Sudah dicek setelah merge:**
- Di URL dev: progress bar di viewport 1920, 768 dan 390 px.
- Di local stack: 3 order sampai success screen, promo code, dan tampilan mobile 390 px.

**Catatan untuk tester:** order dengan dummy data jangan di-submit di shared environment.

**Belum dicek:** staging, sampai !58 di-merge dan pipeline-nya selesai.

Typecheck, test (88 suite, 1204 test) dan build pass di `4c1e9ab`.
```
