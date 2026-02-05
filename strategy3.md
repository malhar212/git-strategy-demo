# Git Branching Strategy for Microservices Without Cherry-Picking or Feature Flags

A **release branch isolation strategy** solves your core pain points by treating each feature as an independently promotable unit—bypassing the chaotic `dev` branch entirely for production releases. This approach works with inexperienced Git users, maintains clean merge history, and allows Feature A to ship Tuesday while Feature B ships Friday without interference.

The critical insight: **Features branch from production (`main`), test in isolated sandbox environments, then create release branches that flow independently to `staging` and `main`**. No cherry-picking needed because each release branch contains only one feature's complete changes.

---

## How the release branch isolation strategy works

This strategy creates individual release branches per feature that bypass unstable shared branches entirely for production promotion:

```
main (production)
  │
  ├─── feature/CU-abc123-checkout ──► sandbox-pr-123 (isolated testing)
  │         │
  │         └──► release/CU-abc123-checkout ──(PR)──► staging ──(PR [minor])──► main (ships Tuesday)
  │                                                                              │
  │                                                               [auto-tag v1.2.0]
  │                                                               [auto-delete branch]
  │                                                               [auto-sync staging]
  │
  └─── feature/CU-def456-payments ──► sandbox-pr-456 (isolated testing)
            │
            └──► release/CU-def456-payments ──(PR)──► staging ──(PR [minor])──► main (ships Friday)
```

**The workflow for developers is deliberately simple:**

1. **Start feature from main**: `git checkout main && git pull && git checkout -b feature/CU-{task_id}-description`
2. **Develop normally** with regular commits (no format enforced on feature branches)
3. **Isolated testing**: Push feature branch → CI deploys to sandbox environment (pr-123.sandbox.yourcompany.com)
4. **Sync frequently**: `git merge --no-ff origin/main` into feature every 1-2 days to stay current
5. **When ready for UAT**: Create release branch from main, merge feature into it with `--no-ff`
6. **PR to staging**: Create PR from release branch to staging (merged with merge commit)
7. **After UAT approval**: Create PR from release branch to main with `[major|minor|patch]` prefix in title
8. **Squash merge PR to main**: This is the ONLY place we squash — creates clean single commit
9. **Automatic post-merge**: Version tag auto-created, release branch auto-deleted, staging auto-synced from main

This eliminates cherry-picking because release branches contain exactly one feature's complete changes—there's nothing to select. It eliminates blocking because Feature A's release branch operates completely independently from Feature B's. Hotfixes work cleanly because they branch from main, merge to main, then auto-sync down to staging.

---

## Branch and Commit Naming Conventions

### Branch Naming

All branches include a ClickUp task ID with `CU-` prefix:

| Branch Type | Pattern | Example |
|-------------|---------|---------|
| Feature | `feature/CU-{task_id}-description` | `feature/CU-86b62v077-user-auth` |
| Release | `release/CU-{task_id}-description` | `release/CU-86b62v077-user-auth` |
| Hotfix | `hotfix/CU-{task_id}-description` | `hotfix/CU-abc123def-critical-fix` |

**Note:** Release branch names are derived from feature branch names (no version number in the branch name). Version is computed automatically when PR is merged to main.

### Commit Message Format

**Feature branches:** Free-form commits allowed (no enforcement)
```bash
git commit -m "add login form"
git commit -m "wip validation"
```

**Release/Hotfix/Main branches:** Conventional commits enforced
```bash
git commit -m "feat(CU-86b62v077): add user authentication"
git commit -m "fix(CU-86b62v077): resolve validation issue"
```

Format: `type(scope): description`
- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `release`
- **Scope:** Usually the task ID (e.g., `CU-86b62v077`)

### Version Tagging

Versions are **automatically computed** when PRs are merged to main. The PR title must include a bump prefix:

| PR Title Prefix | Version Bump | Example |
|-----------------|--------------|---------|
| `[major]` | Breaking changes | `v1.0.0` → `v2.0.0` |
| `[minor]` | New features | `v1.0.0` → `v1.1.0` |
| `[patch]` | Bug fixes | `v1.0.0` → `v1.0.1` |

Example PR title: `[minor] feat(CU-abc123): add user authentication`

After squash merge, GitHub Actions auto-creates the tag (e.g., `v1.1.0`).

---

## Common Development Scenarios

### Scenario 1: Multiple Developers on Same Feature Branch

**Situation:** Two developers collaborating on one feature.

```bash
# Developer A pushes changes
git checkout feature/CU-abc123-desc
git add . && git commit -m "Add user validation"
git push origin feature/CU-abc123-desc

# Developer B has local commits and needs to get A's changes
git checkout feature/CU-abc123-desc
git fetch origin

# If B has NO local commits yet
git pull origin feature/CU-abc123-desc

# If B HAS local commits, use merge to combine changes
git merge --no-ff origin/feature/CU-abc123-desc
# Resolve any conflicts, then:
git push origin feature/CU-abc123-desc
```

**Best practices:**
- Communicate in team chat before pushing to shared feature branch
- Pull frequently (every hour if actively collaborating)
- Use merge (not rebase) to combine changes - safer for shared branches
- If major conflicts expected, work on sub-branches then merge to feature

---

### Scenario 2: Feature Depends on Another Unreleased Feature

**Situation:** Feature B needs code from Feature A, which hasn't merged to main yet.

**Option 1: Sequential development (RECOMMENDED)**
```bash
# Wait for Feature A to merge to main first
# Then start Feature B from main with A's code included
git checkout main
git pull  # Now includes Feature A
git checkout -b feature/CU-def102-feature-B
```

**Option 2: Branch Feature B from Feature A**
```bash
# Feature A still in development
git checkout feature/CU-abc101-feature-A
git checkout -b feature/CU-def102-feature-B

# Develop Feature B (includes A's changes)
git commit -m "Build Feature B using Feature A"

# When Feature A merges to main:
# Sync main into Feature B to properly integrate Feature A
git checkout feature/CU-def102-feature-B
git merge --no-ff main -m "Sync Feature A from main"
```

