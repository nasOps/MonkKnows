# Branching Strategy

**Written by:** Andreas, Nima & Sofie
**Updated:** February 23, 2026

---

## Exam Requirement

- Pick a workflow and branching strategy
- Pros and cons of the workflow and branching strategy
- Revise the document with new insights during the course

---

## What version control strategy did you choose and how did you actually do it / enforce it?

We use a customized GitHub Flow with a `development` layer:

```
main (production, always deployable)
  └── development (integration/staging)
        └── feature branches (created from GitHub issues)
```

The strategy is not a 1:1 copy of either GitHub Flow or Git Flow - it is tailored to our team size (3 people) and the project's needs.

### Branch hierarchy

**`main`** is always stable and deployable. No direct pushes are allowed. PRs require at least 1 approval and CI (RuboCop + RSpec) must pass before merge.

**`development`** serves as the integration branch where features are collected before going to main. PRs are required but no approval is needed - CI must still pass. It functions as staging.

**Feature branches** are created directly from GitHub issues via the "Create a branch" button. Naming is automatic: `<issue-nr>-<issue-title>`, e.g. `42-devops-set-up-ci-pipeline`. Branches are short-lived and deleted after merge.

### Naming convention

We do NOT use `feature/`, `bugfix/` or similar prefixes. The issue number in the branch name automatically provides traceability to the GitHub issue, and issue labels (`devops`, `bug`, `feature`, `rewrite`) replace the need for prefixes. With three team members and short-lived branches, there is no need to visually filter branches.

Examples of actual branch names: `28-user-model`, `42-devops-set-up-ci-pipeline`, `35-rewrite-login-register`.

### Merge strategy

We use squash merge for all PRs. All commits in a feature branch are condensed into a single commit upon merge. This provides a clean and readable Git history where each commit on main corresponds to one issue. Detailed commit history from the feature branch is lost, but a clean history is more valuable than granularity for a team of three.

### Branch protection rules (enforcement)

The strategy is enforced via GitHub branch protection rules:

**`main`:** Require PR before merge, 1 required approval, CI status check (`build-test`) required, force pushes blocked, deletion not allowed.

**`development`:** Require PR before merge, 0 required approvals, CI status check (`build-test`) required, force pushes blocked.

The difference in approval requirements is intentional: development should not be a bottleneck in daily work, while main is stricter because it represents production.

### Workflow (step by step)

1. Create issue on GitHub with relevant template and labels
2. Create branch from the issue (GitHub's "Create a branch" feature)
3. Work on the branch, commit regularly
4. Create PR to `development` when ready
5. CI runs automatically (RuboCop + RSpec)
6. Squash merge to development
7. When development is stable: PR from development to main
8. 1 approval + CI green → squash merge to main
9. Feature branch is deleted after merge

---

## Why did your group choose the one you did? Why did you not choose others?

### Why this strategy?

We are a team of three migrating a Flask application to Ruby/Sinatra. We needed something simple enough that we don't spend time on branch management, but structured enough that main is always stable. GitHub Flow with a development layer strikes that balance.

Branch names are generated automatically from GitHub issues, which provides traceability without extra conventions to remember. CI on all PRs ensures that no broken code reaches development or main.

### Why not Git Flow?

Git Flow uses `develop`, `release`, `hotfix` and `feature` branches with strict rules. It is designed for teams with formal release cycles and many parallel features.

We rejected it because we are three people, we have no formal releases (continuous deployment), and Git Flow would add overhead without benefit. Extra branch types like `release` and `hotfix` don't make sense when the team is small enough to coordinate directly.

### Why not a dedicated test branch?

We considered a separate branch solely for test runs. It was rejected because CI already runs automatically on all PRs to both development and main. A test branch would run the same tests a third time without catching anything new - it adds wait time and an extra manual step without added value. It would only make sense if we had heavy integration tests that shouldn't run on every PR, and we don't.

### Why not classic prefixes (feature/, bugfix/)?

Classic GitHub Flow typically uses `feature/`, `bugfix/` etc. as prefixes. We rejected this because GitHub's automatic branch names from issues already include the issue number, and labels on issues provide the same categorization as prefixes. Prefixes would be redundant information - traceability via issue number is stronger than traceability via prefix.

---

## What advantages and disadvantages did you run into during the course?

*(Updated continuously throughout the course)*

### Advantages experienced in practice

- CI as a gate on all PRs caught errors before they reached development or main. This gave us confidence that merged code was at least linted and tested, without relying on manual checks.
- The approval requirement on main has not been a bottleneck. With three people the turnaround on reviews is fast enough that it doesn't slow us down.
- Automatic branch names from issues made it easy to trace which branch belonged to which task without any extra effort.

### Disadvantages experienced in practice

- Merge conflicts were a recurring problem, particularly with .gitignore files and SQLite database files. The .gitignore conflict required us to close all active feature branches, consolidate into a single root-level .gitignore, and untrack files with `git rm --cached`. Database files are binary and cannot be merged - this was resolved by removing .db files from tracking entirely.
- Development runs far ahead of main. Because daily work merges into development and main only gets updated when development is considered stable, the gap between the two branches grows over time. This makes the eventual PR from development to main larger and harder to review, and increases the risk of unexpected issues when merging to production.

### What we would do differently next time

- Merge development into main more frequently. Smaller, more regular merges to main would reduce the gap and make each merge less risky. We could establish a cadence (e.g. weekly) or merge after each completed feature rather than waiting for multiple features to accumulate.
- Establish .gitignore and database tracking rules from day one. Both of our major merge conflict incidents could have been avoided with correct setup at the start of the project.
