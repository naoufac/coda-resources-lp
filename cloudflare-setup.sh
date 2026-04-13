#!/bin/bash
# =============================================================================
# Cloudflare Pages & Redirect Setup via API
# =============================================================================
#
# This script automates:
# 1. Creating 5 Cloudflare Pages projects (one per landing page branch)
# 2. Attaching custom domains to each project
# 3. Setting up 301 redirect rules for 5 domains → codaresources-vietnam.com
#
# Prerequisites:
#   - Cloudflare API Token with permissions:
#       • Account > Cloudflare Pages > Edit
#       • Zone > Zone > Read
#       • Zone > DNS > Edit
#       • Zone > Page Rules > Edit  (or Rules > Edit)
#   - The GitHub repo connected to Cloudflare (or provide repo details)
#   - All 17 domains already active in Cloudflare
#
# Usage:
#   export CF_API_TOKEN="your-cloudflare-api-token"
#   export CF_ACCOUNT_ID="your-account-id"
#   export GITHUB_REPO_OWNER="naoufac"
#   export GITHUB_REPO_NAME="coda"
#   bash cloudflare-setup.sh
#
# To find your Account ID:
#   Cloudflare Dashboard → any domain → Overview → right sidebar → "Account ID"
#
# To create an API Token:
#   Cloudflare Dashboard → My Profile → API Tokens → Create Token
#   Use "Edit Cloudflare Workers" template + add Zone DNS + Zone Page Rules
# =============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

CF_API_TOKEN="${CF_API_TOKEN:?Set CF_API_TOKEN environment variable}"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:?Set CF_ACCOUNT_ID environment variable}"
GITHUB_REPO_OWNER="${GITHUB_REPO_OWNER:-naoufac}"
GITHUB_REPO_NAME="${GITHUB_REPO_NAME:-coda}"

API_BASE="https://api.cloudflare.com/client/v4"

# Landing pages: project_name | branch | domains (space-separated)
declare -a LP_PROJECTS=(
  "coda-lp-plumbing|lp-plumbing|plumbing-fittings.asia malleable-iron.asia malleableironfittings.asia"
  "coda-lp-hvac|lp-hvac|hvac-fittings.com"
  "coda-lp-fire-protection|lp-fire-protection|galvanized-fittings.com galvanized-fittings.asia"
  "coda-lp-mexico|lp-mexico|pipe-fittings.mx iron-fittings.mx"
  "coda-lp-europe|lp-europe|pipe-fittings.eu"
)

# Domains for 301 redirect → codaresources-vietnam.com
declare -a REDIRECT_DOMAINS=(
  "iron-fittings.com"
  "iron-fittings.asia"
  "pipe-fittings.asia"
  "pipe-nipple.asia"
  "press-fittings.asia"
)

REDIRECT_TARGET="https://codaresources-vietnam.com"

# ─── Helper Functions ─────────────────────────────────────────────────────────

cf_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  
  local args=(-s -X "$method" -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json")
  
  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi
  
  curl "${args[@]}" "${API_BASE}${endpoint}"
}

check_success() {
  local response="$1"
  local context="$2"
  
  local success
  success=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
  
  if [ "$success" = "True" ]; then
    echo "  ✅ $context"
    return 0
  else
    local errors
    errors=$(echo "$response" | python3 -c "import sys,json; errs=json.load(sys.stdin).get('errors',[]); print('; '.join([e.get('message','') for e in errs]))" 2>/dev/null || echo "Unknown error")
    echo "  ❌ $context: $errors"
    return 1
  fi
}

get_zone_id() {
  local domain="$1"
  local response
  response=$(cf_api GET "/zones?name=$domain&status=active")
  echo "$response" | python3 -c "import sys,json; zones=json.load(sys.stdin)['result']; print(zones[0]['id'] if zones else '')" 2>/dev/null
}

# ─── Step 1: Create Cloudflare Pages Projects ────────────────────────────────

