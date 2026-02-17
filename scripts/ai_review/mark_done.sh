#!/usr/bin/env bash
set -euo pipefail

ISSUE_NUMBER="$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")"
REPO="${GITHUB_REPOSITORY:?}"
TOKEN="${GH_TOKEN:?}"

# 현재 라벨 목록 조회
labels=$(curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER" \
  | jq -r '.labels[].name')

# ai-run 제거
new_labels=$(printf "%s\n" $labels | grep -v '^ai-run$' || true)

# 성공/실패 라벨 추가
if [ "${GITHUB_JOB_STATUS:-success}" = "success" ]; then
  # ai-done 추가 (중복 방지)
  if ! printf "%s\n" $new_labels | grep -q '^ai-done$'; then
    new_labels=$(printf "%s\n%s\n" "$new_labels" "ai-done")
  fi
else
  # ai-fail 추가 (중복 방지)
  if ! printf "%s\n" $new_labels | grep -q '^ai-fail$'; then
    new_labels=$(printf "%s\n%s\n" "$new_labels" "ai-fail")
  fi
fi

# JSON 배열로 변환해서 라벨 set (PATCH)
json=$(printf "%s\n" $new_labels | jq -R . | jq -s '{labels: .}')

curl -sS -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER" \
  -d "$json" >/dev/null

echo "Updated labels for issue #$ISSUE_NUMBER (status=${GITHUB_JOB_STATUS:-success})"
