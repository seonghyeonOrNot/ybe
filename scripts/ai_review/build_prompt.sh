#!/usr/bin/env bash
set -euo pipefail

TITLE="$(jq -r '.issue.title' "$GITHUB_EVENT_PATH")"
BODY="$(jq -r '.issue.body // ""' "$GITHUB_EVENT_PATH")"
LABELS_CSV="$(jq -r '.issue.labels[].name' "$GITHUB_EVENT_PATH" | paste -sd ", " -)"

has_label () {
  local target="$1"
  jq -e --arg t "$target" '.issue.labels[]? | select(.name==$t)' "$GITHUB_EVENT_PATH" >/dev/null 2>&1
}

: > required_outputs.md

if has_label feature; then
  cat >> required_outputs.md <<'EOF'
### [feature] 기능 이슈/설계 검토
- As-is / To-be
- 영향 범위(상태/정책/지표/설정스키마): data/catalog/attendance/*.tsv 근거로 명시
- constraints(머신리더블) → 사용자 안내 문구(한 줄) 변환
- edge case 5개 이상
- QA 시나리오(정상/경계/오류) 표
- API 스키마 초안(request/response 필드/타입)
EOF
  echo >> required_outputs.md
fi

if has_label cs; then
  cat >> required_outputs.md <<'EOF'
### [cs] 고객 문의 검토
- 문의 요약(재현 조건 포함)
- 원인 후보 Top 3(정책/상태/권한/환경)
- 확인 질문(최소) 5개 이내
- 즉시 대응 가이드(운영/고객응대 문구 포함)
- 개선 필요 시 feature 액션아이템
EOF
  echo >> required_outputs.md
fi

if has_label policy; then
  cat >> required_outputs.md <<'EOF'
### [policy] 정책 정합성
- 정책 해석(기준/예외/충돌)
- 관련 TSV 항목(canonical_key) 근거 제시
- UI 안내 문구(한 줄) 3안
- 감사/로그 포인트(필드/이벤트)
EOF
  echo >> required_outputs.md
fi

if has_label qa; then
  cat >> required_outputs.md <<'EOF'
### [qa] QA 산출물
- 테스트 케이스 표(정상/경계/오류)
- 기대 결과는 정수(분/건수 등)로 명시
- 데이터 준비(사전조건) 체크리스트
EOF
  echo >> required_outputs.md
fi

if has_label risk; then
  cat >> required_outputs.md <<'EOF'
### [risk] 리스크/컴플라이언스
- 법/감사 관점 리스크
- 완화 방안(로그/권한/보관/고지)
EOF
  echo >> required_outputs.md
fi

if has_label data; then
  cat >> required_outputs.md <<'EOF'
### [data] 지표/계산
- metric_definition.tsv 근거로 계산 기준 정리
- 입력/출력 단위 및 데이터 소스 명시
EOF
  echo >> required_outputs.md
fi

if [ ! -s required_outputs.md ]; then
  cat > required_outputs.md <<'EOF'
### [default]
- 이슈 내용을 기준으로 기능/정책/QA 관점 종합 검토 결과 작성
EOF
fi

cat > prompt.txt <<EOF
너는 PM/개발/QA/운영을 위한 실무 리뷰어다.
Output language: Korean
표 기반 구조 우선. 계산값/기대결과는 정수로 명시.

반드시 참고할 기준 데이터(Source of Truth):
- data/catalog/attendance/*.tsv
- CLAUDE.md의 Working Agreement

아래 이슈 본문을 입력으로, 질문으로 끝내지 말고 가정을 두고 완성된 결과를 작성하라.

[Issue Title]
${TITLE}

[Issue Body]
${BODY}

[Labels]
${LABELS_CSV}

[Required Outputs by Label]
EOF

cat required_outputs.md >> prompt.txt

반드시 최종 답변을 파일로도 저장하라: comment.md (Markdown).
출력은 표 기반으로 작성하고, 마지막에 "END"를 한 줄로 추가하라.
