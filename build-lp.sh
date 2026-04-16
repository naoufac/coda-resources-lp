#!/bin/bash
# ============================================================================
# CODA Resources - Landing Page Branch Builder
# ============================================================================
# Usage: ./build-lp.sh <branch-name>
#
# This script prepares the current branch for Cloudflare Pages deployment:
# 1. Copies the correct LP HTML as index.html at root
# 2. Fixes all relative paths (../css/ → ./css/, etc.)
# 3. Fixes CTAs (mailto → #Form-title, navbar Contact Us → #Form-title)
# 4. Improves SEO (title, canonical, og:image, remove duplicate GA)
# 5. Fixes cross-site links to absolute URLs
#
# Branch mapping:
#   lp-plumbing        → plumbing.html    → plumbing-fittings.asia
#   lp-hvac            → hvac.html        → hvac-fittings.com
#   lp-fire-protection → fire-protection  → galvanized-fittings.com
#   lp-mexico          → plumbing.html    → pipe-fittings.mx
#   lp-europe          → plumbing.html    → pipe-fittings.eu
# ============================================================================

set -e

BRANCH="${1:-$(git branch --show-current)}"
MAIN_SITE="https://www.codaresources-vietnam.com"

echo "🔧 Building LP for branch: $BRANCH"

# Determine source file and config per branch
case "$BRANCH" in
  lp-plumbing)
    SOURCE="industry-lp/plumbing.html"
    TITLE="ISO Certified Malleable Iron Plumbing Fittings | CODA Resources"
    CANONICAL="https://plumbing-fittings.asia"
    OG_IMAGE="https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png"
    ;;
  lp-hvac)
    SOURCE="industry-lp/hvac.html"
    TITLE="Certified HVAC Fittings &amp; Heating Components | CODA Resources"
    CANONICAL="https://hvac-fittings.com"
    OG_IMAGE="https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef04eb5636a97547c6d6c0_landscape-01.png"
    ;;
  lp-fire-protection)
    SOURCE="industry-lp/fire-protection.html"
    TITLE="FM Certified Fire Protection Fittings | CODA Resources"
    CANONICAL="https://galvanized-fittings.com"
    OG_IMAGE="https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ef05815636a97547c6f802_landscape-01.png"
    ;;
  lp-mexico)
    SOURCE="industry-lp/plumbing.html"
    TITLE="Conexiones de Hierro Maleable Certificadas | CODA Resources"
    CANONICAL="https://pipe-fittings.mx"
    OG_IMAGE="https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png"
    ;;
  lp-europe)
    SOURCE="industry-lp/plumbing.html"
    TITLE="Certified Malleable Iron Pipe Fittings Europe | CODA Resources"
    CANONICAL="https://pipe-fittings.eu"
    OG_IMAGE="https://cdn.prod.website-files.com/68ec7db83e69c43112dbe029/68ee1093dd995b9d0376c3af_landscape-01.png"
    ;;
  *)
    echo "❌ Unknown branch: $BRANCH"
    echo "   Valid branches: lp-plumbing, lp-hvac, lp-fire-protection, lp-mexico, lp-europe"
    exit 1
    ;;
esac

echo "   Source: $SOURCE"
echo "   Title: $TITLE"
echo "   Canonical: $CANONICAL"

# Copy source to index.html
cp "$SOURCE" index.html
echo "✅ Copied $SOURCE → index.html"

# ---- PATH FIXES ----
# Fix relative paths: ../ → ./ (since index.html is now at root)
sed -i '' 's|"\.\./css/|"./css/|g' index.html
sed -i '' 's|"\.\./js/|"./js/|g' index.html
sed -i '' 's|"\.\./images/|"./images/|g' index.html
sed -i '' 's|"\.\./fonts/|"./fonts/|g' index.html
sed -i '' 's|"\.\./videos/|"./videos/|g' index.html
# Also fix srcset paths (no quotes, comma-separated)
sed -i '' 's|\.\./images/|./images/|g' index.html
sed -i '' 's|\.\./videos/|./videos/|g' index.html
echo "✅ Fixed asset paths (../ → ./)"

# ---- SEO: TITLE ----
python3 -c "
import re
title = '''${TITLE}'''
with open('index.html', 'r') as f:
    content = f.read()
content = re.sub(r'<title>[^<]*</title>', f'<title>{title}</title>', content)
with open('index.html', 'w') as f:
    f.write(content)
