# HR-007 연차촉진 기능 고도화 - 개발 전달 문서

## 문서 정보

| 항목 | 내용 |
|------|------|
| 이슈 ID | HR-007 |
| 이슈명 | 연차촉진 기능 고도화 |
| 작성일 | 2026-02-04 |
| 작성자 | Tech Communicator |
| 버전 | v1.0 |

---

## 1. 배경 및 요구사항 요약

### 1.1 현황 분석
- 고객 VOC 52건 발생 (시스템 오류 9건, 데이터 오류 5건 포함)
- 주요 문제점:
  - 1년 미만자 연차 계산 오류
  - 계획서 제출 시 연차 즉시 차감 (분리 필요)
  - 이월연차가 촉진 대상에 포함되는 문제
  - 당겨쓴 연차 미반영

### 1.2 개선 목표
- 계획서 제출과 연차 차감의 분리 (`planned_days` vs `used_days`)
- 이월연차 촉진 대상 제외
- 당겨쓴 연차 정확한 반영
- 1년 미만자 월별 발생 연차 실시간 집계
- 입사일 변경 시 촉진 데이터 초기화 옵션 제공

---

## 2. 데이터 모델 제안

### 2.1 연차 테이블 (leaves)

| 필드명 | 타입 | NULL | 기본값 | 설명 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | PK |
| user_id | BIGINT | NO | - | 사용자 ID (FK) |
| leave_type | VARCHAR(20) | NO | - | 연차 유형 (ANNUAL/CARRYOVER/ADDITIONAL/ADVANCE) |
| granted_days | DECIMAL(5,2) | NO | 0 | 부여 일수 |
| used_days | DECIMAL(5,2) | NO | 0 | 실제 사용 일수 |
| planned_days | DECIMAL(5,2) | NO | 0 | 계획서 제출 일수 (사용 예정) |
| advance_used_days | DECIMAL(5,2) | NO | 0 | 당겨쓴 연차 일수 |
| remaining_days | DECIMAL(5,2) | NO | 0 | 잔여 일수 (계산 필드) |
| grant_date | DATE | NO | - | 부여일 |
| expire_date | DATE | NO | - | 만료일 |
| fiscal_year | INT | NO | - | 회계연도 |
| is_promotion_target | BOOLEAN | NO | TRUE | 촉진 대상 여부 |
| created_at | DATETIME | NO | CURRENT_TIMESTAMP | 생성일시 |
| updated_at | DATETIME | NO | CURRENT_TIMESTAMP | 수정일시 |

**인덱스:**
```sql
CREATE INDEX idx_leaves_user_fiscal ON leaves(user_id, fiscal_year);
CREATE INDEX idx_leaves_type ON leaves(leave_type);
CREATE INDEX idx_leaves_expire ON leaves(expire_date);
CREATE UNIQUE INDEX uk_leaves_user_type_grant ON leaves(user_id, leave_type, grant_date);
```

**유니크 조건:**
- `(user_id, leave_type, grant_date)` - 동일 사용자, 동일 유형, 동일 부여일 중복 방지

### 2.2 촉진 테이블 (leave_promotions)

| 필드명 | 타입 | NULL | 기본값 | 설명 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | PK |
| user_id | BIGINT | NO | - | 사용자 ID (FK) |
| fiscal_year | INT | NO | - | 회계연도 |
| promotion_stage | TINYINT | NO | - | 촉진 단계 (1: 1차, 2: 2차) |
| target_days | DECIMAL(5,2) | NO | 0 | 촉진 대상 일수 |
| sent_date | DATETIME | YES | NULL | 발송일시 |
| due_date | DATE | YES | NULL | 제출 마감일 |
| submitted_date | DATETIME | YES | NULL | 계획서 제출일시 |
| status | VARCHAR(20) | NO | 'PENDING' | 상태 (PENDING/SENT/SUBMITTED/EXPIRED) |
| notification_method | VARCHAR(20) | YES | NULL | 발송 방법 (EMAIL/SMS/KAKAO) |
| created_at | DATETIME | NO | CURRENT_TIMESTAMP | 생성일시 |
| updated_at | DATETIME | NO | CURRENT_TIMESTAMP | 수정일시 |

