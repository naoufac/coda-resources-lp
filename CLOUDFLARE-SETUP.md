# Cloudflare Pages Deployment Guide

## Quick Start (One Command)

```bash
git clone https://github.com/naoufac/coda.git && cd coda

export CF_API_TOKEN="your-cloudflare-api-token"
export CF_ACCOUNT_ID="your-cloudflare-account-id"

bash deploy-all.sh
```

This single command creates 5 Git branches, pushes them, creates 5 Cloudflare Pages projects, attaches 9 custom domains, and configures 5 redirect rules. Done.

You can also run the parts separately:
```bash
bash deploy-all.sh --branches-only     # Just create & push Git branches
bash deploy-all.sh --cloudflare-only   # Just configure Cloudflare via API
```

---

## Overview

This repo contains 5 separate landing pages, each deployed as an independent Cloudflare Pages project from its own Git branch. Any push to a branch triggers an automatic redeploy of its corresponding landing page.

## Architecture

| Branch | Landing Page | Domains |
|--------|-------------|---------|
| `lp-plumbing` | Plumbing LP | plumbing-fittings.asia · malleable-iron.asia · malleableironfittings.asia |
| `lp-hvac` | HVAC LP | hvac-fittings.com |
| `lp-fire-protection` | Fire Protection LP | galvanized-fittings.com · galvanized-fittings.asia |
| `lp-mexico` | Mexico LP (Plumbing) | pipe-fittings.mx · iron-fittings.mx |
| `lp-europe` | Europe LP (Plumbing) | pipe-fittings.eu |

---

## Step 1: Create Branches & Push

### Option A: Automatic via GitHub Actions (Recommended)

The repo includes a GitHub Actions workflow (`.github/workflows/deploy-branches.yml`) that automatically creates and pushes all 5 landing page branches when:
- Changes are pushed to `main` in the `landing-pages/` directory
- The workflow is manually triggered (Actions → Deploy Landing Page Branches → Run workflow)

This runs automatically — no manual steps needed once the workflow is merged to `main`.

### Option B: Manual

```bash
# Clone the repo
git clone <repo-url>
cd <repo>

# Run the branch creation script
bash create-branches.sh

# Push all branches
git push origin lp-plumbing lp-hvac lp-fire-protection lp-mexico lp-europe
```

---

## Step 2: Create Cloudflare Pages Projects + Domains + Redirects

### Option A: Automated via API Script (Recommended)

Run the `cloudflare-setup.sh` script to create all 5 Pages projects, attach domains, and configure 301 redirects in one go:

```bash
# Set your Cloudflare credentials
export CF_API_TOKEN="your-api-token"    # Create at: Cloudflare → My Profile → API Tokens
export CF_ACCOUNT_ID="your-account-id"  # Found at: Cloudflare → any domain → Overview → sidebar
export GITHUB_REPO_OWNER="naoufac"
export GITHUB_REPO_NAME="coda"

# Run the setup
bash cloudflare-setup.sh
```

The API token needs these permissions:
- **Account** > Cloudflare Pages > Edit
- **Zone** > Zone > Read
- **Zone** > DNS > Edit
- **Zone** > Page Rules / Rules > Edit

This will:
- Create 5 Cloudflare Pages projects connected to this repo
- Attach all 9 custom domains to the correct projects
- Set up 301 redirects for 5 domains → codaresources-vietnam.com

### Option B: Manual via Dashboard

For **each** of the 5 branches, create a new Cloudflare Pages project:

1. Go to **Cloudflare Dashboard** → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**
2. Select this repository
3. Select the branch (e.g., `lp-plumbing`)
4. Build settings:
   - **Framework preset**: None
   - **Build command**: _(leave empty)_
   - **Build output directory**: `/`
5. Click **Save and Deploy**
6. Wait for the initial deployment to complete

### Naming Convention

| Branch | Suggested Project Name |
|--------|----------------------|
| `lp-plumbing` | `coda-lp-plumbing` |
| `lp-hvac` | `coda-lp-hvac` |
| `lp-fire-protection` | `coda-lp-fire-protection` |
| `lp-mexico` | `coda-lp-mexico` |
| `lp-europe` | `coda-lp-europe` |

---

## Step 3: Attach Custom Domains

For each Cloudflare Pages project, add the corresponding custom domains:

1. Go to the Pages project → **Custom domains** → **Set up a custom domain**
2. Add each domain listed below
3. Cloudflare will auto-configure DNS if the domain is already on your account

### Domain Assignments

**coda-lp-plumbing:**
- `plumbing-fittings.asia`
- `malleable-iron.asia`
- `malleableironfittings.asia`

