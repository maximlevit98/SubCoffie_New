#!/bin/bash

# 💾 Quick Save to Git
# Быстрое сохранение изменений в Git репозиторий

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Quick Save to Git Repository                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if in git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Error: Not a git repository${NC}"
    exit 1
fi

# Check for changes
if git diff-index --quiet HEAD --; then
    echo -e "${GREEN}✅ No changes to commit. Working tree is clean!${NC}"
    echo ""
    echo "Last commit:"
    git log -1 --oneline
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Changes detected:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
git status --short
echo ""

# Ask for commit message
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💬 Enter commit message:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Examples:"
echo "  • feat: добавил новую функцию заказа кофе"
echo "  • fix: исправил баг с оплатой"
echo "  • docs: обновил документацию"
echo "  • refactor: улучшил код авторизации"
echo ""
read -p "Commit message: " COMMIT_MSG

if [ -z "$COMMIT_MSG" ]; then
    echo -e "${RED}❌ Error: Commit message cannot be empty${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Saving changes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Add all changes
echo "1️⃣  Adding files..."
git add .
echo -e "${GREEN}✅ Files added${NC}"
echo ""

# Commit
echo "2️⃣  Creating commit..."
git commit -m "$COMMIT_MSG"
echo -e "${GREEN}✅ Commit created${NC}"
echo ""

# Ask about push
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Push to GitHub now? (Y/n): " -n 1 -r
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "3️⃣  Pushing to GitHub..."
    
    CURRENT_BRANCH=$(git branch --show-current)
    
    if git push origin "$CURRENT_BRANCH"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}🎉 SUCCESS! Changes saved and pushed to GitHub!${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "View at: ${BLUE}https://github.com/maximlevit98/SubCoffie_New${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}❌ Push failed${NC}"
        echo "Changes are saved locally. Try pushing manually:"
        echo "  git push origin $CURRENT_BRANCH"
        exit 1
    fi
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ Changes saved locally${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To push later, run:"
    echo "  git push origin $CURRENT_BRANCH"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Repository Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total commits: $(git rev-list --count HEAD)"
echo "Current branch: $CURRENT_BRANCH"
echo "Last 3 commits:"
git log -3 --oneline
echo ""
echo "Made with ☕ and ❤️"
echo ""