**인덱스:**
```sql
CREATE INDEX idx_promotions_user_year ON leave_promotions(user_id, fiscal_year);
CREATE INDEX idx_promotions_status ON leave_promotions(status);
CREATE INDEX idx_promotions_due ON leave_promotions(due_date);
CREATE UNIQUE INDEX uk_promotions_user_year_stage ON leave_promotions(user_id, fiscal_year, promotion_stage);
```

### 2.3 촉진 계획 테이블 (promotion_plans)

| 필드명 | 타입 | NULL | 기본값 | 설명 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | PK |
| promotion_id | BIGINT | NO | - | 촉진 ID (FK) |
| plan_date | DATE | NO | - | 사용 예정일 |
| plan_days | DECIMAL(3,2) | NO | - | 사용 예정 일수 |
| leave_id | BIGINT | YES | NULL | 연차 ID (FK, 실제 사용 시 연결) |
| is_used | BOOLEAN | NO | FALSE | 실제 사용 여부 |
| used_date | DATE | YES | NULL | 실제 사용일 |
| created_at | DATETIME | NO | CURRENT_TIMESTAMP | 생성일시 |
| updated_at | DATETIME | NO | CURRENT_TIMESTAMP | 수정일시 |

**인덱스:**
```sql
CREATE INDEX idx_plans_promotion ON promotion_plans(promotion_id);
CREATE INDEX idx_plans_date ON promotion_plans(plan_date);
```

### 2.4 변경 이력 테이블 (leave_audit_logs)

| 필드명 | 타입 | NULL | 기본값 | 설명 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | PK |
| table_name | VARCHAR(50) | NO | - | 대상 테이블명 |
| record_id | BIGINT | NO | - | 대상 레코드 ID |
| user_id | BIGINT | NO | - | 대상 사용자 ID |
| action | VARCHAR(20) | NO | - | 작업 유형 (INSERT/UPDATE/DELETE) |
| field_name | VARCHAR(50) | YES | NULL | 변경 필드명 |
| old_value | TEXT | YES | NULL | 변경 전 값 |
| new_value | TEXT | YES | NULL | 변경 후 값 |
| changed_by | BIGINT | NO | - | 변경 수행자 ID |
| changed_at | DATETIME | NO | CURRENT_TIMESTAMP | 변경일시 |
| reason | VARCHAR(200) | YES | NULL | 변경 사유 |
| ip_address | VARCHAR(45) | YES | NULL | 요청 IP |

**인덱스:**
```sql
CREATE INDEX idx_audit_table_record ON leave_audit_logs(table_name, record_id);
CREATE INDEX idx_audit_user ON leave_audit_logs(user_id);
CREATE INDEX idx_audit_changed_at ON leave_audit_logs(changed_at);
```

---

## 3. API 설계

### 3.1 GET /api/promotions - 촉진 현황 조회

**설명:** 촉진 대상자 목록 및 현황 조회

**Request:**
```http
GET /api/promotions?fiscal_year=2026&stage=1&status=PENDING&page=1&size=20
Authorization: Bearer {token}
```

