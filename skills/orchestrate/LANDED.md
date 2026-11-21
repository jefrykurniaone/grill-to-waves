# `+ landed` — where the run landed

The run ended at its close point, a review request from the integration branch. Someone merged it,
and the base's pipeline deployed the base to a shared environment. `+ landed` checks that landing:
the merge, every job that ran on it — the quality analysis that runs only after a merge among them —
and the deployed app, walked. It records what it found on the map, and files what failed. It writes
nothing to the working copy and the code, so it takes no claim and runs no tree preflight.

## Steps

1. **Resolve the tracker** as [SKILL.md](SKILL.md) Stage 0 does, and read the map: its review
   request, `Run closes at:`, the runtime checks it pins to the close, and its specs' `runtime:`
   criteria. Done when the review request is named by its number.

2. **The merge.** The review request's merged state on the forge, and the commit it merged as on
   `origin/<base>` (`gh pr view <n> --json state,mergeCommit`, `glab mr view <n> -F json` for
   `state` and `merge_commit_sha` or `squash_commit_sha`). Not merged yet: say so and stop; there is
   nothing to check.

3. **The pipeline on that commit.** Every job by name with its status: build, deploy, and every
   quality or security job (SonarQube, Semgrep, Trivy and the like). A job still running is a wait:
   say which and stop. A job allowed to fail counts too: a failed one is a finding even where the
   pipeline is green.

4. **The analysis behind a failed quality job.** Read its result through the service's API with a
   read-only token from the session's environment — for SonarQube, `SONAR_TOKEN`, the host from the
   repository's `sonar-project.properties` or CI config — or, without one, from the job's log on the
   forge, and say which. List each failed condition and each new issue with its rule, file and line,
   and attribute each to this run's code or not: the run's merge commit holds the change on that line
   (`git blame <merge commit> -- <file>`), or it does not.

5. **Walk the deployed app.** Dispatch the walker as [SKILL.md](SKILL.md) *The runtime walk* says,
   against the environment the base deploys to — its address from the repository's steering file,
   runbook or deploy values — with the map's runtime checks pinned to the close and every
   `runtime:` criterion its specs carry. The walk signs in with the environment's own test account,
   never a production one. Judge its table as that section says. Done when every criterion carries a
   measured value or a named failure.

6. **File and record.** A failure attributed to this run's code — a red job, a quality issue, a
   failed walk row — is filed as its own item under the run label, for a follow-up run or the
   owner's waiver. Everything else is filed as a finding outside the run's scope, without the run
   label. Then post one `landed:` entry on the map's log: the merge commit, every job with its
   status, the analysis result with each issue's attribution, the walk's table with its screenshots,
   and the items filed. A map still open because its close point is *merged* closes now, as
   [SKILL.md](SKILL.md) *Closing upward* step 8 says.

7. **Report** the same facts in a few lines, the items filed with their numbers, and end on the
   outcome line: `orchestrate: done` when nothing failed, `orchestrate: stopped — <what failed>`
   otherwise.
