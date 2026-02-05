# Pitfalls & Troubleshooting Guide

This document covers common issues, gotchas, and their solutions for the **Release Branch Isolation Strategy**.

## Table of Contents

1. [Setup Issues](#setup-issues)
2. [Workflow Failures](#workflow-failures)
3. [Hook Failures](#hook-failures)
4. [Merge Conflicts](#merge-conflicts)
5. [Permission Issues](#permission-issues)
6. [Status Check Issues](#status-check-issues)
7. [Known Gotchas](#known-gotchas)
8. [Recovery Scenarios](#recovery-scenarios)

---

## Setup Issues

### Problem: Missing Node.js or pnpm

**Symptom**: Commands like `pnpm run git:feature` fail with "command not found"

**Solution**:
```bash
# Check Node.js version (need 16+)
node --version

# Check pnpm is installed
pnpm --version

# Install Node.js (see https://nodejs.org/)
# Then install pnpm:
npm install -g pnpm

# Verify installation
pnpm --version
```

### Problem: Husky hooks not installed

**Symptom**: `pre-push` hook doesn't prevent direct pushes to main/staging

**Solution**:
```bash
# Install dependencies (this runs husky prepare)
pnpm install

# Verify hooks are executable
ls -la .husky/
# You should see: pre-push, commit-msg, pre-merge-commit

# If hooks are missing, reinstall
pnpm install husky --save-dev
npx husky install
```

**Root Cause**: Husky's `prepare` script runs during `pnpm install`. If you cloned without running install, hooks won't be present.

### Problem: GitHub CLI not authenticated

**Symptom**: Workflows fail with "authentication required" or GitHub Actions can't push

**Solution**:
```bash
# Check GitHub CLI authentication
gh auth status

# If not authenticated, log in
gh auth login

# Choose: HTTPS or SSH (SSH is recommended)
# Verify authentication worked
gh auth status
```

### Problem: SSH key not configured

**Symptom**: `git push` fails with "Permission denied (publickey)"

**Solution**:
```bash
# Generate SSH key (if not present)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add private key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard
cat ~/.ssh/id_ed25519.pub | pbcopy

# Go to GitHub Settings > SSH and GPG keys > New SSH key
# Paste the key

# Test connection
ssh -T git@github.com
# Should print: "Hi username! You've successfully authenticated..."
```

### Problem: GitHub plan doesn't support private repo branch protection

**Symptom**: Branch protection rules don't appear in settings or fail to apply

**Solution**:
Branch protection requires a GitHub Team plan (paid). If on free plan:
- Downgrade to public repository (make repo public)
- OR upgrade GitHub account to Team plan
- Branch protection is available only on paid GitHub plans

This is a GitHub limitation, not a strategy issue.

### Problem: Setup script fails with "pathspec 'main' did not match"

**Symptom**: Running `pnpm run git:setup` fails with error:
```
error: pathspec 'main' did not match any file(s) known to git
ELIFECYCLE  Command failed with exit code 1.
```

**Root Cause**: Git's default branch name is `master` (pre-Git 3.0), but our scripts expect `main`. When `git init` runs without the `-b main` flag, it creates a `master` branch instead.

**Solution**:
```bash
# If the setup script failed, you're likely on the staging branch with master as the other branch
# Check current state:
git branch -a

# Rename master to main:
git checkout master
git branch -m master main

# Continue with remote setup manually if needed:
git remote add origin git@github.com:username/repo-name.git
git push -u origin main --force
git push -u origin staging --force
```

**Prevention**: The setup script has been updated to use `git init -b main` which explicitly creates `main` as the initial branch name. If you still encounter this:
```bash
# Configure git globally to use main as default
git config --global init.defaultBranch main
```

**Note**: This was a real issue encountered during setup (Feb 2026).

---

### Problem: Setup script fails to push to remote

**Symptom**: `pnpm run git:setup` completes locally but fails during remote push

**Causes & Solutions**:

1. **Remote doesn't exist yet**
   ```bash
   # Create repository on GitHub first, then run setup
   # OR add remote manually
   git remote add origin git@github.com:username/repo-name.git
   git push -u origin main --force
   ```

2. **No permission to push**
   ```bash
   # Check SSH key is configured (see SSH key section above)
   ssh -T git@github.com

   # Check you have push permissions on the repo
   # (You should be the owner or have write access)
   ```

3. **Remote URL is wrong**
   ```bash
   # Check current remote
   git remote -v

   # Update if needed
   git remote set-url origin git@github.com:username/repo-name.git

   # Verify setup script hardcoded URL matches your repo
   # Edit: .husky/scripts/setup-git.sh line 59
   REMOTE_URL="git@github.com:malhar212/git-strategy-demo.git"
   # Change to your actual repo URL
   ```

---

## Workflow Failures

### Problem: Status checks don't appear in PR

**Symptom**: PR shows "Waiting for status checks" but no checks appear in the list

**Solution**:
This is normal! GitHub Actions workflows don't appear in the status checks dropdown until they run at least once.

**What to do**:
1. Create a simple test PR (feature branch → staging)
2. Let all workflows run once
3. After first run, status checks will appear in future PRs

**Verify workflows exist**:
```bash
# List workflows
gh workflow list

# Or check GitHub UI: Settings > Actions > All workflows
```

### Problem: Sync workflow fails with merge conflict

**Symptom**: After merging to main, the automatic sync from main → staging fails

**Details**: The `sync-staging.yml` workflow creates a GitHub Issue when this happens.

**Solution**:
1. Go to the repo's Issues tab
2. Find issue titled "🔴 Manual sync required: main → staging conflict"
3. Follow the commands in the issue:
   ```bash
   git checkout staging
   git pull origin staging
   git merge origin/main --no-ff
   # Resolve conflicts in your editor
   git add .
   git commit
   git push origin staging
   ```

**Prevention**: Keep main and staging in sync regularly. Don't make changes directly to staging.

### Problem: Auto-tag workflow fails with "Missing write permissions"

**Symptom**: PR merges successfully but tag is not created

**Root Cause**: GitHub Actions doesn't have `contents: write` permission

**Solution**:
Check `.github/workflows/auto-tag-release.yml`:
```yaml
permissions:
  contents: write  # This must be present
```

If missing, add it:
```yaml
jobs:
  create-tag:
    permissions:
      contents: write
    steps:
```

### Problem: Branch enforcement workflow rejects valid PR

**Symptom**: "ERROR: Only release/* and hotfix/* branches can create PRs to main"

**Possible causes**:

1. **Feature branch created directly from staging/main**
   ```bash
   # Wrong: starting from staging
   git checkout staging
   git checkout -b feature/CU-abc123-name

   # Correct: must start from main
   git checkout main
   git checkout -b feature/CU-abc123-name
   # OR use the script
   pnpm run git:feature abc123 name
   ```

2. **Branch name doesn't follow pattern**
   ```
   Valid pattern: {type}/CU-{task_id}-{description}
   - feature/CU-abc123-user-login
   - release/CU-abc123-user-login
   - hotfix/CU-abc123-critical-fix

   Invalid: (will fail)
   - feature/user-login (missing task ID)
   - feature/abc123-user-login (missing CU- prefix)
   - feature-abc123-user-login (missing slash)
   ```

**Solution**: Rename your branch or create a new one with correct naming:
```bash
# Rename current branch
git branch -m feature/CU-abc123-user-login

# Or create new branch with correct name and delete old one
git checkout -b feature/CU-abc123-user-login
git push -u origin feature/CU-abc123-user-login
git push origin --delete old-branch-name
```

### Problem: Validate PR title fails

**Symptom**: PR to main blocked with "PR title must start with [major], [minor], or [patch]"

**Cause**: The branch enforcement workflow requires proper semver prefix

**Solution**: Update PR title to include semver bump type:

```
WRONG:
- feat(CU-123): add login
- fix(CU-456): resolve bug

CORRECT:
- [minor] feat(CU-123): add login
- [patch] fix(CU-456): resolve bug
- [major] feat(CU-789): breaking changes
```

**Examples**:
```
✓ [minor] feat(CU-86b62v077): user authentication
✓ [patch] fix(CU-abc123def): resolve payment validation
✓ [major] feat(CU-xyz789): breaking API changes
```

---

## Hook Failures

### Problem: Pre-push hook blocks push with "Direct push to 'main' is not allowed"

**Symptom**:
```
ERROR: Direct push to 'main' is not allowed!
```

**This is expected behavior!** The strategy prevents direct pushes to main and staging.

**Solution**: Use the proper workflow instead:
```bash
# For features: Create release branch first
pnpm run git:feature abc123 my-feature
# ... make changes ...
pnpm run git:release
pnpm run git:to-staging
# ... test in staging ...
pnpm run git:ship minor

# For hotfixes: Use hotfix directly
pnpm run git:hotfix abc123 critical-fix
# ... make changes ...
pnpm run git:to-staging
# ... test ...
pnpm run git:ship patch
```

### Problem: Pre-push hook blocks push with "Invalid branch name"

**Symptom**:
```
ERROR: Invalid branch name
Expected pattern: {type}/CU-{task_id}-description
```

**Cause**: Your branch name doesn't follow the naming convention

**Solution**: Recreate the branch with correct name:
```bash
# Save your current work
git stash

# Rename branch
git branch -m feature/CU-abc123-your-feature

# Push with new name
git push -u origin feature/CU-abc123-your-feature

# Delete old branch name from remote if it exists
git push origin --delete old-branch-name
```

**Branch naming rules**:
- Must be: `{type}/CU-{task_id}-{description}`
- `type`: feature, release, or hotfix
- `task_id`: Must be alphanumeric (after CU-)
- `description`: Lowercase with hyphens, no spaces

### Problem: Commit-msg hook fails with "Invalid conventional commit format"

**Symptom**: Commit fails with commitlint error on release/hotfix branches

**Details**: Release and hotfix branches require conventional commit format

**Solution**: Fix your commit message:

```
WRONG:
git commit -m "added login feature"
git commit -m "fix bug"

CORRECT:
git commit -m "feat(CU-abc123): add user login functionality"
git commit -m "fix(CU-def456): resolve password validation bug"
```

**Format**: `type(scope): subject`

Where `type` is one of:
- `feat`: A new feature
- `fix`: A bug fix
- `chore`: Build process, dependencies, tooling
- `docs`: Documentation changes
- `style`: Code style changes (no logic change)
- `refactor`: Code refactoring
- `test`: Adding/updating tests

**Bypass (feature branches only)**:
Feature branches don't enforce commit messages, only release/hotfix/main.

### Problem: Pre-merge-commit hook blocks merge with "Only release/* and hotfix/* branches can merge"

**Symptom**:
```
ERROR: Only release/* and hotfix/* branches can merge to main
```

**Cause**: Trying to merge a feature branch directly to main/staging

**Solution**: Use the proper release workflow:

```bash
# Wrong: Direct merge attempt (blocked)
git checkout main
git merge feature/CU-abc123-name

# Correct: Create release branch first
pnpm run git:release        # From feature branch
pnpm run git:to-staging     # PR to staging
# ... test ...
pnpm run git:ship minor     # Merges via PR to main
```

---

## Merge Conflicts

### Scenario 1: Conflict during `git:sync` (main → feature)

**Symptom**: While syncing feature with main:
```
ERROR: Merge conflicts detected!
Please resolve the conflicts and then:
  1. git add <resolved-files>
  2. git commit
```

**Solution**:
```bash
# 1. See which files have conflicts
git status

# 2. Open each conflicted file in your editor
# Look for markers:
# <<<<<<< HEAD
#   your feature changes
# =======
#   main's changes
# >>>>>>>

# 3. Keep the version you want (or combine them)
# Remove conflict markers

# 4. Commit the merge
git add .
git commit -m "chore: resolve merge conflicts from main sync"

# 5. Continue with workflow
pnpm run git:release
```

**Prevention**: Sync frequently with main (daily)

### Scenario 2: Conflict during `git:sync-feature` (feature → release)

**Symptom**: While syncing feature branch into release after UAT bug fixes

**Solution**: Same as Scenario 1 - resolve conflicts and commit

### Scenario 3: Conflict during main → staging auto-sync

**Symptom**: Workflow creates GitHub Issue about sync conflict

**Root Cause**: Usually caused by:
- Direct edits to staging (which shouldn't happen)
- Conflicting changes between main and staging

**Solution**:
1. Find the auto-generated issue in GitHub
2. Follow the commands to resolve locally:
   ```bash
   git checkout staging
   git pull origin staging
   git merge origin/main --no-ff
   # Resolve conflicts
   git add .
   git commit -m "chore: resolve main-staging sync conflicts"
   git push origin staging
   ```

**Prevention**: Never make direct changes to staging. Only merge to it via:
- PRs from release branches
- Automatic sync from main

### When to abort vs. continue

**Abort merge if**:
```bash
# You want to start over
git merge --abort
```
Then fix the underlying issue and retry.

**Continue if**:
You understand the conflicts and can resolve them correctly.

---

## Permission Issues

### Problem: GitHub Actions can't create PRs

**Symptom**: Workflows fail with "insufficient permissions" when creating PRs

**Root Cause**: GITHUB_TOKEN may not have permissions

**Solution**: Check workflow permissions. For workflows that need to create PRs/issues:

```yaml
permissions:
  pull-requests: write
  issues: write
  contents: read
```

### Problem: GitHub Actions can't push to protected branches

**Symptom**: Workflow fails pushing tag with "You don't have permission"

**Solution**: Check workflow has proper permissions:

```yaml
permissions:
  contents: write  # Need this for pushing tags
```

Also ensure:
- GitHub Actions is enabled for the repo
- The GitHub Actions app has sufficient permissions
- Branch protection rules allow pushes from GitHub Actions

**Configure in GitHub**:
1. Go to Settings > Branches > Branch Protection Rules
2. For each protected branch, under "Restrict who can push":
   - Allow `github-actions` bot or any user

### Problem: User doesn't have permission to merge

**Symptom**: Can't merge PR even though you created it

**Cause**: User doesn't have write access to repo

**Solution**:
1. Go to repo Settings > Collaborators
2. Add user with "Write" or "Admin" role
3. User must accept the invitation

### Problem: Branch protection rules block legitimate operations

**Symptom**: PR can't be merged despite all checks passing

**Possible causes**:

1. **Dismiss stale reviews**
   - Go to Settings > Branches > Branch Protection Rules
   - Enable: "Dismiss stale pull request approvals when new commits are pushed"

2. **Require status checks**
   - Verify required checks match those that actually run
   - Workflows must be triggered and run at least once

3. **Require linear history (Squash merge issues)**
   - Disable "Require linear history" if you use merge commits
   - This strategy uses `--no-ff` (merge commits), not squash

**Solution**:
```bash
# Review current branch protection
gh api repos/:owner/:repo/branches/main/protection

# Update if needed via GitHub UI or gh CLI
gh api repos/:owner/:repo/branches/main/protection \
  --input protection.json
```

---

## Status Check Issues

### Problem: Status checks marked as "pending" forever

**Symptom**: Checks show as "pending" or "running" but never complete

**Possible causes**:

1. **Workflow not configured for the branch**
   ```yaml
   # Check the 'on' trigger in workflow file:
   on:
     pull_request:
       branches: [main]  # Make sure your branch is listed
   ```

2. **Workflow file has syntax error**
   - Check GitHub Actions logs
   - Go to repo > Actions tab > select workflow > see error

3. **Workflow is waiting on manual approval**
   - Some workflows may have approval gates
   - Check the Actions tab for pending approvals

**Solution**:
```bash
# View workflow runs and their status
gh workflow view workflow-name --yaml

# See recent runs
gh run list

# Check logs for errors
gh run view <run-id> --log
```

### Problem: Required checks not found in merge dropdown

**Symptom**: Status checks don't appear in the "required checks" list

**Cause**: Workflows haven't run on this branch yet

**Solution**: Create a dummy commit to trigger workflows:
```bash
# Make a trivial change
echo "test" >> test.txt
git add test.txt
git commit -m "test: trigger workflows"
git push

# Wait for workflows to complete
# Then delete the test commit
git reset --soft HEAD~1
git reset test.txt
git push --force
```

### Problem: Checks passing but PR still blocked

**Symptom**: All checks green but merge button disabled

**Cause**: May need manual approval or other branch protection rule

**Solution**: Check branch protection settings:
1. Go to Settings > Branches > Branch Protection Rules
2. Check for:
   - Require pull request reviews
   - Require status checks to pass
   - Require branches to be up to date before merging
   - Require conversation resolution

### Problem: Stale checks from previous workflow versions

**Symptom**: Old check names still appear after modifying workflow

**Cause**: GitHub caches workflow status contexts

**Solution**:
1. Go to Settings > Branch protection
2. Update required checks to remove stale ones
2. Wait 15-30 minutes for cache to clear
3. Re-run the workflow to generate fresh status

---

## Known Gotchas

### Gotcha 1: git:release does NOT sync your feature branch first

**Misconception**: Developers may assume `git:release` automatically syncs their feature branch with main before creating the release.

**What actually happens**:
1. `git:release` fetches and pulls latest main
2. Creates release branch FROM main
3. Merges feature INTO release

**The problem**: If your feature branch is out of sync with main, you may hit merge conflicts at step 3 (during release creation) instead of handling them earlier in your feature branch.

**Best practice**: Always run `git:sync` on your feature branch before `git:release`:
```bash
# On feature branch
pnpm run git:sync       # Merge main into feature, resolve conflicts here
pnpm run git:release    # Now release creation will merge cleanly
```

**Why this matters**: Resolving conflicts in your feature branch is safer - you can test that everything still works. Resolving conflicts during release creation means less time for testing before UAT.

**Note**: Discovered during workflow documentation (Feb 2026).

---

### Gotcha 2: Squash merge loses commit metadata

**Issue**: If using squash merge, commit messages with task IDs get squashed

**Why it matters**: Loses traceability to the original commits

**Solution**:
- Avoid squash merge in this strategy
- Use merge commits (--no-ff) as configured
- This preserves individual commit history

**If you accidentally squash**:
```bash
# The metadata is still in the merge commit message
# But you lose individual commit details
# PR title is what matters for tagging (contains [major|minor|patch])
```

### Gotcha 3: Setup script uses force push unnecessarily

**The problem**: The setup script prompts with scary warnings:
```
WARNING: This will FORCE PUSH to the remote repository!
All existing remote history will be replaced.
```

**Why force push is unnecessary**:
- If you're pushing to a fresh/empty remote, regular `git push` works fine
- If you're adapting an existing repo, you don't want to destroy history
- Force push (`--force`) is only needed when rewriting history (rebasing, amending)

**What you should do instead**:
```bash
# Regular push works for new branches
git push -u origin main
git push -u origin staging

# Only use --force if you intentionally rewrote history
```

**TODO - Needs Fix**: The setup script should use regular push by default and only offer force push as an explicit "nuclear option" for truly starting fresh.

**Note**: Discovered during workflow setup (Feb 2026). We successfully pushed without --force.

---

### Gotcha 4: Task ID pattern must match exactly

**Valid pattern**: `CU-[a-z0-9]+-[a-z0-9-]+`

**Examples that work**:
```
✓ feature/CU-abc123-user-login
✓ feature/CU-86b62v077-auth-fix
✓ release/CU-d3f4a2b9-complex-name
```

**Examples that fail**:
```
✗ feature/CU-ABC123-name (uppercase not allowed)
✗ feature/CU_abc123_name (underscore not allowed)
✗ feature/CU-abc_123-name (underscore in task ID)
✗ feature/TICKET-123-name (must be CU prefix)
```

**Solution**: Always use lowercase alphanumeric for task ID part

### Gotcha 5: Staging auto-syncs - don't manually merge after main merge

**Problem**: You merge to main, then manually merge main → staging

**Why it's a problem**:
1. Auto-sync workflow also tries to merge
2. Both create identical or conflicting merge commits
3. History becomes messy

**Solution**: Let the auto-sync workflow handle it
- After merging to main, wait 2-3 minutes
- Workflow automatically syncs main → staging
- Never manually push to staging (pre-push hook blocks anyway)

### Gotcha 6: Deleting branches locally after PR merge is manual

**Issue**: After PR merge, the release branch is deleted on GitHub but still exists locally

**Solution**:
```bash
# Check local branches
git branch -a

# See stale branches in remotes
git branch -r

# Fetch and prune to clean up
git fetch --prune

# Delete local branch
git branch -d release/CU-abc123-name

# Or delete multiple at once
git branch | grep "release/" | xargs git branch -d
```

**Tip**: Configure Git to auto-delete local branches on PR merge:
```bash
git config --global fetch.prune true
```

---

## Recovery Scenarios

### Scenario: How to fix a botched release

**Problem**: Merged wrong code to main or released wrong version

**If not yet released (no tag)**:
```bash
# 1. Identify the bad commit
git log --oneline main | head -20

# 2. Reset main to the commit before the bad merge
git checkout main
git reset --hard <good-commit-hash>

# 3. Force push to fix remote (⚠️ be careful!)
git push origin main --force

# 4. Create a new release with fixes
git checkout -b release/CU-fixid-fix-release
# Make fixes...
git commit -m "fix(CU-fixid): correct release"
pnpm run git:to-staging
pnpm run git:ship minor
```

**If already released (tag exists)**:
```bash
# Create hotfix instead
pnpm run git:hotfix abc123 revert-bad-release

# Fix the code
# Commit
# Create PR and merge
# This creates a new tag with bumped version

# OR delete the bad tag and re-release:
git tag -d v1.2.3
git push origin --delete v1.2.3

# Then follow the "not yet released" steps above
```

### Scenario: How to undo a bad merge

**If merge is on feature branch** (not yet released):
```bash
git checkout <feature-branch>
git reset --hard HEAD~1  # Undo last commit (the merge)
git push origin <feature-branch> --force
```

**If merge is on release branch** (not yet released):
```bash
git checkout <release-branch>
git reset --hard HEAD~1
git push origin <release-branch> --force

# Then reapply the merge when ready
git merge <feature-branch> --no-ff
git push origin <release-branch>
```

**If merge is on main** (already merged to production):
```bash
# Create hotfix to revert the changes
pnpm run git:hotfix abc123 revert-bad-code

# In the hotfix branch, revert the problematic commit:
git revert <bad-commit-hash>

# OR manually undo the changes, then:
git add .
git commit -m "fix(CU-abc123): revert bad changes"

# Continue with hotfix workflow
pnpm run git:to-staging
pnpm run git:ship patch
```

### Scenario: How to recover from a sync conflict

**During main → feature sync**:
```bash
# You're on feature branch and git:sync failed
git status  # Shows merge in progress

# Option 1: Resolve and continue
# Edit conflicted files
git add .
git commit -m "chore: resolve sync conflict"

# Option 2: Abort and try again later
git merge --abort
git pull origin main  # Try again with simple merge if --no-ff fails
```

**During main → staging auto-sync** (workflow failed):
```bash
# See the GitHub issue created by the workflow
# It gives exact commands, but basically:

git checkout staging
git pull origin staging

# Now try the merge
git merge origin/main --no-ff

# Resolve conflicts
# (Keep staging's version if you never edit staging directly)
git add .
git commit -m "chore: resolve main-staging sync"
git push origin staging
```

**Prevention**:
- Only merge to staging via PRs and auto-sync
- Never commit directly to staging
- Keep main and staging in sync regularly

### Scenario: How to restart if everything goes wrong

**Nuclear option**: Reset to a known good state

```bash
# 1. Save your current work if needed
git stash

# 2. Go to main
git checkout main

# 3. Reset to origin/main (discard all local changes)
git reset --hard origin/main

# 4. For other branches, delete and recreate
git checkout -b feature/CU-abc123-restarted origin/main

# 5. If remote is corrupted, reset that too (⚠️ destructive!)
# ONLY if you have backup or don't care about history
git push origin main --force

# 6. Start over
pnpm run git:feature abc123 new-name
```

**Better approach**:
1. Create a new feature branch from current main
2. Cherry-pick your good changes from the broken branch
   ```bash
   git checkout -b feature/CU-new-task-name origin/main
   git cherry-pick <commit-hash>
   ```
3. Proceed normally

---

## Quick Reference

### Common Commands Cheat Sheet

```bash
# Setup
pnpm run git:setup              # Initial repo setup
pnpm install                    # Install hooks

# Feature workflow
pnpm run git:feature TASK DESC  # Create feature branch
pnpm run git:sync               # Sync with main
pnpm run git:release            # Create release branch
pnpm run git:to-staging         # PR to staging
pnpm run git:ship BUMP          # Ship to main

# Hotfix workflow
pnpm run git:hotfix TASK DESC   # Create hotfix branch
pnpm run git:to-staging         # PR to staging
pnpm run git:ship BUMP          # Ship to main

# Utilities
pnpm run git:status             # Show workflow status
pnpm run git:sync-feature       # Sync feature after UAT fixes
```

### Error Quick Lookup

| Error | Root Cause | Fix |
|-------|-----------|-----|
| "Direct push to 'main' not allowed" | Trying to push directly | Use git:release then git:ship |
| "Invalid branch name" | Name doesn't match pattern | Rename to type/CU-id-name |
| "PR title must start with [major\|minor\|patch]" | Missing semver prefix | Update PR title |
| "Only release/* and hotfix/* can merge" | Wrong branch type | Use git:release first |
| "Invalid conventional commit" | Bad commit format on release | Use `type(scope): message` format |
| "Merge conflicts detected" | Conflicting changes | Edit files, git add, git commit |
| "Cannot authenticate" | No SSH/GitHub token | Configure SSH or GitHub CLI |
| "Hooks not working" | Husky not installed | Run pnpm install |

---

## Getting Help

If you encounter an issue not covered here:

1. **Check the main README**: `/Users/malharmahant/Documents/Projects/git-strategy-demo/README.md`
2. **Review the workflow file**: `.github/workflows/` for the failing workflow
3. **Check hook script**: `.husky/` for the failing hook
4. **Enable workflow debug logs**:
   ```bash
   gh run view <run-id> --log
   ```
5. **Ask team**: This is complex, team input is valuable
