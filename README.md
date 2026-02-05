# Git Branching Strategy Demo

This repository demonstrates the **Release Branch Isolation Strategy** for microservices.

## Branch Structure

- `main` - Production (source of truth)
- `staging` - Pre-production UAT testing
- `dev` - Expendable integration sandbox

## Workflow

1. Features start from `main` (not dev!)
2. Merge to `dev` for integration testing
3. Create release branch from feature branch
4. Deploy release to staging for UAT
5. Merge release to main for production
6. Sync main back to dev