**Query Parameters:**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| fiscal_year | int | N | 회계연도 (기본: 현재년도) |
| stage | int | N | 촉진 단계 (1, 2) |
| status | string | N | 상태 필터 |
| department_id | int | N | 부서 필터 |
| page | int | N | 페이지 번호 (기본: 1) |
| size | int | N | 페이지 크기 (기본: 20, 최대: 100) |

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "promotion_id": 1234,
        "user_id": 5678,
        "user_name": "홍길동",
        "department": "개발팀",
        "hire_date": "2023-03-15",
        "tenure_type": "OVER_ONE_YEAR",
        "fiscal_year": 2026,
        "promotion_stage": 1,
        "target_days": 10.0,
        "annual_days": 15.0,
        "additional_days": 2.0,
        "used_days": 5.0,
        "advance_used_days": 0.0,
        "carryover_days": 2.0,
        "sent_date": "2026-07-01T09:00:00",
        "due_date": "2026-07-10",
        "submitted_date": null,
        "status": "SENT",
        "plans": []
      }
    ],
    "pagination": {
      "page": 1,
      "size": 20,
      "total_items": 156,
      "total_pages": 8
    },
    "summary": {
      "total_targets": 156,
      "pending_count": 45,
      "sent_count": 80,
      "submitted_count": 31,
      "expired_count": 0
    }
  }
}
```

**에러 코드:**

| 코드 | HTTP Status | 메시지 | 설명 |
|------|-------------|--------|------|
| PROMO_001 | 400 | Invalid fiscal year | 유효하지 않은 회계연도 |
| PROMO_002 | 400 | Invalid promotion stage | 유효하지 않은 촉진 단계 |
| PROMO_003 | 403 | Access denied | 조회 권한 없음 |
| PROMO_004 | 500 | Internal server error | 서버 오류 |

---

### 3.2 POST /api/promotions/send - 촉진 발송

**설명:** 대상자에게 촉진 알림 발송

**Request:**
```http
POST /api/promotions/send
Authorization: Bearer {token}
Content-Type: application/json

{
  "fiscal_year": 2026,
  "promotion_stage": 1,
  "user_ids": [5678, 5679, 5680],
  "notification_method": "EMAIL",
  "due_date": "2026-07-10",
  "message_template_id": 101
}
```

**Request Body:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| fiscal_year | int | Y | 회계연도 |
| promotion_stage | int | Y | 촉진 단계 (1 또는 2) |
| user_ids | array | Y | 대상자 ID 목록 (빈 배열 시 전체 대상) |
| notification_method | string | Y | 발송 방법 (EMAIL/SMS/KAKAO) |
| due_date | string | Y | 제출 마감일 (YYYY-MM-DD) |
| message_template_id | int | N | 메시지 템플릿 ID |

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "sent_count": 3,
    "failed_count": 0,
    "results": [
      {
        "user_id": 5678,
        "status": "SENT",
        "sent_at": "2026-07-01T09:00:00"
      }
    ]
  },
  "message": "촉진 알림이 발송되었습니다."
}
```

**에러 코드:**

| 코드 | HTTP Status | 메시지 | 설명 |
|------|-------------|--------|------|
| SEND_001 | 400 | Invalid request body | 요청 형식 오류 |
| SEND_002 | 400 | No valid targets | 유효한 대상자 없음 |
| SEND_003 | 400 | Already sent | 이미 발송된 대상 포함 |
| SEND_004 | 400 | Invalid due date | 마감일이 과거 또는 너무 미래 |
| SEND_005 | 403 | Permission denied | 발송 권한 없음 |
| SEND_006 | 500 | Notification service error | 알림 서비스 오류 |

---

### 3.3 POST /api/promotions/plans - 계획서 제출

**설명:** 연차 사용 계획서 제출 (연차 차감 없음)

**Request:**
```http
POST /api/promotions/plans
Authorization: Bearer {token}
Content-Type: application/json

{
  "promotion_id": 1234,
  "plans": [
    {
      "plan_date": "2026-08-15",
      "plan_days": 1.0
    },
    {
      "plan_date": "2026-09-01",
      "plan_days": 0.5
    }
  ]
}
```

**Request Body:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| promotion_id | int | Y | 촉진 ID |
| plans | array | Y | 계획 목록 |
| plans[].plan_date | string | Y | 사용 예정일 (YYYY-MM-DD) |
| plans[].plan_days | number | Y | 사용 예정 일수 (0.5 단위) |

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "promotion_id": 1234,
    "total_plan_days": 1.5,
    "remaining_target_days": 8.5,
    "submitted_at": "2026-07-05T14:30:00",
    "plans": [
      {
        "plan_id": 101,
        "plan_date": "2026-08-15",
        "plan_days": 1.0
      },
      {
        "plan_id": 102,
        "plan_date": "2026-09-01",
        "plan_days": 0.5
      }
    ]
  },
  "message": "계획서가 제출되었습니다."
}
```

**에러 코드:**

| 코드 | HTTP Status | 메시지 | 설명 |
|------|-------------|--------|------|
| PLAN_001 | 400 | Invalid promotion id | 유효하지 않은 촉진 ID |
| PLAN_002 | 400 | Promotion not sent | 촉진 미발송 상태 |
| PLAN_003 | 400 | Past due date | 제출 기한 초과 |
| PLAN_004 | 400 | Invalid plan date | 사용 예정일 오류 (과거 또는 범위 초과) |
| PLAN_005 | 400 | Exceeds target days | 촉진 대상 일수 초과 |
| PLAN_006 | 400 | Invalid plan days unit | 일수 단위 오류 (0.5 단위만 허용) |
| PLAN_007 | 403 | Not plan owner | 본인 계획서만 제출 가능 |

---

### 3.4 PUT /api/promotions/plans/:id - 계획서 수정

**설명:** 제출된 계획서 수정 (마감일 이전에만 가능)

**Request:**
```http
PUT /api/promotions/plans/101
Authorization: Bearer {token}
Content-Type: application/json

