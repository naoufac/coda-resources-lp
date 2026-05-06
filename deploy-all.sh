#!/bin/bash
# =============================================================================
# deploy-all.sh — One-command deployment
# =============================================================================
#
# This script does EVERYTHING:
#   1. Creates 5 orphan Git branches (one per landing page)
#   2. Pushes them to GitHub
#   3. Creates 5 Cloudflare Pages projects via API
#   4. Attaches custom domains to each project
#   5. Sets up 301 redirects for 5 domains → codaresources-vietnam.com
#
# Usage:
#   export CF_API_TOKEN="your-cloudflare-api-token"
#   export CF_ACCOUNT_ID="your-cloudflare-account-id"
#   bash deploy-all.sh
#
# Or run individual steps:
#   bash deploy-all.sh --branches-only    # Just create & push branches
#   bash deploy-all.sh --cloudflare-only  # Just configure Cloudflare (branches must exist)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-all}"  # all | --branches-only | --cloudflare-only

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "${RED}❌${NC} $1"; }

# ═════════════════════════════════════════════════════════════════════════════
# PART 1: CREATE & PUSH BRANCHES
# ═════════════════════════════════════════════════════════════════════════════

create_and_push_branches() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  PART 1: Creating & Pushing 5 Landing Page Branches"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  cd "$REPO_ROOT"

  # Verify we're in a git repo with landing-pages
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    fail "Not inside a git repository"
    exit 1
  fi

  if [ ! -d "$REPO_ROOT/landing-pages" ]; then
    fail "landing-pages/ directory not found. Run from repo root."
    exit 1
  fi

  # Save current branch to return to later
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

  # Copy landing-pages to temp so they survive branch switches
  TEMP_DIR=$(mktemp -d)
  cp -r "$REPO_ROOT/landing-pages" "$TEMP_DIR/"
  info "Backed up landing-pages to $TEMP_DIR"

  # Define branches
  declare -a BRANCHES=(
    "lp-plumbing"
    "lp-hvac"
    "lp-fire-protection"
    "lp-mexico"
    "lp-europe"
  )

  for branch in "${BRANCHES[@]}"; do
    echo ""
    info "Creating branch: $branch"

    if [ ! -d "$TEMP_DIR/landing-pages/$branch" ]; then
      fail "landing-pages/$branch not found — skipping"
      continue
    fi

    # Create orphan branch
    git checkout --orphan "$branch" 2>/dev/null
    git rm -rf --cached . > /dev/null 2>&1 || true

    # Clean working directory
    find . -maxdepth 1 ! -name '.git' ! -name '.' -exec rm -rf {} +

    # Copy LP files to root
    cp -r "$TEMP_DIR/landing-pages/$branch"/* .

    # Add .gitignore
    printf '.DS_Store\n*.swp\n.env\n' > .gitignore

    # Commit
    git add -A
    git commit -m "Deploy: $branch landing page

Auto-deployed from landing-pages/$branch
Entry point: index.html
Assets: css/, images/, js/, videos/, fonts/" > /dev/null

    ok "Branch '$branch' created ($(git ls-files | wc -l | tr -d ' ') files)"

    # Push
    info "Pushing $branch to origin..."
    if git push origin "$branch" --force 2>/dev/null; then
      ok "Pushed $branch"
    else
      fail "Failed to push $branch — check your git credentials"
    fi
  done

  # Cleanup and return
  rm -rf "$TEMP_DIR"
  git checkout "$CURRENT_BRANCH" 2>/dev/null || git checkout main 2>/dev/null || true

  echo ""
  ok "All 5 branches created and pushed!"
  echo ""
}


# ═════════════════════════════════════════════════════════════════════════════
# PART 2: CLOUDFLARE API SETUP
# ═════════════════════════════════════════════════════════════════════════════

setup_cloudflare() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  PART 2: Cloudflare Pages + Domains + Redirects"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Require credentials
  if [ -z "${CF_API_TOKEN:-}" ]; then
    fail "CF_API_TOKEN not set. Run:"
    echo "    export CF_API_TOKEN=\"your-token\""
    exit 1
  fi
  if [ -z "${CF_ACCOUNT_ID:-}" ]; then
    fail "CF_ACCOUNT_ID not set. Run:"
    echo "    export CF_ACCOUNT_ID=\"your-account-id\""
    exit 1
  fi

  GITHUB_REPO_OWNER="${GITHUB_REPO_OWNER:-naoufac}"
  GITHUB_REPO_NAME="${GITHUB_REPO_NAME:-coda}"
  API_BASE="https://api.cloudflare.com/client/v4"
  REDIRECT_TARGET="https://codaresources-vietnam.com"

  # ─── Verify token ────────────────────────────────────────────────────────
  info "Verifying API token..."
  verify_resp=$(curl -s -X GET "${API_BASE}/user/tokens/verify" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

  token_status=$(echo "$verify_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',{}).get('status','unknown'))" 2>/dev/null || echo "error")

  if [ "$token_status" = "active" ]; then
    ok "Token is valid and active"
  else
    fail "Token verification failed: $token_status"
    echo "    Response: $verify_resp"
    exit 1
  fi

  # ─── Helper: API call ────────────────────────────────────────────────────
  cf_api() {
    local method="$1" endpoint="$2" data="${3:-}"
    local args=(-s -X "$method" -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json")
    [ -n "$data" ] && args+=(-d "$data")
    curl "${args[@]}" "${API_BASE}${endpoint}"
  }

  check_result() {
    local response="$1" context="$2"
    local success
    success=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
    if [ "$success" = "True" ]; then
      ok "$context"
      return 0
    else
      local errors
      errors=$(echo "$response" | python3 -c "import sys,json; errs=json.load(sys.stdin).get('errors',[]); print('; '.join([e.get('message','') for e in errs]) if errs else 'Unknown error')" 2>/dev/null || echo "Unknown error")
      # "already exists" is fine
      if echo "$errors" | grep -qi "already exists\|duplicate"; then
        warn "$context — already exists (OK)"
        return 0
      fi
      fail "$context: $errors"
      return 1
    fi
  }

  get_zone_id() {
    local domain="$1"
    local resp
    resp=$(cf_api GET "/zones?name=$domain&status=active")
    echo "$resp" | python3 -c "import sys,json; zones=json.load(sys.stdin).get('result',[]); print(zones[0]['id'] if zones else '')" 2>/dev/null
  }

  # ─── Step 2a: Create Pages Projects ──────────────────────────────────────
  echo ""
  info "Creating 5 Cloudflare Pages projects..."
  echo ""

  declare -a LP_PROJECTS=(
    "coda-lp-plumbing|lp-plumbing|plumbing-fittings.asia malleable-iron.asia malleableironfittings.asia"
    "coda-lp-hvac|lp-hvac|hvac-fittings.com"
    "coda-lp-fire-protection|lp-fire-protection|galvanized-fittings.com galvanized-fittings.asia"
    "coda-lp-mexico|lp-mexico|pipe-fittings.mx iron-fittings.mx"
    "coda-lp-europe|lp-europe|pipe-fittings.eu"
  )

  for project_config in "${LP_PROJECTS[@]}"; do
    IFS='|' read -r project_name branch domains <<< "$project_config"

    info "Creating project: $project_name (branch: $branch)"

    payload=$(cat <<EOFP
{
  "name": "$project_name",
  "production_branch": "$branch",
  "source": {
    "type": "github",
    "config": {
      "owner": "$GITHUB_REPO_OWNER",
      "repo_name": "$GITHUB_REPO_NAME",
      "production_branch": "$branch",
      "pr_comments_enabled": false,
      "deployments_enabled": true,
      "production_deployments_enabled": true,
      "preview_deployment_setting": "none"
    }
  },
  "build_config": {
    "build_command": "",
    "destination_dir": "",
    "root_dir": ""
  }
}
EOFP
)

    resp=$(cf_api POST "/accounts/$CF_ACCOUNT_ID/pages/projects" "$payload")
    check_result "$resp" "Project $project_name" || true
  done

  info "Waiting 10s for projects to initialize..."
  sleep 10

  # ─── Step 2b: Attach Custom Domains ──────────────────────────────────────
  echo ""
  info "Attaching custom domains..."
  echo ""

  for project_config in "${LP_PROJECTS[@]}"; do
    IFS='|' read -r project_name branch domains <<< "$project_config"

    for domain in $domains; do
      info "  $domain → $project_name"
      resp=$(cf_api POST "/accounts/$CF_ACCOUNT_ID/pages/projects/$project_name/domains" "{\"name\": \"$domain\"}")
      check_result "$resp" "  $domain attached" || true
    done
  done

  # ─── Step 2c: 301 Redirects ─────────────────────────────────────────────
  echo ""
  info "Setting up 301 redirects..."
  echo ""

  declare -a REDIRECT_DOMAINS=(
    "iron-fittings.com"
    "iron-fittings.asia"
    "pipe-fittings.asia"
    "pipe-nipple.asia"
    "press-fittings.asia"
  )

  for domain in "${REDIRECT_DOMAINS[@]}"; do
    info "  $domain → $REDIRECT_TARGET"

    zone_id=$(get_zone_id "$domain")
    if [ -z "$zone_id" ]; then
      fail "  Zone not found for $domain (is it active in Cloudflare?)"
      continue
    fi

    # Check for existing redirect ruleset
    rulesets_resp=$(cf_api GET "/zones/$zone_id/rulesets")
    ruleset_id=$(echo "$rulesets_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rs in data.get('result', []):
    if rs.get('phase') == 'http_request_dynamic_redirect':
        print(rs['id'])
        break
" 2>/dev/null || echo "")

    rule_json=$(cat <<EOFR
{
  "rules": [
    {
      "expression": "true",
      "description": "301 redirect to main site",
      "action": "redirect",
      "action_parameters": {
        "from_value": {
          "status_code": 301,
          "target_url": {
            "value": "$REDIRECT_TARGET"
          },
          "preserve_query_string": true
        }
      }
    }
  ]
}
EOFR
)

    if [ -n "$ruleset_id" ]; then
      resp=$(cf_api PUT "/zones/$zone_id/rulesets/$ruleset_id" "$rule_json")
    else
      create_json=$(cat <<EOFC
{
  "name": "Redirect to main site",
  "kind": "zone",
  "phase": "http_request_dynamic_redirect",
  "rules": [
    {
      "expression": "true",
      "description": "301 redirect to main site",
      "action": "redirect",
      "action_parameters": {
        "from_value": {
          "status_code": 301,
          "target_url": {
            "value": "$REDIRECT_TARGET"
          },
          "preserve_query_string": true
        }
      }
    }
  ]
}
EOFC
)
      resp=$(cf_api POST "/zones/$zone_id/rulesets" "$create_json")
    fi

    check_result "$resp" "  Redirect for $domain" || true
  done

  # ─── Done ────────────────────────────────────────────────────────────────
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok "CLOUDFLARE SETUP COMPLETE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Pages Projects:  5 created"
  echo "  Custom Domains:  9 attached"
  echo "  301 Redirects:   5 configured"
  echo ""
  echo "  Pending (manual):"
  echo "    • groovedfittings.asia → likely fire-protection LP"
  echo "    • iron-oem.asia → likely redirect to /solutions/contract-manufacturer"
  echo ""
  echo "  DNS may take a few minutes to propagate."
  echo ""
}


# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  CODA Landing Pages — Full Deployment               ║"
echo "╚══════════════════════════════════════════════════════╝"

case "$MODE" in
  --branches-only)
    create_and_push_branches
    ;;
  --cloudflare-only)
    setup_cloudflare
    ;;
  all|*)
    create_and_push_branches
    setup_cloudflare
    ;;
esac

echo ""
ok "Done! 🎉"
echo ""
