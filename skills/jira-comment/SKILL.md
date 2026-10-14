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

5. **Settle the language**, by *Language*, and draft each comment from the template, in *Jira
   markup*.

6. **Print each draft in its own fenced block**, ready to copy, and under the drafts one line: paste
   into the **Text** tab of the comment box, flip to **Visual** to check, then Add. Where the work
   has a local tracker directory (`.scratch/<run>/`), save each beside it as
   `jira-comment-<event>-<language>.txt`. A draft file already there stays as it is, because it may
   have been pasted: a later comment gets a file of its own.

## Events

| Event | The lead line says | The second line links | The body carries |
|---|---|---|---|
| Request opened | **fixed** | the request: target branch, reviewer, pipeline | Cause, Fix, Also fixed, Not done, Retest, the gate |
| Merged and deployed | **on `<env>`, ready for retest** | the request, its merge commit, the environment's address, the pipeline | Retest on that environment, Checked, Not checked, the gate |
| Promotion request opened | where the fix runs now | the promotion request | Also carries, Checked, Not checked |

Several events since the last comment make one comment, in the table's order: the first event takes
the lead and second lines, each later one a labelled paragraph. A later comment reports its events
only: cause and fix are said once, in the first. When no first comment was drafted, tell the user
and offer to fold both into one.

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
- **Retest is numbered steps ending on what must be seen**: where to open, what to choose, what
  must be seen, and on the label line whether an account or data is needed. Screen labels are
  written in double quotes, exactly as the screen shows them.
- **A list is a list.** A fix that lands in several places, several checks, several retest paths:
  one bullet or step each, never a sentence of commas.
- **Checked and Not checked name their environment.** What could not be verified is listed with its
  reason in a few words.
- **Name what else travels.** Other tickets in the same request or promotion, by key.
- **A note for testers is for a trap**: data a retest leaves behind on a shared environment, a rate
  limit, a prerequisite account. No trap, no note.
- **One screen.** A label and one sentence, or a label and bullets of one line each; 10 to 20 lines
  in all. The gate is the last line.
- **Numbers are measured.** A suite or test count comes from this session's run or the pipeline's
  log, or it is left out.

## Jira markup

The draft is Jira wiki markup, the notation the comment box's **Text** tab holds in Jira Server and
Data Center. It is pasted into the Text tab; the **Visual** tab is where the result is checked.
Markdown is not Jira markup: pasted into Visual, `**x**` and backticks stay as literal characters.

- `*bold*` for the lead line and each label; `_italic_` for the gate line.
- `{{monospace}}` for branches, commit shas and code identifiers.
- `[label|url]` for every link, `[url]` for a bare address. A request reference lives in its link's
  label: `[MR !57|url]`.
- `* ` for bullets, `# ` for numbered steps, each item on its own line starting with its marker.
- Lines of one paragraph render as separate lines; a blank line starts a new paragraph.

Jira reads these as markup wherever they stand, so in prose they appear only as markup:

- `!` pairs embed an image: a `!` stands only in a link label, one per line.
- `[ ]` open a link, `{ }` a macro, `|` at the start of a line a table.
- `*`, `_`, `-`, `+`, `^`, `~` around a word make it bold, italic, struck, underlined, superscript,
  subscript.
- `#`, `*`, `-` or `h1.` to `h6.` opening a line make a list item or a heading: a line opens with
  its words, as in `pipeline #903`.
- `(i)`, `(x)`, `(y)`, `(n)`, `(/)`, `(!)`, `(?)`, `(+)`, `(-)`, `(on)`, `(off)`, `:)`, `:D`, `:P`
  become icons.

A character that must appear literally takes a backslash: `\{`, `\[`.

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
*<KEY>: <state>.*
[<MR !n>|<url>] <target branch or merge commit>, <reviewer or environment address>, <pipeline result>.

*Cause:* <one sentence>

*Fix:* <one sentence>
* <each place it lands, when there are several>

*Also fixed:*
* <one line each>

*Not done:* <what was left out, and what it waits on>

*Retest on <env>:* <account or data needed, or none>
# <where to open>
# <what to choose>: <what must be seen>

*Checked:*
* On <env>: <what was exercised>

*Note for testers:* <the trap>

*Not checked:* <what, and until when or why>

_<Type check, tests and build: result.>_
```

Keep the labels the event's row names and drop the rest; a label with nothing true under it is
dropped too. A promotion's comment says **Also carries** where the first says **Also fixed**.

## Example

The first comment, for a ticket written in English:

```
*SHOP-412: fixed.*
[MR !57|https://git.example.com/shop/storefront/-/merge_requests/57] to {{dev}}, reviewer: dina, not merged yet. Pipeline success.

*Cause:* the progress bar drew 6 steps from an old constant, while checkout walks 4.

*Fix:* the progress bar shows the steps the payment method walks:
* Card and Bank transfer: 4 steps
* Cash on delivery: 3 steps

*Also fixed:*
* The promo code field keeps its value when the buyer goes back a step.
* At 390 px the order summary no longer overlaps the pay button.

*Not done:* refusing an expired promo code on step 1 (needs a backend change).

*Retest:* no account needed.
# Open Checkout with any item in the cart.
# Choose Card: 4 steps, "Step 1 of 4".
# Choose Cash on delivery: 3 steps.

_Type check, tests and build pass._
```

The follow-up after the merge, deploy and promotion request, for a ticket written in Indonesian
(its English twin follows it in the same reply):

```
*SHOP-412: sudah di {{dev}}, siap di-retest.*
[MR !57|https://git.example.com/shop/storefront/-/merge_requests/57] sudah di-merge ({{4c1e9ab}}) dan ter-deploy di [https://shop-dev.example.com], pipeline #903 success.

*Promote ke {{stg}}:*
[MR !58|https://git.example.com/shop/storefront/-/merge_requests/58], belum di-merge. Ikut terbawa: SHOP-398, SHOP-405.

*Retest di dev:* tidak perlu akun.
# Buka Checkout dengan satu item di cart.
# Pilih Card: 4 step, "Step 1 of 4".
# Pilih Cash on delivery: 3 step.

*Sudah dicek:*
* Di dev: progress bar di viewport 1920, 768 dan 390 px.
* Di local stack: 3 order sampai success screen, promo code, tampilan mobile 390 px.

*Catatan untuk tester:* jangan submit order dengan dummy data di shared environment.

*Belum dicek:* staging, sampai MR promote di-merge dan pipeline-nya selesai.

_Typecheck, test (88 suite, 1204 test) dan build pass di {{4c1e9ab}}._
```