{
  "plan_date": "2026-08-20",
  "plan_days": 1.0
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "plan_id": 101,
    "plan_date": "2026-08-20",
    "plan_days": 1.0,
    "updated_at": "2026-07-06T10:00:00"
  },
  "message": "계획이 수정되었습니다."
}
```

**에러 코드:**

| 코드 | HTTP Status | 메시지 | 설명 |
|------|-------------|--------|------|
| PLAN_101 | 400 | Invalid plan id | 유효하지 않은 계획 ID |
| PLAN_102 | 400 | Plan already used | 이미 사용된 계획 수정 불가 |
| PLAN_103 | 400 | Past due date | 수정 기한 초과 |
| PLAN_104 | 403 | Not plan owner | 본인 계획만 수정 가능 |

---

### 3.5 GET /api/promotions/export - 촉진 현황 다운로드

**설명:** 촉진 현황을 엑셀 파일로 다운로드

**Request:**
```http
GET /api/promotions/export?fiscal_year=2026&stage=1&format=xlsx
Authorization: Bearer {token}
```

**Query Parameters:**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| fiscal_year | int | Y | 회계연도 |
| stage | int | N | 촉진 단계 |
| format | string | N | 파일 형식 (xlsx/csv, 기본: xlsx) |
| include_plans | bool | N | 계획 상세 포함 여부 |

**Response (200 OK):**
```http
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="promotion_report_2026_stage1.xlsx"

[Binary file content]
```

**에러 코드:**

| 코드 | HTTP Status | 메시지 | 설명 |
|------|-------------|--------|------|
| EXPORT_001 | 400 | Invalid parameters | 파라미터 오류 |
| EXPORT_002 | 403 | Export permission denied | 다운로드 권한 없음 |
| EXPORT_003 | 500 | Export generation failed | 파일 생성 실패 |

---

## 4. 계산 로직 의사코드

### 4.1 촉진 대상 연차 계산

```python
def calculate_promotion_target_days(user_id: int, fiscal_year: int) -> Decimal:
    """
    촉진 대상 연차 계산
    공식: 촉진 대상 연차 = 기본연차 + 가산연차 - 사용연차 - 당겨쓴연차 - 이월연차

    Returns:
        Decimal: 촉진 대상 일수 (0 이상)
    """
    # 사용자의 해당 연도 연차 정보 조회
    leaves = get_leaves_by_user_and_year(user_id, fiscal_year)

    # 연차 유형별 합계 계산
    annual_days = sum(
        leave.granted_days
        for leave in leaves
        if leave.leave_type == 'ANNUAL'
    )

    additional_days = sum(
        leave.granted_days
        for leave in leaves
        if leave.leave_type == 'ADDITIONAL'
    )

    used_days = sum(
        leave.used_days
        for leave in leaves
        if leave.leave_type in ('ANNUAL', 'ADDITIONAL')
    )

    advance_used_days = sum(
        leave.advance_used_days
        for leave in leaves
        if leave.leave_type in ('ANNUAL', 'ADDITIONAL')
    )

    # 이월연차는 촉진 대상에서 제외
    carryover_days = sum(
        leave.granted_days
        for leave in leaves
        if leave.leave_type == 'CARRYOVER'
    )

    # 촉진 대상 연차 계산
    # 이월연차는 촉진 대상에서 제외하므로 별도로 차감하지 않음
    # (이월연차 자체가 granted에 포함되지 않음)
    target_days = (
        annual_days
        + additional_days
        - used_days
        - advance_used_days
    )

    # 음수 방지
    return max(Decimal('0'), target_days)
