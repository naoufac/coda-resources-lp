#!/bin/bash
# =============================================================================
# Script: create-branches.sh
# Purpose: Create 5 separate Git branches for Cloudflare Pages deployments
# 
# Each branch contains ONLY the files needed for its specific landing page.
# After running this script, connect each branch to a Cloudflare Pages project.
#
# Usage: 
#   git clone <repo-url>
#   cd <repo>
#   bash create-branches.sh
#   git push origin lp-plumbing lp-hvac lp-fire-protection lp-mexico lp-europe
# =============================================================================

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "ERROR: Not inside a git repository"
    exit 1
fi

# Check landing-pages directory exists
if [ ! -d "$REPO_ROOT/landing-pages" ]; then
    echo "ERROR: landing-pages/ directory not found. Run from repo root."
    exit 1
fi

create_branch() {
    local branch_name="$1"
    local lp_dir="$2"
    
    echo ""
    echo "============================================"
    echo "Creating branch: $branch_name"
    echo "Source: $lp_dir"
    echo "============================================"
    
    # Check if the LP directory exists
    if [ ! -d "$REPO_ROOT/landing-pages/$lp_dir" ]; then
        echo "ERROR: landing-pages/$lp_dir not found"
        return 1
    fi
    
    # Create orphan branch (no history, clean start)
    git checkout --orphan "$branch_name"
    
    # Remove all files from staging
    git rm -rf --cached . > /dev/null 2>&1 || true
    
    # Clean the working directory (except .git and landing-pages)
    find . -maxdepth 1 ! -name '.git' ! -name 'landing-pages' ! -name '.' -exec rm -rf {} +
    
    # Copy LP files to root
    cp -r "$REPO_ROOT/landing-pages/$lp_dir"/* .
    
    # Remove landing-pages from this branch
    rm -rf landing-pages
    
    # Add .gitignore
    echo ".DS_Store" > .gitignore
    echo "*.swp" >> .gitignore
    echo ".env" >> .gitignore
    
    # Stage and commit
    git add -A
    git commit -m "Initial deploy: $branch_name landing page

Contains only the files needed for the $lp_dir landing page.
Entry point: index.html
Assets: css/, images/, js/, videos/, fonts/"
    
    echo "✅ Branch '$branch_name' created successfully"
    echo "   Files: $(git ls-files | wc -l)"
    echo ""
}

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)

# Store the landing-pages in a temp location so they survive branch switches
TEMP_DIR=$(mktemp -d)
cp -r "$REPO_ROOT/landing-pages" "$TEMP_DIR/"

echo "============================================"
echo "Creating 5 landing page branches"
echo "============================================"

# Create each branch
# Branch 1: lp-plumbing (domains: plumbing-fittings.asia, malleable-iron.asia, malleableironfittings.asia)
create_branch "lp-plumbing" "lp-plumbing"

# Restore landing-pages for next branch
cp -r "$TEMP_DIR/landing-pages" "$REPO_ROOT/"

# Branch 2: lp-hvac (domains: hvac-fittings.com)
create_branch "lp-hvac" "lp-hvac"

cp -r "$TEMP_DIR/landing-pages" "$REPO_ROOT/"

# Branch 3: lp-fire-protection (domains: galvanized-fittings.com, galvanized-fittings.asia)
create_branch "lp-fire-protection" "lp-fire-protection"

cp -r "$TEMP_DIR/landing-pages" "$REPO_ROOT/"

# Branch 4: lp-mexico (domains: pipe-fittings.mx, iron-fittings.mx)
create_branch "lp-mexico" "lp-mexico"

cp -r "$TEMP_DIR/landing-pages" "$REPO_ROOT/"

# Branch 5: lp-europe (domains: pipe-fittings.eu)
create_branch "lp-europe" "lp-europe"

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Return to original branch
git checkout "$CURRENT_BRANCH" 2>/dev/null || git checkout main 2>/dev/null || true

echo ""
echo "============================================"
echo "✅ ALL 5 BRANCHES CREATED SUCCESSFULLY"
echo "============================================"
echo ""
echo "Branches created:"
echo "  • lp-plumbing        → plumbing-fittings.asia, malleable-iron.asia, malleableironfittings.asia"
echo "  • lp-hvac            → hvac-fittings.com"
echo "  • lp-fire-protection → galvanized-fittings.com, galvanized-fittings.asia"
echo "  • lp-mexico          → pipe-fittings.mx, iron-fittings.mx"
echo "  • lp-europe          → pipe-fittings.eu"
echo ""
echo "Next steps:"
echo "  1. Push all branches:  git push origin lp-plumbing lp-hvac lp-fire-protection lp-mexico lp-europe"
echo "  2. Create Cloudflare Pages projects (see CLOUDFLARE-SETUP.md)"
echo ""
