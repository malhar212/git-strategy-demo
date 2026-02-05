# Git Strategy Quick Reference

Fast lookup guide for developers familiar with the Release Branch Isolation workflow.

## Command Cheat Sheet

| Command | Purpose | Usage |
|---------|---------|-------|
| `pnpm run git:feature <id> <desc>` | Create feature branch from main | `pnpm run git:feature abc123 user-login` |
| `pnpm run git:sync` | Sync feature with main | Run from feature branch |
| `pnpm run git:release` | Create release branch from feature | Run from feature branch |
| `pnpm run git:sync-feature` | Sync release with feature updates | Run from release branch |
| `pnpm run git:to-staging` | Create PR to staging for UAT | Run from release/hotfix branch |
| `pnpm run git:ship <bump>` | Create PR to main | `pnpm run git:ship minor` |
| `pnpm run git:hotfix <id> <desc>` | Create hotfix from main | `pnpm run git:hotfix def456 fix-crash` |
| `pnpm run git:status` | Show branch status & available commands | Run anytime |
| `pnpm run git:setup` | Initialize repository | Initial setup only |

**Parameters:**
- `<id>`: ClickUp task ID (without CU- prefix; automatically added)
- `<desc>`: Description in kebab-case
- `<bump>`: One of `major`, `minor`, or `patch`

---

## Branch Naming Convention

```
feature/CU-{task_id}-{description}
release/CU-{task_id}-{description}
hotfix/CU-{task_id}-{description}
```

**Examples:**
```
feature/CU-abc123-user-authentication
release/CU-abc123-user-authentication
hotfix/CU-def456-fix-login-crash
```

---

## Commit Message Format

**Required on:** `main`, `release/*`, `hotfix/*` branches only
**Format (Conventional Commits):**

```
<type>(<scope>): <subject>
```

**Type options:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `release`
**Scope:** Optional (often the CU task ID)
**Subject:** Lowercase, no period, max 100 characters

**Examples:**
```
feat(CU-abc123): add user login functionality
fix(CU-def456): resolve null pointer in auth module
docs: update API documentation
```

---

## PR Title Format (for PRs to main)

Must include version bump indicator at the start:

```
[major] Breaking change title
[minor] New feature title
[patch] Bug fix title
```

**Examples:**
```
[minor] Add user authentication feature
[patch] Fix payment processing crash
[major] Redesign API endpoints
```

---

## Workflow Diagram

```
                    ┌─────────────┐
                    │    main     │ ◄── Source of truth
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               │               ▼
    ┌─────────────┐        │        ┌─────────────┐
    │  feature/*  │        │        │  hotfix/*   │
    └──────┬──────┘        │        └──────┬──────┘
           │               │               │
           ▼               │               ▼
    ┌─────────────┐        │
    │  release/*  │        │
    └──────┬──────┘        │
           │               │
           └───────────────┼───────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   staging   │ ◄── UAT environment
                    └─────────────┘
```

---

## Feature Flow (Standard Process)

Start feature development:
```bash
pnpm run git:feature abc123 add-login

# Develop...
git add .
git commit -m "feat(CU-abc123): implement login form"
git push origin feature/CU-abc123-add-login
```

Keep feature updated with main:
```bash
# From feature branch
pnpm run git:sync
```

Prepare for UAT:
```bash
# From feature branch
pnpm run git:release

# Now on release/CU-abc123-add-login
pnpm run git:to-staging
```

After UAT approval, ship to production:
```bash
# From release branch
pnpm run git:ship minor
```

---

## Hotfix Flow (Urgent Fixes)

Create hotfix directly from main:
```bash
pnpm run git:hotfix def456 fix-crash

# Develop fix...
git commit -m "fix(CU-def456): critical payment validation"
```

Ship directly to production (optional: via staging first):
```bash
# Optional UAT
pnpm run git:to-staging

# Ship to main
pnpm run git:ship patch
```

---

## Common Git Commands (Not Scripted)

**Development:**
```bash
git add <files>                    # Stage changes
git commit -m "message"            # Commit with message
git push origin <branch>           # Push to remote
```

**Conflict Resolution:**
```bash
git status                         # Check conflict status
git diff                          # View conflicts
git add <resolved-files>          # Stage resolved files
git commit                        # Complete merge (don't add message)
git push origin <branch>          # Push resolved merge
```

**Local Cleanup (After PR Merged):**
```bash
git checkout main && git pull
git branch -d feature/CU-xxx-desc
git branch -d release/CU-xxx-desc
```

**Viewing History:**
```bash
git log --oneline --graph                # All branches
git log --oneline main..HEAD             # Commits not in main
git log --oneline -5                     # Last 5 commits on current
```

---

## Automatic GitHub Actions (After Merge to Main)

When a PR is merged to `main`:

1. ✅ **Auto-tag:** Creates version tag (e.g., `v1.2.3`) based on PR title
2. ✅ **Auto-delete:** Removes source branch (release/hotfix)
3. ✅ **Auto-sync:** Syncs `main` → `staging` for UAT continuity

---

## Quick Troubleshooting

**"You have uncommitted changes"**
```bash
git add .
git commit -m "chore: save work"
# Then retry the command
```

**Merge conflicts during sync/release**
```bash
git status                    # See conflicted files
# Edit conflicted files manually
git add <resolved-files>
git commit                    # Don't add message
git push origin <branch>
```

**Need to check branch status anytime**
```bash
pnpm run git:status          # Shows available commands for current branch
```

**Wrong branch? (before pushing)**
```bash
git reset --soft HEAD~1      # Undo last commit, keep changes
git checkout <correct-branch>
git commit -m "message"
```

---

## Branch Rules Summary

| Branch | Source | Purpose | PR Target | Auto-Actions |
|--------|--------|---------|-----------|--------------|
| `main` | Protected | Source of truth | N/A | Tag, delete branch, sync staging |
| `feature/*` | `main` | Development | None | None |
| `release/*` | `feature/*` | UAT/Release | `staging`, then `main` | None |
| `hotfix/*` | `main` | Urgent fixes | `main` (optional via staging) | None |
| `staging` | PRs | User acceptance testing | N/A | None |

---

## Where to Find Help

- Full documentation: See `README.md` and `docs/` directory
- Script details: Check `.husky/scripts/` for implementation
- GitHub Actions: See `.github/workflows/` for automation details
- Questions? Look at git logs: `git log --oneline --graph`

---

**Last Updated:** February 2026
**Strategy:** Release Branch Isolation with Feature/Release Branching
