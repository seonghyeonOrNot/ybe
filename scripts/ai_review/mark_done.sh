#!/usr/bin/env bash
set -euo pipefail

ISSUE_NUMBER="$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")"

if [ "${GITHUB_JOB_STATUS:-success}" = "success" ]; then
  gh issue edit "$ISSUE_NUMBER" --remove-label "ai-run" --add-label "ai-done"
else
  gh issue edit "$ISSUE_NUMBER" --remove-label "ai-run" --add-label "ai-fail"
fi
