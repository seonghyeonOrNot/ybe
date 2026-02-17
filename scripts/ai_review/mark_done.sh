#!/usr/bin/env bash
set -euo pipefail

ISSUE_NUMBER="$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")"
REPO="${GITHUB_REPOSITORY:?}"

# 둘 중 하나라도 있으면 사용
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [ -z "$TOKEN" ]; then
  echo "ERROR: GITHUB_TOKEN or GH_TOKEN is required"
  exit 1
fi

labels=$(curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER" \
  | jq -r '.labels[].name')

new_labels=$(printf "%s\n" $labels | grep -v '^ai-run$' || true)

if [ "${GITHUB_JOB_STATUS:-success}" = "success" ]; then
  if ! printf "%s\n" $new_labels | grep -q '^ai-done$'; then
    new_labels=$(printf "%s\n%s\n" "$new_labels" "ai-done")
  fi
else
  if ! printf "%s\n" $new_labels | grep -q '^ai-fail$'; then
    new_labels=$(printf "%s\n%s\n" "$new_labels" "ai-fail")
  fi
fi

json=$(printf "%s\n" $new_labels | jq -R . | jq -s '{labels: .}')

curl -sS -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER" \
  -d "$json" >/dev/null

echo "Updated labels for #$ISSUE_NUMBER -> status=${GITHUB_JOB_STATUS:-success}"
