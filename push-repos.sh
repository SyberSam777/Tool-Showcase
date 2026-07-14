#!/usr/bin/env bash
# Initialize and push the three Trinity repos. Dry-run by default.
#
#   ./push-repos.sh                 # show what would happen
#   ./push-repos.sh --apply         # actually init, commit, push
#
# Assumes: empty repos already created on GitHub, and gh/ssh auth working.
set -euo pipefail

GH_USER="${GH_USER:-jwilson}"
GH_HOST="${GH_HOST:-github.com}"
REPOS="${REPOS:-baton lode traffic-lab}"
SRC_ROOT="${SRC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
SIGN="${SIGN:-true}"          # signed commits
BRANCH="${BRANCH:-main}"
APPLY=false

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$APPLY" = "true" ]; then
    echo "+ $*"; "$@"
  else
    echo "[dry-run] $*"
  fi
}

$APPLY || echo ">>> DRY RUN. Nothing will be written or pushed. Re-run with --apply."

for repo in $REPOS; do
  dir="$SRC_ROOT/$repo"
  [ -d "$dir" ] || { echo "!! missing $dir, skipping"; continue; }

  echo
  echo "=== $repo ==="

  # Warn about placeholders before anything ships.
  if grep -rIl 'jwilson' "$dir" >/dev/null 2>&1 && [ "$GH_USER" != "jwilson" ]; then
    echo "!! '$dir' still contains the default handle 'jwilson' but GH_USER=$GH_USER"
    echo "   run: grep -rl jwilson $dir | xargs sed -i 's|jwilson|$GH_USER|g'"
  fi

  # Never ship a kubeconfig or an env file, whatever .gitignore says.
  if find "$dir" -maxdepth 2 \( -name '*.kubeconfig' -o -name '.env' \) | grep -q .; then
    echo "!! secrets-looking files present in $dir — aborting"; exit 1
  fi

  ( cd "$dir"
    [ -d .git ] || run git init -b "$BRANCH"
    run git add -A
    if [ "$SIGN" = "true" ]; then
      run git commit -S -m "feat: initial public release of $repo"
    else
      run git commit -m "feat: initial public release of $repo"
    fi
    run git remote add origin "git@${GH_HOST}:${GH_USER}/${repo}.git" || true
    run git push -u origin "$BRANCH"
  )
done

echo
$APPLY && echo ">>> Done. Now: enable branch protection on $BRANCH and require the CI check." \
       || echo ">>> Dry run complete."
