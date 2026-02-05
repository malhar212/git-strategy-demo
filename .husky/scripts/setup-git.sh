#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Git Repository Setup Script${NC}"
echo -e "${BLUE}  Release Branch Isolation Strategy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
  echo -e "${YELLOW}No .git folder found. Initializing fresh repository...${NC}"
else
  echo -e "${RED}WARNING: This script will DELETE the existing .git folder!${NC}"
  echo -e "${RED}This action is IRREVERSIBLE and will destroy all git history.${NC}"
  echo ""
  read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

  if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 1
  fi

  echo ""
  echo -e "${YELLOW}Removing existing .git folder...${NC}"
  rm -rf .git
fi

# Initialize new repository
echo -e "${GREEN}Initializing new git repository...${NC}"
git init

# Create initial commit
echo -e "${GREEN}Creating initial commit...${NC}"
git add .
git commit -m "chore: initial commit - Release Branch Isolation setup"

# Create staging branch
echo -e "${GREEN}Creating staging branch...${NC}"
git checkout -b staging
git checkout main

echo ""
echo -e "${GREEN}Local repository setup complete!${NC}"
echo ""
echo -e "${BLUE}Branches created:${NC}"
echo "  - main (default)"
echo "  - staging"
echo ""

# Remote setup
REMOTE_URL="git@github.com:malhar212/git-strategy-demo.git"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Remote Repository Setup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "This script will push to: ${BLUE}${REMOTE_URL}${NC}"
echo ""
echo -e "${RED}WARNING: This will FORCE PUSH to the remote repository!${NC}"
echo -e "${RED}All existing remote history will be replaced.${NC}"
echo ""
read -p "Do you want to set up the remote and force push? (type 'yes' to confirm): " remote_confirm

if [ "$remote_confirm" = "yes" ]; then
  echo ""
  echo -e "${GREEN}Adding remote origin...${NC}"
  git remote add origin "$REMOTE_URL" 2>/dev/null || git remote set-url origin "$REMOTE_URL"

  echo -e "${GREEN}Force pushing main branch...${NC}"
  git push -u origin main --force

  echo -e "${GREEN}Force pushing staging branch...${NC}"
  git push -u origin staging --force

  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Setup Complete!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo -e "Repository: ${BLUE}${REMOTE_URL}${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. Configure branch protection rules in GitHub"
  echo "     See: BRANCH_PROTECTION_SETUP.md"
  echo ""
  echo "  2. Start your first feature:"
  echo "     pnpm run git:feature TICKET-1 my-feature"
  echo ""
else
  echo ""
  echo -e "${YELLOW}Skipped remote setup.${NC}"
  echo ""
  echo -e "To manually set up the remote later:"
  echo "  git remote add origin $REMOTE_URL"
  echo "  git push -u origin main --force"
  echo "  git push -u origin staging --force"
  echo ""
fi