**Option 3: Merge both features together as one release**
```bash
# Create combined release branch
git checkout -b release/CU-abc101-features-A-and-B main
git merge --no-ff feature/CU-abc101-feature-A
git merge --no-ff feature/CU-def102-feature-B
# Resolve conflicts if any

# Test together, ship together
git checkout main
git merge --squash release/CU-abc101-features-A-and-B
git commit -m "feat: Features A and B combined"
git tag v1.5.0
```

**Best practice:** Use Option 1 (sequential) when possible. Option 3 if features must ship together.

---

### Scenario 3: Emergency Hotfix While Features Are in Staging

**Situation:** Production bug discovered while features are being tested in staging.

```bash
# Create hotfix branch (task ID required)
git checkout main && git pull
git checkout -b hotfix/CU-xyz789-critical-payment-bug

# Fix the bug (conventional commits enforced on hotfix branches)
git commit -m "fix(CU-xyz789): prevent negative payment amounts"
git push -u origin hotfix/CU-xyz789-critical-payment-bug

# Create PR to main with [patch] prefix in title
# Title: "[patch] fix(CU-xyz789): prevent negative payment amounts"
# Squash merge the PR on GitHub

# After PR is merged:
# - Auto-tag v1.2.1 is created
# - Hotfix branch is auto-deleted
# - Staging is auto-synced from main (via sync-staging workflow)
```

**If auto-sync to staging fails due to conflicts:**
```bash
# Manual resolution
git checkout staging
git pull origin staging
git merge origin/main --no-ff
# Resolve conflicts...
git add .
git commit
git push origin staging
```

**Key points:**
- Hotfixes can skip staging for urgent production fixes (prompted during ship)
- PR to main requires `[patch]` prefix for auto-versioning
- Auto-sync ensures staging gets the hotfix automatically
- Features currently in staging are re-tested with the hotfix included

---

### Scenario 4: UAT Finds Bugs in Release Branch

**Situation:** Release branch is in staging for UAT, testers find bugs that need fixing.

```bash
# UAT testing release/CU-abc123-user-dashboard in staging
# Bugs found!

# Fix in the feature branch (source of truth)
git checkout feature/CU-abc123-user-dashboard
git commit -m "fix: address UAT feedback on validation"
git commit -m "fix: correct dashboard layout issue"
git push origin feature/CU-abc123-user-dashboard

# Sync fixes INTO existing release branch
git checkout release/CU-abc123-user-dashboard
git merge --no-ff feature/CU-abc123-user-dashboard
git push origin release/CU-abc123-user-dashboard

# Staging automatically has updated release branch
# Re-deploy staging environment for re-test
```

