# Branch Protection Setup

Configure these settings in GitHub to enforce the Release Branch Isolation strategy.

## Prerequisites

- GitHub repository with `main` and `staging` branches
- Admin access to the repository
- **Note:** Branch protection on private repos requires GitHub Team plan or higher

---

## Quick Setup via CLI

Use the GitHub CLI to configure branch protection rules automatically.

### 1. Configure Workflow Permissions

```bash
# Enable read-write permissions for GitHub Actions
gh api repos/{owner}/{repo}/actions/permissions/workflow \
  --method PUT \
  --field default_workflow_permissions=write \
  --field can_approve_pull_request_reviews=true
```

### 2. Protect `main` Branch

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"checks":[{"context":"validate-pr"},{"context":"validate-title"},{"context":"validate-commits"},{"context":"validate-branch-name"}]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field required_conversation_resolution=true
```

### 3. Protect `staging` Branch

```bash
gh api repos/{owner}/{repo}/branches/staging/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"checks":[{"context":"validate-pr"},{"context":"validate-branch-name"}]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false
```

### 4. Create Labels

```bash
# Create skip-staging label (orange)
gh label create "skip-staging" --description "PR skipped staging environment" --color "FFA500" --force

# Create sync-conflict label (red)
gh label create "sync-conflict" --description "Sync conflict requires manual resolution" --color "FF0000" --force

# Create urgent label (red)
gh label create "urgent" --description "Requires immediate attention" --color "FF0000" --force
```

### 5. Configure Merge Settings (Squash-only for main)

This must be done via the UI:
1. Go to **Settings** → **General** → **Pull Requests**
2. Uncheck "Allow merge commits"
3. Check "Allow squash merging" ✓
4. Uncheck "Allow rebase merging"
5. Check "Always suggest updating pull request branches" ✓
6. Check "Automatically delete head branches" ✓

---

## Manual Setup via GitHub UI

### 1. Configure GitHub Actions Workflow Permissions

1. Go to your repository on GitHub
2. Click **Settings** → **Actions** → **General**
3. Scroll to **Workflow permissions** section
4. Select **"Read and write permissions"**
5. Check **"Allow GitHub Actions to create and approve pull requests"**
6. Click **Save**

### 2. Protect `main` Branch

1. Go to **Settings** → **Branches**
2. Under "Branch protection rules", click **Add rule**
3. Pattern: `main`

**Required settings:**

- [x] **Require a pull request before merging**
  - [x] Require approvals: `1`
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require approval of the most recent reviewable push

- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - Add required checks:
    - `validate-pr` (branch enforcement)
    - `validate-title` (PR title has [major|minor|patch])
    - `validate-commits` (conventional commits)
    - `validate-branch-name` (CU-{task_id} naming)

- [x] **Require conversation resolution before merging**

- [x] **Do not allow bypassing the above settings**

- [ ] **Allow force pushes** — Keep UNCHECKED
- [ ] **Allow deletions** — Keep UNCHECKED

### 3. Protect `staging` Branch

1. Pattern: `staging`

**Required settings:**

- [x] **Require a pull request before merging**
  - [x] Require approvals: `1`
  - [x] Dismiss stale pull request approvals when new commits are pushed

- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - Add required checks:
    - `validate-pr`
    - `validate-branch-name`

- [ ] **Do not allow bypassing** — Keep UNCHECKED (allows sync workflow)
- [ ] **Allow force pushes** — Keep UNCHECKED
- [ ] **Allow deletions** — Keep UNCHECKED

### 4. Configure Merge Settings

1. Go to **Settings** → **General**
2. Scroll to **Pull Requests** section
3. Configure:
   - [ ] Allow merge commits — UNCHECKED
   - [x] Allow squash merging — CHECKED
   - [ ] Allow rebase merging — UNCHECKED
   - [x] Always suggest updating pull request branches
   - [x] Automatically delete head branches

This enforces squash merging on all PRs, keeping `main` history clean.

### 5. Create Labels

1. Go to **Issues** → **Labels**
2. Create these labels:

| Name | Description | Color |
|------|-------------|-------|
| `skip-staging` | PR skipped staging environment | `#FFA500` (orange) |
| `sync-conflict` | Sync conflict requires manual resolution | `#FF0000` (red) |
| `urgent` | Requires immediate attention | `#FF0000` (red) |

