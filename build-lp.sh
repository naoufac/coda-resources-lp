#!/bin/bash
# ============================================================================
# CODA Resources - Landing Page Builder
# ============================================================================
# Usage: ./build-lp.sh [branch-name]
#
# Builds ALL 5 landing pages into ready-lp/ folder.
# Each LP gets its own subfolder with index.html + symlinked assets.
#
# If a branch name is passed, also creates root index.html for that branch.
#
# Output:
#   ready-lp/plumbing/index.html         → plumbing-fittings.asia
#   ready-lp/hvac/index.html             → hvac-fittings.com
#   ready-lp/fire-protection/index.html  → galvanized-fittings.com
#   ready-lp/oil-gas/index.html
#   ready-lp/water-treat/index.html
# ============================================================================

set -e

MAIN_SITE="https://www.codaresources-vietnam.com"
STATICFORMS_KEY="sf_445b8939b73ed208581d52a5"

build_lp() {
  local OUTFILE="$1"
  local SOURCE="$2"
  local TITLE="$3"
  local CANONICAL="$4"
  local OG_IMAGE="$5"
  local LP_NAME="$6"

  cp "$SOURCE" "$OUTFILE"

  # ---- PATH FIXES: ../ → ./ ----
  sed -i '' 's|\.\./css/|./css/|g' "$OUTFILE"
  sed -i '' 's|\.\./js/|./js/|g' "$OUTFILE"
  sed -i '' 's|\.\./images/|./images/|g' "$OUTFILE"
  sed -i '' 's|\.\./fonts/|./fonts/|g' "$OUTFILE"
  sed -i '' 's|\.\./videos/|./videos/|g' "$OUTFILE"

  # ---- SEO: TITLE + OG + CANONICAL ----
  python3 << PYEOF
import re

with open('$OUTFILE', 'r') as f:
    content = f.read()

# Title
content = re.sub(r'<title>[^<]*</title>', '<title>$TITLE</title>', content)

# og:title and twitter:title
clean = '$TITLE'.replace('&amp;', '&')
content = re.sub(r'<meta content="[^"]*" property="og:title">', f'<meta content="{clean}" property="og:title">', content)
content = re.sub(r'<meta content="[^"]*" property="twitter:title">', f'<meta content="{clean}" property="twitter:title">', content)

# Canonical
if 'rel="canonical"' not in content:
    content = content.replace('<meta charset="utf-8">', '<meta charset="utf-8">\n  <link rel="canonical" href="$CANONICAL">')

# og:image
if 'og:image' not in content:
    content = content.replace(
        '<meta property="og:type" content="website">',
        '<meta property="og:type" content="website">\n  <meta property="og:image" content="$OG_IMAGE">\n  <meta name="twitter:image" content="$OG_IMAGE">'
    )

# CTA: Hero mailto → #Form-title
content = content.replace(
    'href="mailto:rpalmeiro@codaresources.vn, Aferrari@codaresources.com?subject=Quote%20request%20-%20Coda%20Resources%20Vietnam"',
    'href="#Form-title"'
)

# CTA: Navbar CONTACT US → #Form-title
content = content.replace(
    '<div class="nav-button visible-mobile">\n            <a href="#" class="button small w-inline-block">',
    '<div class="nav-button visible-mobile">\n            <a href="#Form-title" class="button small w-inline-block">'
)
content = content.replace(
    '<div class="nav-button visible-mobile">\n              <a href="#" class="button small w-inline-block">',
    '<div class="nav-button visible-mobile">\n              <a href="#Form-title" class="button small w-inline-block">'
)

# CTA: Product card mailto → #Form-title
content = content.replace(
    'href="mailto:support@codaresources.vn?subject=Catalog%20request%20-%20Coda%20Resources%20Vietnam"',
    'href="#Form-title"'
)

# Cross-site links → absolute
content = content.replace('href="../certifications.html"', 'href="$MAIN_SITE/certifications" target="_blank"')
content = content.replace('href="../solutions/contract-manufacturer.html"', 'href="$MAIN_SITE/solutions/contract-manufacturer" target="_blank"')
content = content.replace('href="../solutions/product.html"', 'href="$MAIN_SITE/solutions/product" target="_blank"')

# Remove duplicate GA tag
pattern = r'  <!--  Google tag \(gtag\.js\)  -->\s*\n\s*<script async="" src="https://www\.googletagmanager\.com/gtag/js\?id=G-6R0J6870LV"></script>\s*\n\s*<script>\s*\n\s*window\.dataLayer = window\.dataLayer \|\| \[\];\s*\n\s*function gtag\(\)\{dataLayer\.push\(arguments\);\}\s*\n\s*gtag\(.*?\);\s*\n\s*gtag\(.*?\);\s*\n\s*</script>'
content = re.sub(pattern, '', content, flags=re.DOTALL)

# Schema.org: fix relative URLs
if 'application/ld+json' in content:
    content = content.replace('"url": "/industry/', '"url": "$CANONICAL/industry/')
    content = content.replace('"url": "/"', '"url": "$CANONICAL/"')
    content = content.replace('"item": "/industry/', '"item": "$CANONICAL/industry/')
    content = content.replace('"item": "/"', '"item": "$CANONICAL/"')

# Form: StaticForms.dev integration (no redirectTo — uses inline success message)
content = re.sub(
    r'<form id="email-form" name="email-form" data-name="Email Form" method="get" class="form" data-wf-page-id="[^"]*" data-wf-element-id="[^"]*">',
    '<form id="email-form" name="email-form" action="https://api.staticforms.dev/submit" method="POST" class="form">'
    + '\n              <input type="hidden" name="apiKey" value="$STATICFORMS_KEY">'
    + '\n              <input type="hidden" name="subject" value="New Lead — $LP_NAME — CODA Resources">',
    content
)

# Remove broken Webflow reCAPTCHA
content = re.sub(r'\s*<div class="w-form-formrecaptcha g-recaptcha[^"]*"></div>', '', content)

with open('$OUTFILE', 'w') as f:
    f.write(content)
PYEOF

  echo "    ✅ $OUTFILE"
}