**Key points:**
- Always fix bugs in feature branch (source of truth)
- **CRITICAL: No direct commits on release branches** - only merge from feature
- Merge feature into release to update it (Git knows what's new)
- Release branch can accumulate updates via merge - this is normal and expected
- Staging automatically reflects updated release branch (no recreation needed)

---

### Scenario 5: Feature Cancelled (Never Ships to Production)

**Situation:** Feature merged to staging, but business decides not to ship it.

```bash
# Feature A tested in staging but cancelled

# Step 1: Delete release branch
git branch -D release/CU-abc123-cancelled-feature
git push origin --delete release/CU-abc123-cancelled-feature

# Step 2: Remove from staging
git checkout staging
git reset --hard main

# Step 3: Re-add any still-testing features
git merge --no-ff release/CU-def456-feature-B  # Feature B still testing
git push --force origin staging

# Step 4: Delete feature branch
git branch -D feature/CU-abc123-desc
git push origin --delete feature/CU-abc123-desc

# Step 5: Close ticket and document why it was cancelled
```

**Key points:**
- Cancelled features never contaminated main (production stays clean)
- Reset staging to remove cancelled feature cleanly
- Always document why features are cancelled for future reference

---

### Scenario 6: Syncing Main Changes into Staging

**Situation:** Feature A ships to production on Tuesday, Feature B still testing in staging.

```bash
# Tuesday: Feature A's PR to main is squash-merged
# PR title was: "[minor] feat(CU-ghi404): Feature A implementation"

# After merge, automatically:
# - Auto-tag v1.3.0 is created
# - Release branch release/CU-ghi404-feature-A is auto-deleted
# - Staging is auto-synced from main (via sync-staging.yml workflow)

# Feature B continues testing with Feature A integrated automatically!
```

**If auto-sync fails due to conflicts:**
A GitHub issue is automatically created. Manual resolution:

```bash
git checkout staging
git pull origin staging
git merge origin/main --no-ff
# Resolve conflicts...
git add .
git commit
git push origin staging
```

**When to manually reset staging:**
- When auto-sync repeatedly fails due to accumulated conflicts
- When staging has become messy
- NOT after every release (auto-sync handles normal cases)

**Key points:**
- Staging sync is automated via `sync-staging.yml` workflow
- Manual intervention only needed if conflicts occur
- Feature B now tests against actual production state (with Feature A integrated)

---

### Scenario 7: Merge Conflicts When Merging to Staging

**Situation:** Feature A already in staging, Feature B conflicts with it when merging to staging.

**Critical insight:** Conflicts CANNOT be resolved only in staging. They must be resolved in the release branches, otherwise the conflict resolution is lost when merging to main.

**Solution 1: Sequential testing with staging sync (RECOMMENDED)**

Avoid conflicts entirely by testing features one at a time:

```bash
# Week 1: Feature A in staging (being tested)
git checkout staging
git merge --no-ff release/CU-abc101-feature-A
git push origin staging
# UAT Feature A

# Feature B also ready, but DON'T merge it yet (would conflict)

# Feature A passes UAT → ship to production
git checkout main
git merge --squash release/CU-abc101-feature-A
git commit -m "feat: Feature A"
git tag v1.3.0
git push origin main v1.3.0

# Sync main → staging immediately
git checkout staging
git merge --no-ff main -m "Sync Feature A from production"
git push origin staging
# Staging now has Feature A as baseline from production

# Week 2: Now test Feature B
git checkout staging
git merge --no-ff release/CU-def102-feature-B
git push origin staging
# No conflicts! Feature A is already integrated from production
```

**Why this works:** Feature B merges to a staging that already has Feature A as the baseline from production. No conflicts occur, and Feature B correctly tests against production state.

---

**Solution 2: Resolve conflicts in release branches, ship together**

If features truly must be tested together before production:

```bash
# Feature A already in staging
git checkout staging
git merge --no-ff release/CU-abc101-feature-A

# Try to merge Feature B
git merge --no-ff release/CU-def102-feature-B
# CONFLICT in src/app.js!

# ⚠️ DO NOT resolve conflicts in staging! Abort.
git merge --abort

# Better approach: Create a combined release with both features
git checkout main
git checkout -b release/CU-abc101-combined
git merge --no-ff feature/CU-abc101-feature-A
git merge --no-ff feature/CU-def102-feature-B
# Resolve conflicts during merge
git push origin release/CU-abc101-combined

# Now staging merge works cleanly
git checkout staging
git reset --hard main  # Clean slate
git merge --no-ff release/CU-abc101-combined
git push --force origin staging

# Test together in staging

# After UAT passes, ship to main
git checkout main
git merge --squash release/CU-abc101-combined
git commit -m "feat: Features A and B"
git tag v1.5.0
git push origin main v1.5.0
```

**Key points:**
- Don't resolve conflicts in staging
- Create a combined release branch that merges both features
- Conflicts resolved in the combined release branch
- Both features ship together as a bundle

**Key points:**
- Conflicts resolved in Feature B's release branch (not staging!)
- Feature B's release now includes Feature A + conflict resolution
- When merging to main, conflicts are already resolved
- Both features ship together as a bundle

---

**Solution 3: Create combined release branch**

If features are tightly coupled and should always ship together:

```bash
# Create one combined release
git checkout -b release/CU-abc101-features-A-and-B main
git merge --no-ff feature/CU-abc101-feature-A
git merge --no-ff feature/CU-def102-feature-B
# Resolve conflicts during the merge if needed
git push origin release/CU-abc101-features-A-and-B

# Test together in staging
git checkout staging  
git merge --no-ff release/CU-abc101-features-A-and-B
git push origin staging

# Ship together to main
git checkout main
git merge --squash release/CU-abc101-features-A-and-B
git commit -m "feat: Features A and B"
git tag v1.5.0
git push origin main v1.5.0
```

**When to use each solution:**
- **Solution 1 (Sequential):** Features are independent, conflicts are accidental → RECOMMENDED for most cases
- **Solution 2 (Resolve in release):** Features are related, both need testing together but could theoretically ship separately
- **Solution 3 (Combined release):** Features are tightly coupled and must always ship as one unit

**Critical rule:** Never resolve conflicts only in staging. Always resolve in release branches so the resolution carries through to main.

---

### Scenario 8: Building Feature Iteratively with Multiple Releases

**Situation:** Large feature built in phases, each phase ships to production.

**Option A: Continue building on same feature branch (ITERATIVE)**

```bash
# Phase 1: MVP of checkout flow
git checkout main
git checkout -b feature/CU-abc123-desc-checkout-flow

# Build MVP
git commit -m "Add cart functionality"
git commit -m "Add basic payment processing"

# Ship MVP to production
git checkout main
git checkout -b release/CU-abc123-checkout-mvp
git merge --no-ff feature/CU-abc123-desc-checkout-flow
git push origin release/CU-abc123-checkout-mvp

git checkout staging
git merge --no-ff release/CU-abc123-checkout-mvp
# UAT passes
git checkout main
git merge --squash release/CU-abc123-checkout-mvp
git commit -m "feat(CU-abc123): checkout flow MVP"
git tag v1.5.0
git push origin main v1.5.0

# Phase 2: Continue on SAME feature branch for enhancements
git checkout feature/CU-abc123-desc-checkout-flow
git merge --no-ff main  # Sync production changes (includes Phase 1)

# Add enhancements
git commit -m "Add discount codes"
git commit -m "Add gift card support"

# Ship enhancements
git checkout main
git checkout -b release/CU-abc123-checkout-enhanced
git merge --no-ff feature/CU-abc123-desc-checkout-flow
# ... test, approve, merge to main ...

# Phase 3: Final polish
git checkout feature/CU-abc123-desc-checkout-flow
git merge --no-ff main  # Sync again
git commit -m "Add analytics tracking"

git checkout main
git checkout -b release/CU-abc123-checkout-final
git merge --no-ff feature/CU-abc123-desc-checkout-flow
# ... test, approve, merge to main ...

# Finally cleanup
git branch -D feature/CU-abc123-desc-checkout-flow
git push origin --delete feature/CU-abc123-desc-checkout-flow
```

**Option B: Separate branches merged together (PARALLEL)**

```bash
# Multiple sub-feature branches developed in parallel
git checkout -b release/CU-abc123-complete-checkout main
git merge --no-ff feature/CU-mno100-cart
git merge --no-ff feature/CU-abc101-payment
git merge --no-ff feature/CU-def102-confirmation
# Ship all together
```

**When to use each:**
- **Option A (iterative):** Building incrementally, shipping MVP then improving
- **Option B (parallel):** Sub-features developed by different developers simultaneously

**Key points for Option A:**
- Same feature branch lives for weeks/months
- Sync with main MORE frequently (daily or every 2 days)
- Each phase gets its own release branch and version tag
- Feature branch accumulates all phases until completely done

---

## Handling your specific pain points

**Pain Point 1: Feature A tested, Feature B in testing → A blocked**

With release branch isolation, Feature A has `release/feature-A` deploying to staging while Feature B has a separate `release/feature-B` in its sandbox. They never interact. When Feature A passes UAT, merge it to main and deploy—Feature B's status is irrelevant.

For services that must be tested together, use a **shared release branch**: `release/CU-abc123-auth-plus-payments` that merges both features from their feature branches. This is the exception, not the norm.

**Pain Point 2: Hotfixes require pushing half-tested code**

Hotfixes now follow a completely separate path:

```bash
git checkout main
git checkout -b hotfix/CU-xyz789-critical-payment-bug
# Fix the issue
git checkout main
git merge --squash hotfix/CU-xyz789-critical-payment-bug
git commit -m "fix: critical payment bug"
git tag v1.2.1
# Deploy immediately
# Then sync to staging
git checkout staging
git merge --no-ff main
```

Hotfixes never touch feature code because they branch from and merge to production directly.

**Pain Point 3: Features interfere during testing**

Features test in **isolated sandbox environments** deployed per-feature-branch. Features can't interfere when they run in separate sandbox namespaces (pr-123.sandbox.yourcompany.com vs pr-456.sandbox.yourcompany.com).

**Pain Point 4: Merge conflicts with multi-commit features**

Use **frequent syncing** of main into features (every 1-2 days):

```bash
git checkout feature/CU-abc123-desc
git merge --no-ff main -m "Sync main changes"
```

Small, frequent syncs prevent massive conflicts. When you're ready to ship, the release branch is already mostly compatible with main.

---

## Sandbox Environments: Replacing Shared Integration Branches

**Sandbox environments are the key innovation** that replaces shared integration branches. When a developer pushes a feature branch, CI automatically:

1. Builds the service image tagged with the branch name or PR number
2. Deploys to a dedicated Kubernetes namespace: `sandbox-pr-123`
3. Routes test traffic via subdomain: `pr-123.sandbox.yourcompany.com`
4. Tears down automatically when PR closes or merges

**Benefits over shared integration branches:**
- ✅ No feature interference during testing
- ✅ QA can test multiple features simultaneously
- ✅ Closer to production environment than local Docker
- ✅ Each developer can iterate without blocking others
- ✅ No need for feature flags to isolate code

**Simple implementation with Kubernetes:**

```yaml
# .github/workflows/sandbox-deploy.yml
name: Deploy Sandbox Environment
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]

jobs:
  deploy-sandbox:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set PR number
        run: echo "PR_NUMBER=${{ github.event.pull_request.number }}" >> $GITHUB_ENV
      
      - name: Build and push image
        run: |
          docker build -t yourregistry/service:pr-$PR_NUMBER .
          docker push yourregistry/service:pr-$PR_NUMBER
      
      - name: Deploy to sandbox namespace
        run: |
          kubectl create namespace sandbox-pr-$PR_NUMBER --dry-run=client -o yaml | kubectl apply -f -
          helm upgrade --install service-pr-$PR_NUMBER ./helm \
            --namespace sandbox-pr-$PR_NUMBER \
            --set image.tag=pr-$PR_NUMBER \
            --set ingress.host=pr-$PR_NUMBER.sandbox.yourcompany.com
      
      - name: Comment PR with sandbox URL
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🚀 Sandbox deployed: https://pr-${{ env.PR_NUMBER }}.sandbox.yourcompany.com`
            })