```

### 4.2 1년 미만자 월별 연차 계산

```python
def calculate_under_one_year_leave(user_id: int, hire_date: date, base_date: date) -> Decimal:
    """
    1년 미만자 월별 발생 연차 계산
    - 매월 만근 시 1일 발생
    - 최대 11일까지 발생 가능

    Args:
        user_id: 사용자 ID
        hire_date: 입사일
        base_date: 기준일 (계산 시점)

    Returns:
        Decimal: 발생한 총 연차 일수
    """
    # 입사일로부터 경과 개월 수 계산
    months_worked = calculate_months_between(hire_date, base_date)

    # 1년 미만 체크
    if months_worked >= 12:
        raise ValueError("1년 이상 근무자는 이 함수를 사용할 수 없습니다.")

    # 월별 만근 여부 확인 (출근율 80% 이상)
    monthly_attendance = []
    for month in range(months_worked):
        month_start = add_months(hire_date, month)
        month_end = add_months(hire_date, month + 1) - timedelta(days=1)

        attendance_rate = get_attendance_rate(user_id, month_start, month_end)
        monthly_attendance.append(attendance_rate >= 0.8)

    # 만근 월 수 = 발생 연차 (최대 11일)
    full_attendance_months = sum(1 for is_full in monthly_attendance if is_full)
    granted_days = min(full_attendance_months, 11)

    # 사용 연차 조회
    used_days = get_used_days_for_period(
        user_id,
        hire_date,
        add_months(hire_date, 12) - timedelta(days=1)
    )

    # 잔여 연차 = 발생 연차 - 사용 연차
    remaining = Decimal(granted_days) - used_days

    return max(Decimal('0'), remaining)
```

### 4.3 잔여연차 계산 (이월, 당겨쓰기 포함)

```python
def calculate_remaining_days(
    user_id: int,
    fiscal_year: int,
    include_carryover: bool = True,
    include_advance: bool = True
) -> dict:
    """
    잔여 연차 종합 계산

    Args:
        user_id: 사용자 ID
        fiscal_year: 회계연도
        include_carryover: 이월연차 포함 여부
        include_advance: 당겨쓰기 포함 여부

    Returns:
        dict: {
            'total_granted': 총 부여 일수,
            'annual_granted': 기본 연차,
            'additional_granted': 가산 연차,
            'carryover_granted': 이월 연차,
            'used_days': 사용 일수,
            'planned_days': 계획 일수 (미사용),
            'advance_used': 당겨쓴 일수,
            'remaining_total': 총 잔여,
            'remaining_for_promotion': 촉진 대상 잔여,
            'available_days': 실제 사용 가능 일수
        }
    """
    leaves = get_leaves_by_user_and_year(user_id, fiscal_year)

    result = {
        'annual_granted': Decimal('0'),
        'additional_granted': Decimal('0'),
        'carryover_granted': Decimal('0'),
        'used_days': Decimal('0'),
        'planned_days': Decimal('0'),
        'advance_used': Decimal('0'),
    }

    for leave in leaves:
        if leave.leave_type == 'ANNUAL':
            result['annual_granted'] += leave.granted_days
        elif leave.leave_type == 'ADDITIONAL':
            result['additional_granted'] += leave.granted_days
        elif leave.leave_type == 'CARRYOVER':
            result['carryover_granted'] += leave.granted_days

        result['used_days'] += leave.used_days
        result['planned_days'] += leave.planned_days
        result['advance_used'] += leave.advance_used_days

    # 총 부여 일수 (이월 포함 여부에 따라)
    result['total_granted'] = (
        result['annual_granted']
        + result['additional_granted']
        + (result['carryover_granted'] if include_carryover else Decimal('0'))
    )

    # 실제 사용 일수 (당겨쓰기 포함 여부에 따라)
    actual_used = result['used_days']
    if include_advance:
        actual_used += result['advance_used']

    # 총 잔여 일수
    result['remaining_total'] = result['total_granted'] - actual_used

    # 촉진 대상 잔여 (이월연차 제외)
    result['remaining_for_promotion'] = (
        result['annual_granted']
        + result['additional_granted']
        - result['used_days']
        - result['advance_used']
    )

    # 실제 사용 가능 일수 (계획 일수 제외)
    result['available_days'] = (
        result['remaining_total']
        - result['planned_days']
    )

    # 음수 방지
    for key in ['remaining_total', 'remaining_for_promotion', 'available_days']:
        result[key] = max(Decimal('0'), result[key])

    return result