"
echo "✅ Updated title tag"

# ---- SEO: CANONICAL ----
# Add canonical link after charset meta if not present
if ! grep -q 'rel="canonical"' index.html; then
  sed -i '' "s|<meta charset=\"utf-8\">|<meta charset=\"utf-8\">\n  <link rel=\"canonical\" href=\"${CANONICAL}\">|" index.html
  echo "✅ Added canonical URL: $CANONICAL"
fi

# ---- SEO: OG:IMAGE ----
# Add og:image after og:type if not present
if ! grep -q 'og:image' index.html; then
  sed -i '' "s|<meta property=\"og:type\" content=\"website\">|<meta property=\"og:type\" content=\"website\">\n  <meta property=\"og:image\" content=\"${OG_IMAGE}\">\n  <meta name=\"twitter:image\" content=\"${OG_IMAGE}\">|" index.html
  echo "✅ Added og:image and twitter:image"
fi

# ---- SEO: UPDATE OG:TITLE TO MATCH TITLE ----
python3 -c "
import re
title = '''${TITLE}'''
# Remove &amp; for clean og display
clean_title = title.replace('&amp;', '&')
with open('index.html', 'r') as f:
    content = f.read()
content = re.sub(r'<meta content=\"[^\"]*\" property=\"og:title\">', f'<meta content=\"{clean_title}\" property=\"og:title\">', content)
content = re.sub(r'<meta content=\"[^\"]*\" property=\"twitter:title\">', f'<meta content=\"{clean_title}\" property=\"twitter:title\">', content)
with open('index.html', 'w') as f:
    f.write(content)
"
echo "✅ Updated og:title and twitter:title"

# ---- CTA FIX: Hero "request a quote" mailto → #Form-title ----
sed -i '' 's|href="mailto:rpalmeiro@codaresources\.vn, Aferrari@codaresources\.com?subject=Quote%20request%20-%20Coda%20Resources%20Vietnam"|href="#Form-title"|g' index.html
echo "✅ Fixed hero CTA: mailto → #Form-title"

# ---- CTA FIX: Navbar "CONTACT US" buttons → #Form-title ----
# The navbar has <a href="#" class="button small w-inline-block"> with CONTACT US text
# We need to change the href="#" on these specific buttons
# Using Python for more precise replacement
python3 -c "
import re
with open('index.html', 'r') as f:
    content = f.read()

# Fix navbar CONTACT US buttons: href=\"#\" → href=\"#Form-title\"
# These are inside nav-button divs
content = content.replace(
    '<div class=\"nav-button visible-mobile\">\n            <a href=\"#\" class=\"button small w-inline-block\">',
    '<div class=\"nav-button visible-mobile\">\n            <a href=\"#Form-title\" class=\"button small w-inline-block\">'
)
content = content.replace(
    '<div class=\"nav-button visible-mobile\">\n              <a href=\"#\" class=\"button small w-inline-block\">',
    '<div class=\"nav-button visible-mobile\">\n              <a href=\"#Form-title\" class=\"button small w-inline-block\">'
)

with open('index.html', 'w') as f:
    f.write(content)
"
echo "✅ Fixed navbar CONTACT US → #Form-title"

# ---- CTA FIX: Product card mailto links → #Form-title ----
sed -i '' 's|href="mailto:support@codaresources\.vn?subject=Catalog%20request%20-%20Coda%20Resources%20Vietnam"|href="#Form-title"|g' index.html
echo "✅ Fixed product card CTAs → #Form-title"

# ---- FIX CROSS-SITE LINKS ----
# ../certifications.html → main site
sed -i '' "s|href=\"\.\./certifications\.html\"|href=\"${MAIN_SITE}/certifications\"|g" index.html
# ../solutions/contract-manufacturer.html → main site
sed -i '' "s|href=\"\.\./solutions/contract-manufacturer\.html\"|href=\"${MAIN_SITE}/solutions/contract-manufacturer\" target=\"_blank\"|g" index.html
# ../solutions/product.html → main site
sed -i '' "s|href=\"\.\./solutions/product\.html\"|href=\"${MAIN_SITE}/solutions/product\" target=\"_blank\"|g" index.html
echo "✅ Fixed cross-site links to absolute URLs"

# ---- REMOVE DUPLICATE GA TAG ----
# The pages have GA loaded twice: once by Webflow auto-inject, once manually
# Remove the manual duplicate (the one wrapped in <!-- Google tag (gtag.js) --> comments)
python3 -c "
import re
with open('index.html', 'r') as f:
    content = f.read()

