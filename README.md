# ybe
project for ybe

stateDiagram-v2
  direction LR

  %% ======================
  %% STEP 1 (사용계획서)
  %% ======================
  state "STEP1_PLANNED_SEND\n(발송 예정)" as S1_P
  state "STEP1_SENT\n(발송 완료)" as S1_S
  state "STEP1_READ\n(확인 완료)" as S1_R
  state "STEP1_PLAN_SUBMITTED\n(계획서 제출)" as S1_SUB
  state "STEP1_PLAN_APPROVED\n(일정 확정/승인)" as S1_APP
  state "STEP1_CHANGE_REQUESTED\n(일정 변경 요청)" as S1_CR
  state "STEP1_CHANGE_APPROVED\n(일정 변경 승인)" as S1_CA
  state "STEP1_CHANGE_REJECTED\n(일정 변경 반려)" as S1_CX
  state "STEP1_DUE_EXPIRED_NEED_STEP2\n(기한 초과 → 2차 필요)" as S1_EXP

  %% ======================
  %% STEP 2 (지정통지서)
  %% ======================
  state "STEP2_SENT\n(지정통지 발송)" as S2_S
  state "STEP2_READ\n(지정통지 확인)" as S2_R
  state "STEP2_CHANGE_APPLIED\n(지정통지 일정변경 완료)" as S2_CA
  state "STEP2_DUE_EXPIRED_FAILED\n(기한 초과 → 실패)" as S2_FAIL

  [*] --> S1_P : 대상 생성/회차 생성

  %% Step1 normal flow
  S1_P --> S1_S : (SYSTEM) 1차 발송 실행
  S1_S --> S1_R : (USER) 안내문/메일 확인
  S1_S --> S1_SUB : (USER) 계획서 제출(확인없이 제출 허용 시)
  S1_R --> S1_SUB : (USER) 계획서 제출
  S1_SUB --> S1_APP : (ADMIN) 승인/확정

  %% Step1 change flow
  S1_APP --> S1_CR : (USER) 일정 변경 요청
  S1_CR --> S1_CA : (ADMIN) 변경 승인
  S1_CR --> S1_CX : (ADMIN) 변경 반려
  S1_CX --> S1_APP : (SYSTEM) 기존 승인 상태 유지

  %% Step1 timeout -> Step2
  S1_S --> S1_EXP : (SYSTEM) 작성기한(due) 초과
  S1_R --> S1_EXP : (SYSTEM) 작성기한(due) 초과
  S1_P --> S1_EXP : (SYSTEM) 발송이 지연되고 due가 먼저 초과되는 예외

  %% Step2 flow
  S1_EXP --> S2_S : (SYSTEM/ADMIN) 2차 지정통지 발송
  S2_S --> S2_R : (USER) 지정통지 확인
  S2_S --> S2_CA : (ADMIN) 일정 변경 처리(확인 여부와 무관)
  S2_R --> S2_CA : (ADMIN) 일정 변경 처리

  %% Step2 timeout -> fail
  S2_S --> S2_FAIL : (SYSTEM) 지정통지 작성/확정 기한 초과
  S2_R --> S2_FAIL : (SYSTEM) 지정통지 작성/확정 기한 초과
  S2_CA --> [*] : 종결(정책상 완료 처리)
  S1_APP --> [*] : 종결(정책상 완료 처리)
  S1_CA --> [*] : 종결(정책상 완료 처리)
  S2_FAIL --> [*] : 종결(실패)