```

**Cleanup:**

```yaml
# .github/workflows/sandbox-cleanup.yml
name: Cleanup Sandbox
on:
  pull_request:
    types: [closed]

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete namespace
        run: |
          kubectl delete namespace sandbox-pr-${{ github.event.pull_request.number }} --ignore-not-found=true
```

---

## Branching across multiple service repos

The deployment repository pattern coordinates versions across your microservices without requiring synchronized branching. Create a dedicated `deployment-config` repository that tracks which service versions are deployed together:

```yaml
# deployment-config/environments/staging/versions.yaml
services:
  user-service: v2.3.1      # Updated Tuesday (feature A)
  order-service: v1.8.0     # Unchanged
  payment-service: v3.1.0   # Updated Friday (feature B)
  api-gateway: v2.0.5       # Unchanged
frontend:
  web-app: v1.5.0
```

**The coordination workflow operates as follows:**

Each service repository builds and tags artifacts independently. When Service A's `release/feature-A` passes UAT, a developer opens a PR to `deployment-config` updating `user-service: v2.3.1`. CI/CD deploys whatever versions are specified. Service B can remain at v1.8.0 indefinitely while Service A promotes.

**For features spanning multiple services**, use consistent ticket-based naming across repos:

```
org/user-service:      feature/CU-abc123-desc-sso-integration
org/auth-service:      feature/CU-abc123-desc-sso-provider
org/frontend:          feature/CU-abc123-desc-sso-ui
```

Link these in a GitHub Project board so the team sees they're related. Each service still gets its own release branch and promotes independently, but the deployment-config PR updates all affected service versions together.

---

## UAT environment configuration

UAT should run production-like infrastructure with independently deployable services. **Do not deploy a staging branch to UAT**—deploy specific release branches or versioned artifacts.

**Environment architecture:**

| Environment | Purpose | What Deploys Here |
|-------------|---------|-------------------|
| **Local** | Developer inner-loop | Docker Compose with service stubs |
| **Sandbox** | Per-feature isolated testing | Feature branch artifacts (ephemeral) |
| **UAT/Staging** | User acceptance, pre-prod | Specific release branch artifacts |
| **Production** | Live system | Tagged releases from main |

**Sandbox deployment via GitHub Actions** is shown in the previous section.

**UAT deployment uses the deployment-config repository:**

When `release/feature-A` is ready for UAT, update `deployment-config/environments/uat/versions.yaml` and merge that PR. ArgoCD or similar GitOps tooling syncs UAT to match the declared versions. Different features deploy to UAT independently by updating their service version in separate PRs.

---

## Promoting services independently

The version manifest pattern enables true independent deployment. Each service follows this promotion flow:

```
Service A:
  PR merged → Build v2.3.1 → Sandbox test ✓ → Update UAT manifest → UAT approved → Update prod manifest

