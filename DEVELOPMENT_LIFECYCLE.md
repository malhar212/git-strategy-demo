# Development Lifecycle

This document walks through the complete development lifecycle from picking up a ticket to shipping it to production.

> For the full command reference, see [WORKFLOW_COMMANDS.md](WORKFLOW_COMMANDS.md).
> For repository setup (branch protection, GitHub Actions permissions), see [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md).

---

## The Big Picture

```
feature/CU-xxx-desc ──(merge --no-ff)──► release/CU-xxx-desc ──(PR --no-ff)──► staging ──(PR --squash [bump])──► main
               │                               ▲                                                                   │
               ╰──(sync-feature --no-ff)───────╯                                                                   │
                                                                                            [auto-tag vX.Y.Z]      │
                                                                                            [auto-delete branch]   │
                                                                                            [auto-sync staging]    │
```

---

## Step 1: Start a Feature Branch

You've been assigned CU-86b62v077. Create a feature branch from `main`:

```bash
pnpm run git:feature 86b62v077 add-user-auth
```

This creates `feature/CU-86b62v077-add-user-auth` from the latest `main`. The `CU-` prefix is added automatically — you only provide the alphanumeric task ID.

**What's enforced:**
- Branch name must follow the `feature/CU-{task_id}-description` pattern (validated by the `pre-push` hook).
- You cannot push a feature branch directly to `main` or `staging` (blocked by `pre-push` hook and `branch-enforcement.yml`).

---

## Step 2: Develop and Commit

Work on your feature. Commit freely — **no commit format is enforced on feature branches**:

```bash
git add src/auth.js
git commit -m "add login form"

git add src/auth.js src/validation.js
git commit -m "wip password validation"
```

Conventional commit format (`type(scope): description`) is recommended but not required on feature branches. The release branch mirrors your feature commits via `--no-ff` merge, and everything gets squashed into a single clean commit only when the PR to main is merged.

**What's enforced:**
- Nothing on feature branches! Commit messages are only validated on `release/*`, `hotfix/*`, and `main` branches (via Husky `commit-msg` hook + commitlint).

---

## Step 3: Stay in Sync with Main

While developing, regularly pull in changes from `main` to avoid large merge conflicts later:

```bash
pnpm run git:sync
```

This runs `git merge origin/main --no-ff` into your feature branch. If there are conflicts, resolve them and commit.

---

## Step 4: Create a Release Branch

Feature is done. Time to package it for UAT. From your feature branch:

```bash
pnpm run git:release
```

This:
1. Creates `release/CU-86b62v077-add-user-auth` from `main` (name derived from your feature branch).
2. Merges your feature branch into the release with `--no-ff`.

The release branch mirrors your feature — it has all the same commits. That's fine because the squash happens later (when the PR to main is squash-merged).

### Step 4b: UAT Finds Bugs? Fix in Feature, Sync to Release

```bash
# Fix in feature branch
git checkout feature/CU-86b62v077-add-user-auth
# make fixes...
git commit -m "fix validation issue from UAT"

# Sync release with the fix
git checkout release/CU-86b62v077-add-user-auth
pnpm run git:sync-feature
git push
```

Since we use `--no-ff` merges, git tracks what's already been merged. Running `git:sync-feature` again only picks up new commits — no duplicates, no conflicts with your own code.

---

## Step 5: PR to Staging (UAT)

Push the release branch and create a PR to `staging`:

```bash
pnpm run git:to-staging
```

This pushes the branch and creates a PR via the `gh` CLI. If `gh` isn't available, it prints manual instructions.

**What happens on GitHub:**
- The `branch-enforcement.yml` workflow validates that only `release/*` or `hotfix/*` branches can PR to `staging`.
- The PR should be merged with a **merge commit** (`--no-ff`), preserving history.

**Now:** Get the PR reviewed, then merge it on GitHub. Run UAT on staging.

---

## Step 6: Ship to Main (Production)

UAT passed. Ship it with a semver bump type:

```bash
pnpm run git:ship minor    # or: major, patch
```

This:
1. Verifies your staging PR was merged (prompts to skip if not found — only checked for release branches, not hotfix).
2. Pushes the release branch to origin.
3. Creates a PR to `main` with `[minor]` prefix in the title (for auto-versioning).