def consume_leave_with_priority(user_id: int, days: Decimal, use_date: date) -> list:
    """
    연차 사용 시 차감 우선순위 적용
    우선순위: 1.이월연차 -> 2.당해연도 기본연차 -> 3.가산연차
    (만료일이 빠른 순으로 소진)

    Args:
        user_id: 사용자 ID
        days: 사용 일수
        use_date: 사용일

    Returns:
        list: 차감된 연차 목록 [{'leave_id': ..., 'consumed': ...}, ...]
    """
    # 사용 가능한 연차를 우선순위대로 정렬
    leaves = get_available_leaves(user_id, use_date)

    priority_order = {
        'CARRYOVER': 1,
        'ANNUAL': 2,
        'ADDITIONAL': 3
    }

    # 우선순위, 만료일 순으로 정렬
    sorted_leaves = sorted(
        leaves,
        key=lambda x: (priority_order.get(x.leave_type, 99), x.expire_date)
    )

    consumed_list = []
    remaining_to_consume = days

    for leave in sorted_leaves:
        if remaining_to_consume <= 0:
            break

        available = leave.remaining_days - leave.planned_days
        if available <= 0:
            continue

        consume_amount = min(available, remaining_to_consume)

        consumed_list.append({
            'leave_id': leave.id,
            'leave_type': leave.leave_type,
            'consumed': consume_amount,
            'expire_date': leave.expire_date
        })

        remaining_to_consume -= consume_amount

    if remaining_to_consume > 0:
        raise InsufficientLeaveError(
            f"잔여 연차 부족. 필요: {days}, 가용: {days - remaining_to_consume}"
        )

    return consumed_list
```

---

## 5. 마이그레이션 / 백필 / 배치 작업

### 5.1 기존 데이터 마이그레이션 계획

#### Phase 1: 스키마 변경 (다운타임 없음)

```sql
-- 1. leaves 테이블에 신규 컬럼 추가
ALTER TABLE leaves
ADD COLUMN planned_days DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER used_days,
ADD COLUMN advance_used_days DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER planned_days,
ADD COLUMN is_promotion_target BOOLEAN NOT NULL DEFAULT TRUE;

-- 2. 인덱스 추가
CREATE INDEX idx_leaves_type ON leaves(leave_type);
CREATE INDEX idx_leaves_expire ON leaves(expire_date);

-- 3. 신규 테이블 생성
-- (leave_promotions, promotion_plans, leave_audit_logs DDL 실행)
```

#### Phase 2: 데이터 백필

```sql
-- 1. 이월연차 촉진 대상 제외 설정
UPDATE leaves
SET is_promotion_target = FALSE
WHERE leave_type = 'CARRYOVER';

-- 2. 기존 촉진 데이터 마이그레이션 (기존 테이블이 있다고 가정)
INSERT INTO leave_promotions (user_id, fiscal_year, promotion_stage, target_days, sent_date, status)
SELECT
    user_id,
    YEAR(sent_date) as fiscal_year,
    promotion_stage,
    -- target_days는 백필 스크립트에서 계산
    0 as target_days,
    sent_date,
    CASE
        WHEN submitted_date IS NOT NULL THEN 'SUBMITTED'
        WHEN sent_date IS NOT NULL THEN 'SENT'
        ELSE 'PENDING'
    END as status