Service B:
  PR merged → Build v3.1.0 → Sandbox test (ongoing) → (waits)
```

Service A's Tuesday deployment updates only `user-service: v2.3.1` in the production manifest. Service B's version remains unchanged until Friday.

**Rollback is equally independent**: revert the specific service version in the manifest. ArgoCD automatically syncs to the previous version. Other services are unaffected.

**For services with tight coupling**, create an explicit dependency matrix in your deployment-config:

```yaml
# deployment-config/compatibility.yaml
user-service:
  v2.3.x:
    requires:
      auth-service: ">=v1.5.0"
      database-migrations: ">=2024-01-15"
```

CI validates these constraints before allowing promotion. This makes implicit dependencies explicit and testable.

---

## Preventing staging divergence

The release branch strategy eliminates this problem structurally. Since releases branch from individual features (which branch from main), there's no staging branch that diverges. The staging *environment* receives specific release branches, not a staging branch.

**When features never ship:**

The feature branch and its release branch are simply abandoned. They never contaminated `main`. To clean up:

1. Delete the feature branch after 30 days of inactivity (automate with GitHub Actions)
2. Delete any associated release branches
3. Remove from staging by resetting to main and re-adding active features

**Long-term branch hygiene automation:**

```yaml
# .github/workflows/cleanup-stale-branches.yml
name: Stale Branch Cleanup
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          stale-branch-message: 'Branch inactive for 30 days, will be deleted in 15 days'
          days-before-stale: 30
          days-before-delete: 45
          exempt-branches: 'main,staging'