# ============================================================================
# Build all 5 LPs into ready-lp/
# ============================================================================
echo "🚀 Building all 5 landing pages into ready-lp/"

rm -rf ready-lp
mkdir -p ready-lp/plumbing ready-lp/hvac ready-lp/fire-protection ready-lp/oil-gas ready-lp/water-treat

# Symlink shared assets into each LP folder
for LP_DIR in ready-lp/plumbing ready-lp/hvac ready-lp/fire-protection ready-lp/oil-gas ready-lp/water-treat; do
  for ASSET in css js images fonts videos; do
    ln -sf "../../$ASSET" "$LP_DIR/$ASSET"
  done
done

echo ""
echo "━━━ plumbing ━━━"
build_lp "ready-lp/plumbing/index.html" "industry-lp/plumbing.html" \
  "ISO Certified Malleable Iron Plumbing Fittings | CODA Resources" \
  "https://plumbing-fittings.asia" \
  "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png" \
  "Plumbing"

echo ""
echo "━━━ hvac ━━━"
build_lp "ready-lp/hvac/index.html" "industry-lp/hvac.html" \
  "Certified HVAC Fittings &amp; Heating Components | CODA Resources" \
  "https://hvac-fittings.com" \
  "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef04eb5636a97547c6d6c0_landscape-01.png" \
  "HVAC"

echo ""
echo "━━━ fire-protection ━━━"
build_lp "ready-lp/fire-protection/index.html" "industry-lp/fire-protection.html" \
  "FM Certified Fire Protection Fittings | CODA Resources" \
  "https://galvanized-fittings.com" \
  "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef05815636a97547c6f802_landscape-01.png" \
  "Fire Protection"

echo ""
echo "━━━ oil-gas ━━━"
build_lp "ready-lp/oil-gas/index.html" "industry-lp/oil-gas.html" \
  "Certified Fittings for Oil &amp; Gas Distribution | CODA Resources" \
  "https://oil-gas-fittings.com" \
  "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef05815636a97547c6f802_landscape-01.png" \
  "Oil &amp; Gas"

echo ""
echo "━━━ water-treat ━━━"
build_lp "ready-lp/water-treat/index.html" "industry-lp/water-treat.html" \
  "Certified Fittings for Water Treatment Systems | CODA Resources" \
  "https://water-treatment-fittings.com" \
  "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef1f8f072d1ef4cfe03fa0_41427050efaaae57a8219213dc32c317_Section.png" \
  "Water Treatment"

# ============================================================================
# Branch-specific: also build root index.html
# ============================================================================
if [ -n "$1" ]; then
  BRANCH="$1"
  echo ""
  echo "━━━ Branch deploy: $BRANCH ━━━"
  case "$BRANCH" in
    lp-plumbing)
      build_lp "index.html" "industry-lp/plumbing.html" \
        "ISO Certified Malleable Iron Plumbing Fittings | CODA Resources" \
        "https://plumbing-fittings.asia" \
        "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png" \
        "Plumbing" ;;
    lp-hvac)
      build_lp "index.html" "industry-lp/hvac.html" \
        "Certified HVAC Fittings &amp; Heating Components | CODA Resources" \
        "https://hvac-fittings.com" \
        "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef04eb5636a97547c6d6c0_landscape-01.png" \
        "HVAC" ;;
    lp-fire-protection)
      build_lp "index.html" "industry-lp/fire-protection.html" \
        "FM Certified Fire Protection Fittings | CODA Resources" \
        "https://galvanized-fittings.com" \
        "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef05815636a97547c6f802_landscape-01.png" \
        "Fire Protection" ;;
    lp-mexico)
      build_lp "index.html" "industry-lp/plumbing.html" \
        "Conexiones de Hierro Maleable Certificadas | CODA Resources" \
        "https://pipe-fittings.mx" \
        "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png" \
        "Mexico" ;;
    lp-europe)
      build_lp "index.html" "industry-lp/plumbing.html" \
        "Certified Malleable Iron Pipe Fittings Europe | CODA Resources" \
        "https://pipe-fittings.eu" \
        "https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png" \
        "Europe" ;;
    *) echo "❌ Unknown branch: $BRANCH"; exit 1 ;;
  esac
  echo "    ✅ Root index.html ready for $BRANCH"
fi

echo ""
echo "🎉 All builds complete!"
echo ""
ls -la ready-lp/*/index.html 2>/dev/null || true
