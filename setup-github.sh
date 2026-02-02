#!/bin/bash

# 🚀 Quick GitHub Setup Script
# This script helps you quickly connect your local repository to GitHub

set -e

echo "🎯 Subscribe Coffee - GitHub Setup Helper"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Error: Not a git repository${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "✅ Git repository detected"
echo ""

# Check for existing remote
if git remote | grep -q "origin"; then
    echo -e "${YELLOW}⚠️  Remote 'origin' already exists:${NC}"
    git remote -v
    echo ""
    read -p "Do you want to remove it and add a new one? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote remove origin
        echo -e "${GREEN}✅ Removed old remote${NC}"
    else
        echo "Keeping existing remote. Exiting."
        exit 0
    fi
fi

# Get GitHub username
echo ""
echo "Please enter your GitHub username:"
read -p "GitHub username: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo -e "${RED}❌ Error: GitHub username cannot be empty${NC}"
    exit 1
fi

# Get repository name
echo ""
echo "Please enter the repository name (default: subscribe-coffee):"
read -p "Repository name [subscribe-coffee]: " REPO_NAME
REPO_NAME=${REPO_NAME:-subscribe-coffee}

# Choose protocol
echo ""
echo "Choose connection method:"
echo "1) HTTPS (username/password or token)"
echo "2) SSH (requires SSH key setup)"
read -p "Enter choice [1 or 2]: " PROTOCOL_CHOICE

if [ "$PROTOCOL_CHOICE" = "2" ]; then
    REMOTE_URL="git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git"
    echo ""
    echo "📝 Note: Make sure you have SSH keys set up on GitHub"
    echo "   Visit: https://github.com/settings/keys"
else
    REMOTE_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
fi

echo ""
echo "Will add remote:"
echo -e "${GREEN}${REMOTE_URL}${NC}"
echo ""

read -p "Proceed? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Add remote
echo ""
echo "Adding remote..."
git remote add origin "$REMOTE_URL"

# Ensure we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Renaming branch to 'main'..."
    git branch -M main
fi

echo -e "${GREEN}✅ Remote added successfully!${NC}"
echo ""

# Ask about pushing
echo "Do you want to push to GitHub now?"
echo -e "${YELLOW}⚠️  Make sure you've created the repository on GitHub first!${NC}"
echo "   Create it at: https://github.com/new"
echo ""
read -p "Push now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Pushing to GitHub..."
    if git push -u origin main; then
        echo ""
        echo -e "${GREEN}🎉 Success! Your code is now on GitHub!${NC}"
        echo ""
        echo "View your repository at:"
        echo "https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
    else
        echo ""
        echo -e "${RED}❌ Push failed${NC}"
        echo ""
        echo "Common reasons:"
        echo "1. Repository doesn't exist on GitHub - create it first at https://github.com/new"
        echo "2. Authentication failed - check your credentials or SSH keys"
        echo "3. Network issues - check your internet connection"
        echo ""
        echo "You can try pushing manually later with:"
        echo "  git push -u origin main"
    fi
else
    echo ""
    echo "No problem! Push later with:"
    echo "  git push -u origin main"
fi

echo ""
echo "=========================================="
echo "✅ Setup complete!"
echo ""
echo "Useful commands:"
echo "  git status              - Check repository status"
echo "  git log --oneline       - View commit history"
echo "  git remote -v           - View remote repositories"
echo "  git push origin main    - Push to GitHub"
echo ""
echo "📖 For more info, see GITHUB_SETUP.md"
echo ""