FROM old_promotion_table;
```

### 5.2 planned_days / used_days 분리 처리

```python
def migrate_plan_usage_separation():
    """
    계획서 제출로 인해 used_days에 잘못 반영된 데이터를
    planned_days로 분리하는 마이그레이션
    """
    # 1. 계획서는 제출했으나 실제 사용일이 미래인 케이스 조회
    affected_records = db.query("""
        SELECT p.*, l.id as leave_id, l.used_days
        FROM old_promotion_plans p
        JOIN leaves l ON l.user_id = p.user_id
            AND l.fiscal_year = YEAR(p.plan_date)
        WHERE p.plan_date > CURRENT_DATE
        AND p.is_deducted = TRUE
    """)

    for record in affected_records:
        # 2. used_days에서 차감하고 planned_days로 이동
        db.execute("""
            UPDATE leaves
            SET
                used_days = used_days - :plan_days,
                planned_days = planned_days + :plan_days
            WHERE id = :leave_id
        """, {
            'plan_days': record.plan_days,
            'leave_id': record.leave_id
        })

        # 3. 이력 기록
        db.execute("""
            INSERT INTO leave_audit_logs
            (table_name, record_id, user_id, action, field_name,
             old_value, new_value, changed_by, reason)
            VALUES
            ('leaves', :leave_id, :user_id, 'UPDATE', 'used_days/planned_days',
             :old_value, :new_value, 0, 'DATA_MIGRATION_PLAN_SEPARATION')
        """, {
            'leave_id': record.leave_id,
            'user_id': record.user_id,
            'old_value': f"used_days={record.used_days}",
            'new_value': f"used_days={record.used_days - record.plan_days}, planned_days={record.plan_days}"
        })

    # 4. 커밋 및 검증
    db.commit()

    # 5. 검증 쿼리 실행
    verify_migration()
```

### 5.3 배치 작업 정의

| 배치명 | 주기 | 실행시간 | 설명 |
|--------|------|----------|------|
| PromotionTargetBatch | 일간 | 01:00 | 촉진 대상자 일일 집계 |
| MonthlyLeaveGrantBatch | 월간 | 매월 1일 00:00 | 1년 미만자 월별 연차 부여 |
| PromotionSendScheduleBatch | 일간 | 09:00 | 촉진 발송 예정일 도래 시 자동 발송 |
| LeaveExpirationBatch | 일간 | 00:00 | 만료 연차 처리 및 알림 |
| CarryoverProcessBatch | 연간 | 회계연도 말 | 이월 연차 처리 |
| AdvanceLeaveReconcileBatch | 월간 | 매월 말일 23:00 | 당겨쓴 연차 정산 |

#### 배치 상세: 촉진 대상자 집계 (PromotionTargetBatch)

```python
def promotion_target_batch():
    """
    촉진 대상자 일일 집계 배치
    실행 주기: 매일 01:00
    """
    fiscal_year = get_current_fiscal_year()

    # 1. 촉진 대상 기준일 확인
    promotion_config = get_promotion_config(fiscal_year)

    # 2. 전체 재직자 중 촉진 대상자 추출
    employees = get_active_employees()

    targets = []
    for emp in employees:
        # 근속 기간 확인
        tenure_type = get_tenure_type(emp.hire_date)

        # 촉진 대상 연차 계산
        target_days = calculate_promotion_target_days(emp.id, fiscal_year)

        if target_days > promotion_config.minimum_target_days:
            targets.append({
                'user_id': emp.id,
                'fiscal_year': fiscal_year,
                'tenure_type': tenure_type,
                'target_days': target_days
            })

    # 3. leave_promotions 테이블에 upsert
    for target in targets:
        upsert_promotion_target(target)

    # 4. 발송 예정일 도래 대상자 알림
    notify_upcoming_promotions(targets)

    # 5. 배치 결과 로깅
    log_batch_result('PromotionTargetBatch', {
        'total_employees': len(employees),
        'target_count': len(targets),
        'fiscal_year': fiscal_year
    })