**coda-lp-hvac:**
- `hvac-fittings.com`

**coda-lp-fire-protection:**
- `galvanized-fittings.com`
- `galvanized-fittings.asia`

**coda-lp-mexico:**
- `pipe-fittings.mx`
- `iron-fittings.mx`

**coda-lp-europe:**
- `pipe-fittings.eu`

---

## Step 4: Set Up 301 Redirects (5 Domains → Main Site)

These 5 domains should redirect to the main site with a 301 (permanent redirect):

| Domain | Redirect To |
|--------|------------|
| `iron-fittings.com` | `https://codaresources-vietnam.com` |
| `iron-fittings.asia` | `https://codaresources-vietnam.com` |
| `pipe-fittings.asia` | `https://codaresources-vietnam.com` |
| `pipe-nipple.asia` | `https://codaresources-vietnam.com` |
| `press-fittings.asia` | `https://codaresources-vietnam.com` |

### How to configure each redirect:

1. Go to **Cloudflare Dashboard** → select the domain
2. Navigate to **Rules** → **Redirect Rules**
3. Click **Create rule**
4. Configure:
   - **Rule name**: `Redirect to main site`
   - **When incoming requests match**: `All incoming requests`
   - **Then**: `Static redirect`
   - **URL**: `https://codaresources-vietnam.com`
   - **Status code**: `301`
   - **Preserve query string**: ✅ checked
5. Click **Deploy**

---

## Step 5: Pending Domains (Awaiting Client Confirmation)

| Domain | Current Setup | Notes |
|--------|--------------|-------|
| `groovedfittings.asia` | Pending | Likely → fire-protection LP |
| `iron-oem.asia` | Pending | Likely → `https://codaresources-vietnam.com/solutions/contract-manufacturer` |

### When confirmed:

**For `groovedfittings.asia` (if fire-protection):**
1. Go to `coda-lp-fire-protection` Pages project
2. Add `groovedfittings.asia` as a custom domain

**For `iron-oem.asia` (if redirect to contract-manufacturer page):**
1. Go to Cloudflare Dashboard → `iron-oem.asia`
2. Rules → Redirect Rules → Create rule
3. Redirect to: `https://codaresources-vietnam.com/solutions/contract-manufacturer`
4. Status code: `301`

---

## Maintenance

### Updating a Landing Page

To update any landing page, simply push changes to its branch:

```bash
git checkout lp-plumbing
# Make changes to index.html, images, etc.
git add -A
git commit -m "Update plumbing LP content"
git push origin lp-plumbing
# Cloudflare auto-deploys within ~60 seconds
```

### Branch Structure

Each branch contains only:
```
/
├── index.html          # Landing page entry point
├── css/
│   ├── normalize.css
│   ├── webflow.css
│   └── lp-coda.webflow.css
├── fonts/
│   ├── FunnelSans-Regular.ttf
│   ├── FunnelSans-Medium.ttf
│   ├── FunnelSans-VariableFont_wght.ttf
│   └── GeistMonoVariableVF.ttf
├── images/             # Only images used by this LP
├── js/
│   └── webflow.js
└── videos/
    ├── 5200378-hd_1920_1080_30fps-transcode.mp4
    └── 5200378-hd_1920_1080_30fps-transcode.webm
```

---

## Summary of All 17 Domains

| Domain | Type | Target |
|--------|------|--------|
| plumbing-fittings.asia | Landing Page | `lp-plumbing` branch |
| malleable-iron.asia | Landing Page | `lp-plumbing` branch |
| malleableironfittings.asia | Landing Page | `lp-plumbing` branch |
| hvac-fittings.com | Landing Page | `lp-hvac` branch |
| galvanized-fittings.com | Landing Page | `lp-fire-protection` branch |
| galvanized-fittings.asia | Landing Page | `lp-fire-protection` branch |
| pipe-fittings.mx | Landing Page | `lp-mexico` branch |
| iron-fittings.mx | Landing Page | `lp-mexico` branch |
| pipe-fittings.eu | Landing Page | `lp-europe` branch |
| iron-fittings.com | 301 Redirect | codaresources-vietnam.com |
| iron-fittings.asia | 301 Redirect | codaresources-vietnam.com |
| pipe-fittings.asia | 301 Redirect | codaresources-vietnam.com |
| pipe-nipple.asia | 301 Redirect | codaresources-vietnam.com |
| press-fittings.asia | 301 Redirect | codaresources-vietnam.com |
| groovedfittings.asia | ⏳ Pending | Likely fire-protection LP |
| iron-oem.asia | ⏳ Pending | Likely redirect to /solutions/contract-manufacturer |
