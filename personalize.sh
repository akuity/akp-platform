#!/usr/bin/env bash
# Personalizes this platform repo for your fork and your Akuity environment.
# Run once from the repo root after forking; to start over, reset with
# `git checkout -- .` first.
#
# Works with both GNU sed (Linux) and BSD sed (macOS).

set -e

# GNU sed accepts `-i` bare; BSD sed requires `-i ''`.
if sed --version >/dev/null 2>&1; then
  SEDI=(-i)
else
  SEDI=(-i '')
fi

echo -n "Enter GitHub username/org (owner of your akp-platform fork): "
read -r username
if [[ -z "$username" ]]; then
  echo "GitHub username/org is required." >&2
  exit 1
fi

echo -n "Enter workload cluster name (your Argo CD cluster destination) [workload-cluster]: "
read -r workload
workload=${workload:-workload-cluster}

echo -n "Enter the Argo CD destination name of the Kargo control plane [kargo]: "
read -r kargo_dest
kargo_dest=${kargo_dest:-kargo}

# GHCR org for the guestbook image (leave empty to keep akuity's public image)
echo -n "Enter GHCR org for the guestbook image (empty = keep ghcr.io/akuity): "
read -r ghcr_org

# GitHub org in repo URLs and doc links (all three companion repos)
find . -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.md' \) -not -path './.git/*' -exec sed -E "${SEDI[@]}" \
  -e "s#github.com/[-_a-zA-Z0-9]+/akp-platform#github.com/${username}/akp-platform#g" \
  -e "s#github.com/[-_a-zA-Z0-9]+/akp-monorepo#github.com/${username}/akp-monorepo#g" \
  -e "s#github.com/[-_a-zA-Z0-9]+/akp-infra#github.com/${username}/akp-infra#g" \
  {} +

# CODEOWNERS team slug. Anchored on the team name, not the owner, for the same
# reason as the repo URLs above. Only the org part is rewritten — personal-account
# forks still have to swap `@owner/platform-team` for a plain `@owner` by hand
# (see the comment in the file; GitHub ignores owners it can't resolve).
if [[ -f .github/CODEOWNERS ]]; then
  sed -E "${SEDI[@]}" "s#@[-_a-zA-Z0-9]+/platform-team#@${username}/platform-team#g" .github/CODEOWNERS
fi

# Workload cluster: Argo CD destination names in the app ApplicationSets
find ./apps -type f -name '*.yaml' -exec sed -E "${SEDI[@]}" \
  "s#name: workload-cluster#name: ${workload}#g" {} +

# Kargo control-plane destination ($-anchored so only the destination name
# matches, not `kargo-apps`/`kargo-shared` Application names). Every bootstrap
# manifest that targets the Kargo control plane (kargo-apps.yaml,
# kargo-shared.yaml, akp-bootstrap-project.yaml) needs this rewrite. The
# optional `- ` covers akp-bootstrap-project.yaml's `destinations:` list form
# (`    - name: kargo`) as well as the plain mapping form used elsewhere
# (`    name: kargo`).
find ./bootstrap -type f -name '*.yaml' -exec sed -E "${SEDI[@]}" \
  "s#^( +)(- )?name: kargo\$#\\1\\2name: ${kargo_dest}#" {} +

# Guestbook image org — only if requested
if [[ -n "$ghcr_org" ]]; then
  ghcr_org=$(echo "$ghcr_org" | tr '[:upper:]' '[:lower:]')
  find ./apps -type f \( -name '*.yaml' -o -name '*.md' \) -exec sed -E "${SEDI[@]}" \
    "s#ghcr.io/[-_a-zA-Z0-9]+/guestbook#ghcr.io/${ghcr_org}/guestbook#g" {} +
fi

echo ""
echo "Done. Review the changes with 'git diff', then commit and push."
echo "Notes:"
echo "  - This script is one-shot for the cluster name — reset with 'git checkout -- .' before re-running."
echo "  - If you also forked akp-monorepo or akp-infra, run their personalize/setup steps too."
echo "  - .github/CODEOWNERS now says @${username}/platform-team. If ${username} is a"
echo "    personal account (not an org), replace those owners with plain @${username} —"
echo "    GitHub ignores code owners it cannot resolve."