echo ""
echo "============================================"
echo "Step 1: Creating Cloudflare Pages Projects"
echo "============================================"

for project_config in "${LP_PROJECTS[@]}"; do
  IFS='|' read -r project_name branch domains <<< "$project_config"
  
  echo ""
  echo "--- Creating project: $project_name (branch: $branch) ---"
  
  payload=$(cat <<EOF
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
EOF
)
  
  response=$(cf_api POST "/accounts/$CF_ACCOUNT_ID/pages/projects" "$payload")
  check_success "$response" "Project $project_name created" || true
done

echo ""
echo "⏳ Waiting 10 seconds for projects to initialize..."
sleep 10

# ─── Step 2: Attach Custom Domains ───────────────────────────────────────────

echo ""
echo "============================================"
echo "Step 2: Attaching Custom Domains"
echo "============================================"

for project_config in "${LP_PROJECTS[@]}"; do
  IFS='|' read -r project_name branch domains <<< "$project_config"
  
  echo ""
  echo "--- Domains for $project_name ---"
  
  for domain in $domains; do
    echo "  Adding domain: $domain"
    
    payload="{\"name\": \"$domain\"}"
    response=$(cf_api POST "/accounts/$CF_ACCOUNT_ID/pages/projects/$project_name/domains" "$payload")
    check_success "$response" "$domain → $project_name" || true
  done
done

# ─── Step 3: Set Up 301 Redirects ────────────────────────────────────────────

echo ""
echo "============================================"
echo "Step 3: Setting Up 301 Redirects"
echo "============================================"

for domain in "${REDIRECT_DOMAINS[@]}"; do
  echo ""
  echo "--- Setting up redirect: $domain → $REDIRECT_TARGET ---"
  
  # Get zone ID for this domain
  zone_id=$(get_zone_id "$domain")
  
  if [ -z "$zone_id" ]; then
    echo "  ❌ Zone not found for $domain (is it active in Cloudflare?)"
    continue
  fi
  
  echo "  Zone ID: $zone_id"
  
  # Create a redirect rule (Single Redirects / Dynamic Redirects)
  # Using the Rulesets API for redirect rules
  
  # First, check if a redirect ruleset exists
  rulesets_response=$(cf_api GET "/zones/$zone_id/rulesets")
  
  # Find the http_request_dynamic_redirect phase ruleset or create one
  ruleset_id=$(echo "$rulesets_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
rulesets = data.get('result', [])
for rs in rulesets:
    if rs.get('phase') == 'http_request_dynamic_redirect':
        print(rs['id'])
        break
" 2>/dev/null || echo "")
  
  redirect_rule_payload=$(cat <<EOF
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
EOF
)
  
  if [ -n "$ruleset_id" ]; then
    # Update existing ruleset
    response=$(cf_api PUT "/zones/$zone_id/rulesets/$ruleset_id" "$redirect_rule_payload")
  else
    # Create new ruleset for this phase
    create_payload=$(cat <<EOF
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
EOF
)
    response=$(cf_api POST "/zones/$zone_id/rulesets" "$create_payload")
  fi
  
  check_success "$response" "Redirect rule for $domain" || true
done

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "============================================"
echo "✅ SETUP COMPLETE"
echo "============================================"
echo ""
echo "Pages Projects Created:"
for project_config in "${LP_PROJECTS[@]}"; do
  IFS='|' read -r project_name branch domains <<< "$project_config"
  echo "  • $project_name ($branch) → $domains"
done
echo ""
echo "301 Redirects Configured:"
for domain in "${REDIRECT_DOMAINS[@]}"; do
  echo "  • $domain → $REDIRECT_TARGET"
done
echo ""
echo "Pending Domains (manual setup needed):"
echo "  • groovedfittings.asia → likely fire-protection LP"
echo "  • iron-oem.asia → likely redirect to $REDIRECT_TARGET/solutions/contract-manufacturer"
echo ""
echo "Next: Verify each domain is resolving correctly."
echo "  DNS propagation may take a few minutes."
echo ""
