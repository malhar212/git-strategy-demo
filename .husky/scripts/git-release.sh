#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current branch
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)

# Extract ticket ID from feature branch name
if [[ "$CURRENT_BRANCH" == feature/* ]]; then
  # Extract CU-{task_id} from feature/CU-{task_id}-description
  TICKET_ID=$(echo "$CURRENT_BRANCH" | sed -n 's/feature\/\(CU-[a-z0-9]*\).*/\1/p')
  if [ -z "$TICKET_ID" ]; then
    TICKET_ID="MISC"
  fi
else
  echo -e "${RED}ERROR: This command should be run from a feature branch${NC}"
  echo ""
  echo "Current branch: $CURRENT_BRANCH"
  echo ""
  echo "Expected: feature/*"
  echo ""
  echo "If you want to create a release without a feature branch, use git:hotfix instead."
  exit 1
fi

# Derive release branch name from feature branch: feature/CU-xxx-desc -> release/CU-xxx-desc
FEATURE_SUFFIX=$(echo "$CURRENT_BRANCH" | sed 's|^feature/||')
RELEASE_BRANCH="release/${FEATURE_SUFFIX}"
FEATURE_BRANCH="$CURRENT_BRANCH"

echo -e "${BLUE}Creating release branch${NC}"
echo ""
echo -e "Feature branch: ${YELLOW}${FEATURE_BRANCH}${NC}"
echo -e "Release branch: ${YELLOW}${RELEASE_BRANCH}${NC}"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo -e "${RED}ERROR: You have uncommitted changes${NC}"
  echo ""
  echo "Please commit your changes before creating a release."
  exit 1
fi

# Fetch and update main
echo -e "${GREEN}Fetching latest from origin...${NC}"
git fetch origin

echo -e "${GREEN}Checking out main...${NC}"
git checkout main
git pull origin main

# Create release branch from main
echo -e "${GREEN}Creating release branch from main...${NC}"
git checkout -b "$RELEASE_BRANCH"

# Merge feature into release with --no-ff
echo -e "${GREEN}Merging feature branch into release (--no-ff)...${NC}"
if git merge "$FEATURE_BRANCH" --no-ff -m "feat(${TICKET_ID}): merge ${FEATURE_BRANCH} into release"; then
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Release branch created!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo -e "Release branch: ${BLUE}${RELEASE_BRANCH}${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. PR to staging for UAT:"
  echo "     pnpm run git:to-staging"
  echo ""
  echo "  2. If UAT finds bugs, fix in feature branch then sync:"
  echo "     pnpm run git:sync-feature"
  echo ""
  echo "  3. After UAT approval, ship to main:"
  echo "     pnpm run git:ship <major|minor|patch>"
  echo ""
else
  echo ""
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}  Merge conflicts detected!${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  echo -e "${YELLOW}Please resolve the conflicts and then:${NC}"
  echo "  1. git add <resolved-files>"
  echo "  2. git commit"
  echo ""
  exit 1
fi
