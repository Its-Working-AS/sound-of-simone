#!/bin/bash

# Deploy current Astro build to Cloudflare Pages DEV project.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

overall_start="$(date +%s)"

log_step() {
  local step="$1"
  echo ""
  echo "⏱️  $step"
}

run_timed() {
  local description="$1"
  shift

  local start end elapsed
  start="$(date +%s)"
  "$@"
  end="$(date +%s)"
  elapsed="$((end - start))"
  echo "✅ $description completed in ${elapsed}s"
}

if [ ! -d "node_modules" ]; then
  log_step "Installing dependencies (node_modules missing)..."
  run_timed "Dependency install" npm ci
fi

log_step "Building site..."
run_timed "Build" npm run build

log_step "Deploying to Cloudflare Pages DEV project (sound-of-simone-dev)..."
run_timed "Cloudflare Pages deploy" npx wrangler pages deploy dist --project-name sound-of-simone-dev --branch main

overall_end="$(date +%s)"
overall_elapsed="$((overall_end - overall_start))"

echo ""
echo "🎉 DEV deploy completed in ${overall_elapsed}s."