---

## GitHub Actions Workflows

The following workflows enforce rules server-side:

| Workflow | File | What it validates |
|----------|------|-------------------|
| Branch Enforcement | `branch-enforcement.yml` | Only release/hotfix can PR to main/staging; validates branch naming |
| Validate PR Title | `validate-pr-title.yml` | PR title starts with `[major\|minor\|patch]` |
| Validate Commits | `validate-commits.yml` | Conventional commit format on release/hotfix |
| Auto-tag Release | `auto-tag-release.yml` | Creates version tag after merge to main |
| Sync Staging | `sync-staging.yml` | Syncs main → staging after merges |
| Fix PR Target | `fix-pr-target.yml` | Reminds if release skipped staging |
| Cleanup Stale Branches | `cleanup-stale-branches.yml` | Weekly cleanup of old branches |

---

## Verification

After setup, verify the protection rules work:

### Test 1: Direct Push to Main (Should Fail)

```bash
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "test: direct push"
git push origin main
# Expected: Rejected by GitHub branch protection
```

### Test 2: Feature PR to Main (Should Fail)

1. Create a feature branch and push
2. Try to create a PR from `feature/*` to `main`
3. The `branch-enforcement` workflow should fail

### Test 3: PR Without Bump Prefix (Should Fail)

1. Create a release branch
2. Create a PR to `main` without `[major|minor|patch]` in title
3. The `validate-title` workflow should fail

### Test 4: Invalid Branch Name (Should Fail)

1. Create a branch without CU- prefix: `release/my-feature`
2. Try to create a PR to `staging`
3. The `branch-enforcement` workflow's `validate-branch-name` job should fail

### Test 5: Release PR to Main (Should Pass)

1. Create release: `pnpm run git:feature abc123 my-feature && pnpm run git:release`
2. Push and PR to staging with merge commit
3. Then `pnpm run git:ship minor`
4. PR title should be `[minor] feat(CU-abc123): ...`
5. All workflows should pass

---

## Enforcement Summary

| Rule | Local (Husky) | GitHub Actions | Branch Protection |
|------|---------------|----------------|-------------------|
| Branch naming (CU-{task_id}) | `pre-push` **BLOCKS** | `branch-enforcement.yml` | — |
| No direct push to main/staging | `pre-push` **BLOCKS** | — | Require PR |
| Only release/hotfix → main/staging | `pre-merge-commit` **BLOCKS** | `branch-enforcement.yml` **BLOCKS** | — |
| Conventional commits | `commit-msg` **BLOCKS** | `validate-commits.yml` | — |
| `[major\|minor\|patch]` in PR title | — | `validate-pr-title.yml` | Required check |
| Squash merge to main | — | — | Merge settings |
| Auto-version tag | — | `auto-tag-release.yml` | — |
| Auto-sync staging | — | `sync-staging.yml` | — |

---

## Troubleshooting

### "Status check not found"

Status checks only appear after the workflow runs once. Create a test PR to trigger the workflows, then configure branch protection.

### "Sync workflow can't push to staging"

1. Check workflow permissions in repository settings
2. Ensure "Do not allow bypassing" is unchecked for staging
3. Consider using a PAT with `repo` scope for elevated permissions

### "PR merged without squash"

Verify merge settings in **Settings** → **General** → **Pull Requests**. Only "Allow squash merging" should be checked.

### "Commits not validated"

The `validate-commits.yml` workflow only runs on `release/*` and `hotfix/*` branches. Feature branch commits are intentionally not validated server-side.

---

## Advanced: Strict Security Setup

For teams requiring stricter security:

### Use GitHub App for Automation

1. Create a GitHub App with:
   - Repository permissions: Contents (write), Pull requests (write)
2. Install the app on your repository
3. Generate a private key and store as `APP_PRIVATE_KEY` secret
4. Update workflows to use app token instead of `GITHUB_TOKEN`

### CODEOWNERS

Create `.github/CODEOWNERS`:

```
# Default owners
* @your-team

# Workflow files require devops review
/.github/ @devops-team

# Sensitive paths
/config/ @security-team
```

### Required Reviewers by Path

Enable "Require review from Code Owners" in branch protection to enforce CODEOWNERS.
