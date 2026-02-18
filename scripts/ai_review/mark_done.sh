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

issue_json=$(curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER")

# 라벨을 줄 단위로 안전하게 추출
labels=$(echo "$issue_json" | jq -r '.labels[].name')

# ai-run 제거 + (성공/실패 라벨은 상호배타로 정리)
base_labels=$(printf "%s\n" "$labels" | grep -v -E '^(ai-run|ai-done|ai-fail)$' || true)

if [ "${GITHUB_JOB_STATUS:-success}" = "success" ]; then
  final_labels=$(printf "%s\nai-done\n" "$base_labels")
else
  final_labels=$(printf "%s\nai-fail\n" "$base_labels")
fi

# 빈 줄 제거 + 중복 제거
final_labels=$(printf "%s\n" "$final_labels" | sed '/^$/d' | awk '!seen[$0]++')

json=$(printf "%s\n" "$final_labels" | jq -R . | jq -s '{labels: .}')

curl -sS -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER" \
  -d "$json" >/dev/null

echo "Updated labels for #$ISSUE_NUMBER -> status=${GITHUB_JOB_STATUS:-success}"