**What happens on GitHub:**
- The `branch-enforcement.yml` workflow validates the branch is allowed to PR to main.
- The `fix-pr-target.yml` workflow checks if the release branch was merged to staging first and comments a reminder if not (release branches only).
- The PR title includes the `[minor]` (or `[major]`/`[patch]`) prefix for auto-versioning.
- The PR should be **squash merged** (clean single commit on main).

**Now:** Get the PR reviewed, then **squash merge** it on GitHub.

---

## Step 7: Everything After Merge is Automatic

Once the PR to `main` is squash-merged, the following happens automatically via GitHub Actions:

| What | How | Workflow |
|------|-----|----------|
| **Version computed** | `[minor]` in PR title + latest tag → next version | `auto-tag-release.yml` |
| **Tag created** | `vX.Y.Z` annotated tag pushed | `auto-tag-release.yml` |
| **Release/hotfix branch deleted** | Remote branch cleaned up | `auto-tag-release.yml` |
| **Staging synced** | `main` merged into `staging` with `--no-ff` | `sync-staging.yml` |

You don't need to manually compute versions, tag, delete branches, or sync staging.

**Local cleanup** (optional):

```bash
git checkout main && git pull
git branch -d release/CU-86b62v077-add-user-auth
git branch -d feature/CU-86b62v077-add-user-auth
```

---

## Hotfix Workflow

For critical production bugs that can't wait for a full release cycle:

```bash
# 1. Create hotfix branch from main (task ID required, CU- auto-added)
pnpm run git:hotfix 86b62v077 critical-payment-bug

# 2. Fix and commit directly (conventional commits enforced on hotfix)
git add src/payment.js
git commit -m "fix(CU-86b62v077): prevent negative payment amounts"

# 3. Option A: Go through staging first
pnpm run git:to-staging
# get PR reviewed and merged on GitHub...
pnpm run git:ship patch

# 3. Option B: Skip staging (urgent)
pnpm run git:ship patch
# Answer "y" when prompted to skip staging check
```

Hotfix branches allow direct commits (unlike release branches which get their commits via merge from a feature branch). They skip the release step and PR directly to `staging` and/or `main`. The same `[major|minor|patch]` auto-tagging applies when the PR to main is squash-merged.

---

## What's Enforced and Where

| Rule | Local (Husky) | GitHub Actions | When |
|------|---------------|----------------|------|
| Branch naming (`CU-{task_id}-desc`) | `pre-push` **BLOCKS** | `branch-enforcement.yml` | Push / PR |
| No direct push to main/staging | `pre-push` **BLOCKS** | Branch protection | Push |
| Only release/hotfix → main/staging | `pre-merge-commit` **BLOCKS** | `branch-enforcement.yml` **BLOCKS** | Merge / PR |
| Conventional commits | `commit-msg` **BLOCKS** | `validate-commits.yml` | Commit / PR |
| `[major\|minor\|patch]` in PR title | — | `validate-pr-title.yml` | PR to main |
| Squash merge to main | — | Merge settings | PR merge |
| Staging PR reminder | — | `fix-pr-target.yml` | PR to main (release only) |
| Auto-version + tag | — | `auto-tag-release.yml` | PR merged to main |
| Auto-sync staging | — | `sync-staging.yml` | Push to main |
| Stale branch cleanup | — | `cleanup-stale-branches.yml` | Weekly (Sunday) |

---

## Merge Strategy at Each Step

| Transition | Method | Why |
|------------|--------|-----|
| main → feature (sync) | `--no-ff` | Preserve sync points in history |
| feature → release | `--no-ff` | Mirror feature work, git tracks merge state |
| feature → release (sync) | `--no-ff` | Bring in new fixes, no duplicates |
| release → staging | `--no-ff` (PR merge commit) | Preserve release identity in staging history |
| release → main | `--squash` (PR squash merge) | **Only place we squash** — clean main history |
| hotfix → staging | `--no-ff` (PR merge commit) | Preserve hotfix identity in staging |
| hotfix → main | `--squash` (PR squash merge) | Clean main history |
| main → staging (auto-sync) | `--no-ff` | Keep staging in sync without rewriting history |

> **Philosophy:** Use `--no-ff` everywhere. Squash **only** when merging to main.

---

## Prerequisites

- **pnpm** installed (`npm install -g pnpm`)
- **gh CLI** installed for automated PR creation (`brew install gh`)
- GitHub Actions write permissions enabled (see [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md))
- Branch protection rules configured (see [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md))
- Run `pnpm install` once to set up Husky hooks
