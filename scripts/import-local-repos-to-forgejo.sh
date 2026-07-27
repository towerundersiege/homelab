#!/usr/bin/env bash
# Create private Forgejo repositories for each direct Git repository in a local
# workspace, then mirror committed branches and tags. Existing origin remotes
# and uncommitted work are never modified.

set -euo pipefail

workspace=${1:-"${HOME}/Projects"}
forgejo_url=${FORGEJO_URL:-https://forgejo.home.rpca.uk}
forgejo_owner=${FORGEJO_OWNER:-ryan}

for command in curl find git jq mktemp; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Missing required command: ${command}" >&2
    exit 1
  fi
done

if [[ ! -d "${workspace}" ]]; then
  echo "Workspace not found: ${workspace}" >&2
  exit 1
fi

repositories=()
while IFS= read -r -d '' git_directory; do
  repositories+=("${git_directory}")
done < <(find "${workspace}" -mindepth 2 -maxdepth 2 -type d -name .git -print0)

if [[ ${#repositories[@]} -eq 0 ]]; then
  echo "No direct Git repositories found under ${workspace}" >&2
  exit 1
fi

printf 'Repositories to import into %s/%s:\n' "${forgejo_url}" "${forgejo_owner}"
for git_directory in "${repositories[@]}"; do
  repository=${git_directory%/.git}
  printf '  - %s' "${repository}"
  if [[ -n "$(git -C "${repository}" status --porcelain)" ]]; then
    printf ' (dirty: uncommitted files will not be imported)'
  fi
  printf '\n'
done

read -r -p "Type import to create private repositories and push committed refs: " confirmation
if [[ "${confirmation}" != import ]]; then
  echo 'Cancelled.'
  exit 0
fi

read -r -s -p 'Forgejo access token: ' forgejo_token
printf '\n'
if [[ -z "${forgejo_token}" ]]; then
  echo 'A Forgejo access token is required.' >&2
  exit 1
fi

askpass=$(mktemp)
response=$(mktemp)
cleanup() {
  rm -f "${askpass}" "${response}"
  unset forgejo_token FORGEJO_IMPORT_TOKEN
}
trap cleanup EXIT

cat >"${askpass}" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "${FORGEJO_IMPORT_USERNAME}" ;;
  *Password*) printf '%s\n' "${FORGEJO_IMPORT_TOKEN}" ;;
esac
EOF
chmod 700 "${askpass}"

export FORGEJO_IMPORT_USERNAME="${forgejo_owner}"
export FORGEJO_IMPORT_TOKEN="${forgejo_token}"
export GIT_ASKPASS="${askpass}"
export GIT_TERMINAL_PROMPT=0

for git_directory in "${repositories[@]}"; do
  repository=${git_directory%/.git}
  repository_name=${repository##*/}
  repository_url="${forgejo_url}/${forgejo_owner}/${repository_name}.git"
  api_url="${forgejo_url}/api/v1/repos/${forgejo_owner}/${repository_name}"

  status=$(curl --silent --show-error --output "${response}" --write-out '%{http_code}' \
    --header "Authorization: token ${forgejo_token}" "${api_url}")
  case "${status}" in
    200)
      echo "${repository_name}: Forgejo repository already exists"
      ;;
    404)
      payload=$(jq -nc --arg name "${repository_name}" \
        '{name: $name, private: true, auto_init: false}')
      status=$(curl --silent --show-error --output "${response}" --write-out '%{http_code}' \
        --request POST --header "Authorization: token ${forgejo_token}" \
        --header 'Content-Type: application/json' --data "${payload}" \
        "${forgejo_url}/api/v1/user/repos")
      if [[ "${status}" != 201 ]]; then
        echo "${repository_name}: failed to create repository (HTTP ${status})" >&2
        cat "${response}" >&2
        exit 1
      fi
      echo "${repository_name}: created private Forgejo repository"
      ;;
    *)
      echo "${repository_name}: could not query Forgejo (HTTP ${status})" >&2
      cat "${response}" >&2
      exit 1
      ;;
  esac

  if git -C "${repository}" remote get-url forgejo >/dev/null 2>&1; then
    existing_url=$(git -C "${repository}" remote get-url forgejo)
    if [[ "${existing_url}" != "${repository_url}" ]]; then
      echo "${repository_name}: existing forgejo remote differs: ${existing_url}" >&2
      exit 1
    fi
  else
    git -C "${repository}" remote add forgejo "${repository_url}"
  fi

  git -C "${repository}" push forgejo --all
  git -C "${repository}" push forgejo --tags
  echo "${repository_name}: imported"
done

echo 'Import complete. Existing origin remotes were left unchanged.'
