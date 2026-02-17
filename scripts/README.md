# Scripts Directory

This directory contains utility scripts for deployment and verification.

## Available Scripts

### verify-deployment.sh

**Purpose:** Verify that all deployed components are accessible and working correctly.

**Usage:**
```bash
# Use default domains
./scripts/verify-deployment.sh

# Use custom domains
MAIN_DOMAIN=soundofsimone.no PROXY_DOMAIN=decap.soundofsimone.no ./scripts/verify-deployment.sh
```

**What it checks:**
- ✅ Main site accessibility (https://soundofsimone.no)
- ✅ About page (https://soundofsimone.no/about)
- ✅ Blog posts (https://soundofsimone.no/blog/welcome)
- ✅ CMS admin interface (https://soundofsimone.no/admin/)
- ✅ OAuth proxy (https://decap.soundofsimone.no)
- ✅ DNS resolution for both domains

**Requirements:**
- `curl` command
- `dig` command (for DNS checks)

**Example Output:**
```
🔍 Verifying deployment of Sound of Simone...

📍 Testing Main Site
====================
Checking Main site (https://soundofsimone.no)... ✓ OK
Checking About page (https://soundofsimone.no/about)... ✓ OK
Checking Blog post (https://soundofsimone.no/blog/welcome)... ✓ OK
Checking CMS admin interface (https://soundofsimone.no/admin/)... ✓ OK

🔐 Testing OAuth Proxy
======================
Checking OAuth proxy (https://decap.soundofsimone.no)... ✓ OK
Checking OAuth proxy response content... ✓ OK

🔧 Testing DNS Resolution
==========================
Resolving soundofsimone.no... ✓ OK
Resolving decap.soundofsimone.no... ✓ OK

📋 Deployment Summary
=====================
Note: This script only verifies that URLs are accessible.
For full CMS functionality, ensure:
  1. GitHub OAuth app is configured
  2. Worker secrets (OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET) are set
  3. Custom domains are properly configured in Cloudflare
```

## Adding New Scripts

When adding new scripts to this directory:

1. Make them executable:
   ```bash
   chmod +x scripts/your-script.sh
   ```

2. Use bash shebang:
   ```bash
   #!/bin/bash
   ```

3. Include error handling:
   ```bash
   set -e  # Exit on error
   ```

4. Document in this README

## Best Practices

- Keep scripts simple and focused on a single task
- Include helpful error messages
- Use colors for output (GREEN, RED, YELLOW)
- Test scripts locally before committing
- Document all environment variables and requirements