```

---

## Enforcing the workflow with automation

Your inexperienced developers need guardrails that prevent mistakes, not documentation they'll ignore. Here's a complete enforcement system using GitHub's free features plus Husky hooks.

**Branch protection rules (requires GitHub Team at $4/user/month for private repos):**

For `main`:
- Require pull request before merging (1 approval minimum)
- Require status checks to pass (your CI workflow)
- Require branches to be up to date
- Do not allow bypassing these settings
- Disable force pushes and deletions

For `staging`:
- Require pull request (1 approval)
- Require status checks
- Allow force pushes (needed for reset operations)

For `release/*` (pattern protection):
- Require pull request (prevents direct commits - enforces merge-only!)
- Require 1 approval
- Require status checks
- This ensures no direct commits on release branches

**GitHub Action to enforce branch targets:**

```yaml
# .github/workflows/branch-enforcement.yml
name: Branch Enforcement
on: [pull_request]

jobs:
  check-branch:
    runs-on: ubuntu-latest
    steps:
      - name: Validate PR target
        run: |
          BASE="${{ github.base_ref }}"
          HEAD="${{ github.head_ref }}"
          
          echo "PR: $HEAD → $BASE"
          
          # Features can only merge to main (for code review)
          if [[ "$HEAD" == feature/* && "$BASE" != "main" ]]; then
            echo "::error::Feature branches must target 'main' for review, not '$BASE'"
            exit 1
          fi
          
          # Release branches can merge to staging or main
          if [[ "$HEAD" == release/* && "$BASE" != "staging" && "$BASE" != "main" ]]; then
            echo "::error::Release branches merge to 'staging' or 'main', not '$BASE'"
            exit 1
          fi
          
          # Hotfixes go directly to main
          if [[ "$HEAD" == hotfix/* && "$BASE" != "main" ]]; then
            echo "::error::Hotfix branches merge directly to 'main'"
            exit 1
          fi
          
          echo "✅ Branch target validated"
  
  check-staleness:
    runs-on: ubuntu-latest
    if: startsWith(github.head_ref, 'feature/') || startsWith(github.head_ref, 'release/')
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Check if branch is behind main
        run: |
          git fetch origin main
          BEHIND=$(git rev-list --count HEAD..origin/main)
          
          if [ $BEHIND -gt 20 ]; then
            echo "::error::Branch is $BEHIND commits behind main!"
            echo "This is dangerous. Please sync: git merge --no-ff origin/main"
            exit 1
          elif [ $BEHIND -gt 10 ]; then
            echo "::warning::Branch is $BEHIND commits behind main"
            echo "Consider syncing: git merge --no-ff origin/main"
          elif [ $BEHIND -gt 0 ]; then
            echo "::notice::Branch is $BEHIND commits behind main (acceptable)"
          else
            echo "✅ Branch is up-to-date with main"
          fi
```

**Husky hooks for local enforcement (automatically installed via pnpm install):**

```bash
# .husky/pre-push
# Blocks direct push to main/staging
# Validates branch naming: {type}/CU-{task_id}-description

BRANCH=$(git symbolic-ref --short HEAD)

# Block protected branches
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "staging" ]; then
  echo "❌ Cannot push directly to '$BRANCH'. Create a PR instead."
  exit 1
fi

# Validate branch naming pattern
PATTERN="^(feature|release|hotfix)/CU-[a-z0-9]+-[a-z0-9-]+$"
if ! echo "$BRANCH" | grep -qE "$PATTERN"; then
  echo "❌ Invalid branch name: '$BRANCH'"
  echo "Expected: feature/CU-{task_id}-description"
  echo "          release/CU-{task_id}-description"
  echo "          hotfix/CU-{task_id}-description"
  exit 1
fi
```

```bash
# .husky/commit-msg
# Only enforces conventional commits on release/*, hotfix/*, and main
# Feature branches are free-form (no enforcement)

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)

if [ "$BRANCH" = "main" ] || echo "$BRANCH" | grep -qE '^(release|hotfix)/'; then
  npx --no -- commitlint --edit ${1}
fi
```

**Auto-fix wrong PR targets:**

```yaml
# .github/workflows/fix-pr-target.yml
name: Auto-fix PR Target
on:
  pull_request_target:
    types: [opened]

jobs:
  fix-target:
    if: startsWith(github.head_ref, 'feature/') && github.base_ref != 'main'
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            await github.rest.pulls.update({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.payload.pull_request.number,
              base: 'main'
            });
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number,
              body: '⚠️ Feature branches merge to `main` for code review. I\'ve updated the target for you.'
            });
```

---

## Complete workflow from feature to production

Here's the end-to-end workflow your developers will follow:

**Day 1-3: Feature development**
```bash
# Start from main
git checkout main && git pull
git checkout -b feature/CU-abc123-user-dashboard

# Develop, commit freely (no format enforced on feature branches)
git add . && git commit -m "add dashboard layout"
git add . && git commit -m "wip: validation logic"
git push -u origin feature/CU-abc123-user-dashboard

# CI automatically deploys to sandbox-pr-123.yourcompany.com
# Open PR targeting main for code review
```

**Day 2-3: Keep feature branch updated (CRITICAL)**

While you're developing, other features may merge to main. Sync these changes into your feature branch to avoid conflicts later.

```bash
# Every 1-2 days, or when you hear "Feature X merged to main":
git checkout feature/CU-abc123-user-dashboard
git fetch origin

# Check if main has moved ahead
git log feature/CU-abc123-user-dashboard..origin/main
# Shows commits in main that aren't in your branch

# Merge main into your feature with --no-ff
git merge --no-ff origin/main -m "chore: sync with main"
git push origin feature/CU-abc123-user-dashboard
```

**Why merge (not rebase):**
- Safe (no force-push required)
- Multiple devs can work on same feature
- Consistent with --no-ff strategy throughout workflow
- Merge commits in feature don't matter (you squash when merging to main)

**Handling merge conflicts when syncing:**

If you get conflicts while merging main into your feature:

```bash
# Git pauses and shows:
# CONFLICT (content): Merge conflict in src/app.js

# Open the conflicting files, look for conflict markers:
# <<<<<<< HEAD (your feature changes)
# your code
# =======
# their code (from main)
# >>>>>>> origin/main

# Edit files to resolve conflicts, then:
git add src/app.js
git commit  # Completes the merge with default message
git push origin feature/CU-abc123-user-dashboard
```

**Day 4: Testing in sandbox**
```bash
# PR triggers sandbox deployment automatically
# Test at pr-123.sandbox.yourcompany.com
# QA verifies functionality in isolation
# Found issue? Fix in feature branch, push, re-test automatically
```

**Day 5: Ready for UAT**
```bash
# Create release branch from main (name derived from feature branch, no version)
git checkout main && git pull
git checkout -b release/CU-abc123-user-dashboard
git merge --no-ff feature/CU-abc123-user-dashboard -m "feat(CU-abc123): merge feature into release"
git push -u origin release/CU-abc123-user-dashboard

# Create PR from release branch to staging (via GitHub UI or gh CLI)
# PR is merged with merge commit (not squash) to preserve history
```

**Day 6-7: UAT and production**
```bash
# UAT approved? Create PR from release branch to main
# PR title MUST include bump prefix: "[minor] feat(CU-abc123): user dashboard"

# Squash merge the PR on GitHub (this is the ONLY place we squash)

# After PR is merged, automatically:
# - Version tag v1.5.0 is created (computed from [minor] + latest tag)
# - Release branch release/CU-abc123-user-dashboard is auto-deleted
# - Staging is auto-synced from main

# Local cleanup (optional)
git checkout main && git pull
git branch -d release/CU-abc123-user-dashboard
git branch -d feature/CU-abc123-user-dashboard
```

---

## Understanding `--no-ff` and squash merges

You'll notice this workflow uses `--no-ff` for almost all merges, with **squash merge used only for the final merge to main**. Here's why:

### When to use `--no-ff` (almost everywhere)

**What `--no-ff` does:**

```bash
git checkout staging
git merge --no-ff release/CU-abc123-feature
```

**Without `--no-ff` (default Git behavior - fast-forward when possible):**

```bash
git checkout main
git merge feature/A  # Git does a "fast-forward"

# Result: Feature commits appear directly on main
main: ●───●───●───●───● (linear history, can't see feature boundary)
```

**With `--no-ff` (forces merge commit):**

```bash
git checkout main
git merge --no-ff feature/A  # Forces explicit merge commit

# Result: Clear feature boundary with merge commit
main: ●───●───●───────●(M) ← Merge commit M
             ↘       ↗
feature:      ●───●───●
```

**Benefits of `--no-ff`:**

1. **Clear feature boundaries** - You can see exactly where each feature starts and ends in history
2. **Easy rollback** - Revert entire feature with one command: `git revert -m 1 <merge-commit>`
3. **Audit trail** - Every feature has explicit merge commit with description and ticket number
4. **Debugging** - When a bug appears, easily identify which feature introduced it
5. **Code review** - Reviewers can see entire feature as one logical unit
6. **Consistent workflow** - Every merge creates a commit (predictable, no surprises)

**Use `--no-ff` for:**
- Syncing main → feature: `git merge --no-ff main`
- Creating release from feature: `git merge --no-ff feature/CU-abc123-desc`
- Updating release with fixes: `git merge --no-ff feature/CU-abc123-desc`
- Merging release → staging: `git merge --no-ff release/CU-abc123-feature`
- Syncing main → staging: `git merge --no-ff main`

---

### When to use squash merge (final merge to main ONLY)

```bash
git checkout main
git merge --squash release/CU-abc123-feature
git commit -m "feat(CU-abc123): complete feature description"
```

**What squash merge does:**

Takes all commits from the release branch and combines them into a single commit on main.

**Before squash - release branch:**
```
release: ●───●───●───●───●───● (could be 15+ commits)
         "Add login" "Fix bug" "Add validation" "UAT fix 1" "UAT fix 2" ...
```

**After squash - main:**
```
main: ●───●───●───● (single commit with all changes)
                 "feat(CU-abc123): user authentication system"
```

**Why squash only at the final step:**
- ✅ Clean, readable main history (one commit per feature shipped)
- ✅ Easy changelog generation (one entry per feature)
- ✅ Simpler code review of what shipped to production
- ✅ Main branch stays lean and easy to navigate
- ✅ Detailed history preserved in feature/release branches (for 30+ days)
- ✅ Release branch can have messy history - doesn't matter, main stays clean

**Why NOT squash earlier:**
- ❌ Squashing to release makes updates complicated (reset/recreate drama)
- ❌ Release branches are just promotion vehicles - who cares if they're messy?
- ❌ Adds unnecessary complexity with no benefit
- ✅ Using regular merge everywhere (except final step) is simpler and more consistent

**Trade-offs of squashing to main:**
- ⚠️ Can't use `git revert -m 1` (use `git revert <commit-hash>` instead - still works fine)
- ⚠️ Less granular git blame on main (but you can check feature branch for details)
- ⚠️ Detailed commit history only visible in feature/release branches

**Mitigation:** Keep feature/release branches for 30-60 days after merge via automation, then delete. This preserves detailed history for debugging recent issues while keeping main clean long-term.

---

### Summary of merge strategy

| Merge | Command | Reason |
|-------|---------|--------|
| main → feature | `git merge --no-ff main` | Track when production code synced |
| feature → release | `git merge --no-ff feature` | Copy feature work to release |
| release → staging | `git merge --no-ff release/CU-abc123-feature` | See feature boundaries in staging |
| main → staging | `git merge --no-ff main` | Track production syncs to staging |
| **release → main** | `git merge --squash release/CU-abc123-feature` | **Clean main history (ONLY squash here)** |
| hotfix → main | `git merge --squash hotfix/CU-xyz789-critical` | **Clean main history** |

**The philosophy:** 
- Use `--no-ff` everywhere for clear history and easy rollback
- Squash **only** when merging to main for clean production history
- Feature and release branches can be messy - that's fine!
- Main is what matters for clean, readable history

---

## Pros and cons of this approach

**Advantages:**
- **No cherry-picking ever**—each release branch is a complete, mergeable unit
- **True independent releases**—Feature A's Tuesday release is completely decoupled from Feature B
- **Hotfixes bypass everything**—direct main→main flow with clean merge history
- **Simple mental model for juniors**—feature from main, test in sandbox, release when ready
- **Enforceable**—GitHub Actions and hooks prevent mistakes automatically
- **Clean main history**—squash merges keep main readable; detailed history in branches
- **Isolated testing**—sandbox environments prevent feature interference
- **No shared integration branch**—eliminates dev branch chaos

**Disadvantages:**
- **More branches to manage**—each feature gets a release branch (automation helps)
- **Requires discipline on "start from main"**—hooks enforce this but developers must understand why
- **Requires GitHub Team**—$24/month for 6 developers to get branch protection on private repos
- **Sandbox environments add complexity**—but are essential for isolated testing without feature flags
- **Frequent syncing required**—developers must merge main into features every 1-2 days
- **Staging can accumulate conflicts**—requires periodic resets when conflicts occur

**Comparison to alternatives:**

| Strategy | Cherry-pick free | No feature flags | Junior-friendly | Independent releases |
|----------|------------------|------------------|-----------------|---------------------|
| **Release branch isolation** | ✅ | ✅ | ✅ | ✅ |
| Traditional GitFlow | ❌ Hotfixes need picks | ✅ | ⚠️ Complex | ❌ Batch releases |
| Trunk-based + flags | ✅ | ❌ Requires flags | ⚠️ Needs discipline | ✅ |
| Environment branches | ❌ Needs cherry-pick | ✅ | ✅ | ❌ Branch coupling |

---

## Implementation checklist

**Week 1: Foundation**
- [ ] Configure branch protection on main and staging
- [ ] Add branch enforcement GitHub Action
- [ ] Set up Husky with pre-push hooks
- [ ] Document the workflow in CONTRIBUTING.md (include sync procedure)
- [ ] Train team on "features start from main" rule
- [ ] Train team on "sync main into features every 1-2 days" rule

**Week 2: CI/CD pipeline**
- [ ] Create per-service deployment pipelines
- [ ] Set up deployment-config repository with version manifests
- [ ] Configure ArgoCD or similar GitOps tooling
- [ ] Add GitHub Action to check if feature branches are behind main

**Week 3: Sandbox environments**
- [ ] Set up Kubernetes namespaces for sandboxes
- [ ] Add GitHub Action for sandbox deployment on PR
- [ ] Configure teardown automation when PRs close
- [ ] Test isolated feature deployments

**Week 4: Refinement**
- [ ] Add stale branch cleanup automation
- [ ] Create hotfix reminder workflow
- [ ] Document rollback procedures
- [ ] Create sync reminder automation (notify if feature is 10+ commits behind)
- [ ] Run team retrospective and adjust

---

## Quick Reference: Common Commands

### Starting a new feature
```bash
git checkout main && git pull
git checkout -b feature/CU-{task_id}-description
git push -u origin feature/CU-{task_id}-description
# CI deploys to sandbox-pr-123.yourcompany.com
```

### Keeping feature updated with main (do every 1-2 days)
```bash
git checkout feature/CU-abc123-my-feature
git fetch origin
git log feature/CU-abc123-my-feature..origin/main  # Check what's new

# Merge main into feature (use merge, not rebase)
git merge --no-ff origin/main -m "chore: sync with main"
git push origin feature/CU-abc123-my-feature
```

### Creating release branch
```bash
# Final sync (REQUIRED)
git checkout feature/CU-abc123-my-feature
git merge --no-ff origin/main -m "chore: final sync before release"
git push origin feature/CU-abc123-my-feature

# Create release (name derived from feature, no version number)
git checkout main && git pull
git checkout -b release/CU-abc123-my-feature
git merge --no-ff feature/CU-abc123-my-feature -m "feat(CU-abc123): merge feature into release"
git push -u origin release/CU-abc123-my-feature
```

### PR to staging for UAT
```bash
# Create PR from release/CU-abc123-my-feature to staging
# Via GitHub UI or: gh pr create --base staging --title "chore: merge release to staging"
# Merge with merge commit (not squash)
```

### PR to production (SQUASH MERGE via PR)
```bash
# Create PR from release/CU-abc123-my-feature to main
# PR title MUST have bump prefix: "[minor] feat(CU-abc123): feature description"
# Via GitHub UI or: gh pr create --base main --title "[minor] feat(CU-abc123): description"

# Squash merge the PR on GitHub

# After merge, automatically:
# - Version tag created (e.g., v1.5.0)
# - Release branch deleted
# - Staging synced from main
```

### Handling UAT failures
```bash
# Fix in feature branch (source of truth)
git checkout feature/CU-abc123-my-feature
git commit -m "fix validation issue"
git commit -m "fix layout issue"
git push origin feature/CU-abc123-my-feature

# Sync fixes into release branch
git checkout release/CU-abc123-my-feature
git merge --no-ff feature/CU-abc123-my-feature -m "chore: sync UAT fixes from feature"
git push origin release/CU-abc123-my-feature
# Open PR to staging auto-updates, re-test
```

### Abandoning a feature
```bash
# Delete release and feature branches
git push origin --delete release/CU-abc123-my-feature
git push origin --delete feature/CU-abc123-my-feature

# If feature was in staging, reset staging
git checkout staging
git reset --hard main
# Re-add still-testing features if any
git merge --no-ff release/CU-def456-other-feature
git push --force origin staging
```

### Hotfix workflow (task ID required)
```bash
git checkout main && git pull
git checkout -b hotfix/CU-xyz789-critical-issue
# Fix and commit (conventional commits enforced on hotfix)
git commit -m "fix(CU-xyz789): critical issue description"
git push -u origin hotfix/CU-xyz789-critical-issue

# Create PR to main with [patch] prefix
# Title: "[patch] fix(CU-xyz789): critical issue description"
# Squash merge the PR

# After merge: auto-tag created, branch deleted, staging synced
```

### Check if your feature is behind main
```bash
git fetch origin
git log feature/CU-abc123-my-feature..origin/main
# If output shows commits, you need to sync
```

---

## Frequently Asked Questions

### Why is staging synced automatically?

After any PR is merged to main, the `sync-staging.yml` workflow automatically merges main into staging with `--no-ff`. This ensures:
- Staging always has the latest production code as baseline
- Features testing in staging are tested against current production
- No manual sync step required

**If auto-sync fails due to conflicts:**

A GitHub issue is automatically created. Manual resolution:

```bash
git checkout staging
git pull origin staging
git merge origin/main --no-ff
# Resolve conflicts...
git add .
git commit
git push origin staging
```

**When to manually reset staging:**
- When `main → staging` merge fails due to conflicts
- When staging has accumulated too many failed merge attempts
- When starting fresh for a new release cycle

---

### What if features conflict when merging to staging?

**Solution: Sequential testing (RECOMMENDED)**

Avoid conflicts entirely by testing features one at a time:

```bash
# Test Feature A first
git checkout staging
git merge --no-ff release/CU-abc101-feature-A
# Feature A passes → ship to production

git checkout main
git merge --squash release/CU-abc101-feature-A
git commit -m "feat: Feature A"
git tag v1.3.0
git push origin main v1.3.0

# Sync main → staging
git checkout staging
git merge --no-ff main
git push origin staging
# Staging now has Feature A as baseline

# Now test Feature B
git merge --no-ff release/CU-def102-feature-B
# No conflicts! Feature A is already integrated
```

**Why this works:** Feature A is now in staging from production (baseline), not as competing change.

---

### How often should I sync main into my feature?

**Recommended frequency:**
- **Short features (1-3 days):** Once before creating release
- **Medium features (1-2 weeks):** Every 1-2 days  
- **Long features (weeks/months):** Daily

**When to sync immediately:**
- When you hear "Feature X merged to main"
- Before creating release branch (required)
- After a hotfix ships to production

**No downside to frequent syncing.** Small conflicts are easier than massive ones.

---

### Can I keep building on the same feature branch?

**Yes!** For iterative development:

```bash
# Phase 1: Ship MVP
git checkout feature/CU-abc123-desc-checkout
# ... build MVP ...
git checkout -b release/CU-abc123-mvp
# Ship to production

# Phase 2: Continue same branch
git checkout feature/CU-abc123-desc-checkout
git merge --no-ff main  # Sync production
# ... add enhancements ...
git checkout -b release/CU-abc123-enhanced
# Ship enhancements
```

**Key points:**
- Same feature branch can live for weeks/months
- Sync with main DAILY for long-lived features
- Each phase gets its own release and version tag

---

### Why squash merge only to main, not earlier?

**Strategy:**
- Use `--no-ff` for all merges except final merge to main
- Use squash merge when merging release → main

**Benefits:**
- Main has clean history (one commit per feature)
- Detailed history preserved in feature/release branches
- Easy to generate changelogs from main
- Simpler code review of what shipped

**Keep branches 30-60 days** after merge to preserve detailed history for debugging, then auto-delete.

---

This strategy provides the independent feature releases your team needs while respecting every constraint you specified—no cherry-picking, no feature flags, and a workflow simple enough that inexperienced developers can follow it with automated guardrails preventing mistakes. The regular syncing of main into feature branches ensures conflicts are caught early and features stay current with production code.