```

#### 배치 상세: 1년 미만자 월별 연차 부여 (MonthlyLeaveGrantBatch)

```python
def monthly_leave_grant_batch():
    """
    1년 미만자 월별 연차 자동 부여
    실행 주기: 매월 1일 00:00
    """
    today = date.today()

    # 1. 1년 미만 재직자 조회
    under_one_year_employees = get_employees_under_one_year()

    granted_count = 0
    for emp in under_one_year_employees:
        # 2. 해당 월 만근 여부 확인
        prev_month_start = (today - timedelta(days=1)).replace(day=1)
        prev_month_end = today - timedelta(days=1)

        attendance_rate = get_attendance_rate(
            emp.id,
            prev_month_start,
            prev_month_end
        )

        if attendance_rate >= 0.8:
            # 3. 이미 부여된 연차 수 확인 (최대 11일)
            current_granted = get_monthly_granted_count(emp.id, emp.hire_date)

            if current_granted < 11:
                # 4. 연차 1일 부여
                create_leave({
                    'user_id': emp.id,
                    'leave_type': 'ANNUAL',
                    'granted_days': 1,
                    'grant_date': today,
                    'expire_date': add_years(emp.hire_date, 1) - timedelta(days=1),
                    'fiscal_year': get_fiscal_year(emp.hire_date)
                })
                granted_count += 1

    # 5. 배치 결과 로깅
    log_batch_result('MonthlyLeaveGrantBatch', {
        'checked_count': len(under_one_year_employees),
        'granted_count': granted_count
    })
```

---

## 6. 추가 고려사항

### 6.1 입사일 변경 시 처리

```python
def handle_hire_date_change(user_id: int, old_hire_date: date, new_hire_date: date, reset_promotion: bool = False):
    """
    입사일 변경 시 연차 및 촉진 데이터 처리

    Args:
        user_id: 사용자 ID
        old_hire_date: 기존 입사일
        new_hire_date: 변경된 입사일
        reset_promotion: 촉진 데이터 초기화 여부
    """
    # 1. 연차 재계산 필요 여부 확인
    old_tenure = calculate_tenure_years(old_hire_date)
    new_tenure = calculate_tenure_years(new_hire_date)

    if old_tenure != new_tenure:
        # 연차 일수 변경 알림 생성
        create_notification(user_id, 'LEAVE_RECALCULATION_NEEDED')

    # 2. 촉진 데이터 초기화 (옵션)
    if reset_promotion:
        # 기존 촉진 데이터 소프트 삭제
        soft_delete_promotions(user_id, reason='HIRE_DATE_CHANGE')

        # 촉진 대상 재계산 트리거
        trigger_promotion_recalculation(user_id)

    # 3. 감사 로그 기록
    create_audit_log({
        'table_name': 'users',
        'record_id': user_id,
        'user_id': user_id,
        'action': 'UPDATE',
        'field_name': 'hire_date',
        'old_value': old_hire_date.isoformat(),
        'new_value': new_hire_date.isoformat(),
        'reason': 'HIRE_DATE_CORRECTION'
    })
```

### 6.2 에러 처리 및 알림

| 에러 유형 | 처리 방식 | 알림 대상 |
|-----------|-----------|-----------|
| 연차 계산 오류 | 배치 실패 로그 + 재시도 | 시스템 관리자 |
| 발송 실패 | 개별 재시도 (최대 3회) | 발송 담당자 |
| 데이터 정합성 오류 | 자동 복구 시도 + 수동 확인 요청 | 시스템 관리자, HR 담당자 |
| 마이그레이션 오류 | 롤백 + 수동 처리 필요 | 개발팀, DBA |

---

## 7. 체크리스트

### 개발 전 확인사항
- [ ] 기존 테이블 스키마 확인
- [ ] 기존 촉진 데이터 건수 및 분포 확인
- [ ] 연차 유형(leave_type) ENUM 값 정의 확인
- [ ] 회계연도 기준 확인 (1월 시작 vs 입사일 기준)

### 개발 완료 조건
- [ ] 단위 테스트 커버리지 80% 이상
- [ ] 통합 테스트 시나리오 10개 이상 통과
- [ ] 마이그레이션 스크립트 검증 (스테이징 환경)
- [ ] 롤백 스크립트 준비
- [ ] API 문서 자동 생성 (Swagger/OpenAPI)
- [ ] 성능 테스트 (대상자 10,000명 기준)

---

*문서 끝*
