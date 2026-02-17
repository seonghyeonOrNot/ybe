# Attendance Catalog (Source of Truth)

이 디렉토리는 근태 도메인의 **기준 데이터(Source of Truth)** 를 담는다.  
모든 설계/문서/검증/코드 생성은 아래 TSV 파일을 우선 참조한다.

---

## 파일 구성

| 파일 | 의미 |
|---|---|
| 01_attendance_status.tsv | 근태 상태 정의 |
| 02_location_status.tsv | 근무 위치 상태 정의 |
| 03_work_type.tsv | 근무유형 정의 |
| 04_work_type_config_schema.tsv | 근무유형 설정 스키마 |
| 05_metric_definition.tsv | 근태 지표/계산 기준 정의 |
| 06_policy_master.tsv | 정책/옵션 정의 |
| 99_legacy_mapping.tsv | 기존 ST 코드 매핑 |

---

## 사용 원칙

1. TSV는 **근태 도메인의 기준 데이터**다.
2. 문서/설계보다 TSV를 우선 참조한다.
3. 모든 산출물은 TSV 구조를 기준으로 생성한다.
4. canonical_key는 전 시스템에서 공통 식별자로 사용한다.

---

## canonical_key 규칙

| 규칙 | 예시 |
|---|---|
| dot 계층 구조 사용 | attendance.absent |
| 도메인.개념.속성 형태 | worktype.base.start_time |
| 상태/정책/API/QA 모두 동일 키 사용 | metric.total_work_time.actual |

---

## value_type 정의

| 타입 | 의미 |
|---|---|
| string | 텍스트 |
| enum | 선택값 |
| time | 시각 |
| time_range | 시간 범위 |
| time_duration | 시간 길이 |
| int | 정수 |
| float | 실수 |
| boolean | true/false |
| object | 구조 데이터 |

---

## constraints 작성 규칙

constraints는 **머신리더블 형태**로 작성한다.

형식: key=value;key=value


예시:

| 표현 | 의미 |
|---|---|
| required=true | 필수 입력 |
| start_lt_end=true | 시작 < 종료 |
| radius_min_m=50 | 최소 반경 |
| radius_max_m=5000 | 최대 반경 |
| legal_fixed=true | 법정 기준 고정 |
| depends_on=policy.legal_standard=true | 특정 정책 의존 |

---

## TSV 기반 생성 대상

TSV를 기반으로 다음 산출물을 생성한다.

### 설계
- UI 필드 정의
- 상태 판정 기준
- 정책 구조

### 로직
- 근로시간 계산
- 지표 산출
- 이벤트 발생 조건

### 유효성
- 입력 validation
- 정책 제약조건

### QA
- 테스트 시나리오
- edge case
- 오류 케이스

### API
- request 필드
- response 스키마
- 상태 코드

### 감사/로그
- 상태 변경 이벤트
- 정책 변경 기록
- 승인/취소 흐름

---

## 변경 절차

TSV 변경 시 반드시 다음을 확인한다.

| 체크 항목 |
|---|
| canonical_key 변경 여부 |
| constraints 변경 여부 |
| metric 영향 여부 |
| 정책 영향 여부 |
| QA 시나리오 재생성 필요 여부 |
| API 스키마 영향 여부 |

---

## 금지 규칙

1. TSV와 다른 정의를 문서에 별도로 작성하지 않는다.
2. canonical_key를 임의로 생성하지 않는다.
3. constraints를 자연어 문장으로만 작성하지 않는다.
4. 동일 개념을 다른 키로 중복 정의하지 않는다.

---

## 목적

이 디렉토리는 단순 데이터 파일이 아니라:

**근태 시스템의 도메인 모델 원본**

이다.

- 문서 자동 생성
- 코드 스키마 생성
- QA 자동화
- 정책 검증

모든 자동화는 이 데이터에서 시작한다.