# Remove the manual duplicate GA block (between the Google tag comments)
pattern = r'  <!--  Google tag \(gtag\.js\)  -->\s*\n\s*<script async=\"\" src=\"https://www\.googletagmanager\.com/gtag/js\?id=G-6R0J6870LV\"></script>\s*\n\s*<script>\s*\n\s*window\.dataLayer = window\.dataLayer \|\| \[\];\s*\n\s*function gtag\(\)\{dataLayer\.push\(arguments\);\}\s*\n\s*gtag\(.*?\);\s*\n\s*gtag\(.*?\);\s*\n\s*</script>'
content = re.sub(pattern, '', content, flags=re.DOTALL)

with open('index.html', 'w') as f:
    f.write(content)
"
echo "✅ Removed duplicate Google Analytics tag"

# ---- SCHEMA.ORG FIX: Update URLs in JSON-LD ----
# Fix relative URLs in JSON-LD to use canonical domain
if grep -q 'application/ld+json' index.html; then
  sed -i '' "s|\"url\": \"/industry/|\"url\": \"${CANONICAL}/industry/|g" index.html
  sed -i '' "s|\"url\": \"/\"|\"url\": \"${CANONICAL}/\"|g" index.html
  sed -i '' "s|\"item\": \"/industry/|\"item\": \"${CANONICAL}/industry/|g" index.html
  sed -i '' "s|\"item\": \"/\"|\"item\": \"${CANONICAL}/\"|g" index.html
  echo "✅ Fixed Schema.org URLs"
fi

# ---- LOGO CONSISTENCY ----
# Ensure light navbar uses CODA-Resources-logo-blue.svg (not codavietnam_blue.svg)
sed -i '' 's|src="./images/codavietnam_blue.svg"|src="./images/CODA-Resources-logo-blue.svg"|g' index.html
echo "✅ Fixed logo consistency"

# ---- FORM: STATICFORMS.DEV INTEGRATION ----
# Replace the Webflow form (method="get" + data-wf-*) with StaticForms POST endpoint
# Key: sf_445b8939b73ed208581d52a5
STATICFORMS_KEY="sf_445b8939b73ed208581d52a5"

python3 -c "
import re

with open('index.html', 'r') as f:
    content = f.read()

# Replace the <form> tag: change method to POST, add action, remove Webflow attributes
content = re.sub(
    r'<form id=\"email-form\" name=\"email-form\" data-name=\"Email Form\" method=\"get\" class=\"form\" data-wf-page-id=\"[^\"]*\" data-wf-element-id=\"[^\"]*\">',
    '<form id=\"email-form\" name=\"email-form\" action=\"https://api.staticforms.dev/submit\" method=\"POST\" class=\"form\">'
    + '\n              <input type=\"hidden\" name=\"apiKey\" value=\"${STATICFORMS_KEY}\">'
    + '\n              <input type=\"hidden\" name=\"subject\" value=\"New Lead from ${BRANCH} — CODA Resources\">'
    + '\n              <input type=\"hidden\" name=\"redirectTo\" value=\"${CANONICAL}#Form-title\">',
    content
)

# Remove the broken Webflow reCAPTCHA div (StaticForms handles spam protection)
content = re.sub(
    r'\s*<div class=\"w-form-formrecaptcha g-recaptcha[^\"]*\"></div>',
    '',
    content
)

with open('index.html', 'w') as f:
    f.write(content)
"

# Now fix the shell variable placeholders that Python wrote literally
sed -i '' "s|\\\${STATICFORMS_KEY}|${STATICFORMS_KEY}|g" index.html
sed -i '' "s|\\\${BRANCH}|${BRANCH}|g" index.html
sed -i '' "s|\\\${CANONICAL}|${CANONICAL}|g" index.html

echo "✅ Integrated StaticForms (key: ${STATICFORMS_KEY})"

echo ""
echo "🎉 Build complete! index.html is ready for deployment."
echo "   Branch: $BRANCH"
echo "   Canonical: $CANONICAL"
echo ""
echo "📋 Next steps:"
echo "   1. Review index.html"
echo "   2. git add index.html && git commit -m 'Build LP for $BRANCH'"
echo "   3. git push origin $BRANCH"
echo "   4. Cloudflare Pages will auto-deploy from this branch"
