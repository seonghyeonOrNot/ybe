# 휴가 관리 API 설계

## Base URL
```
/api/v1
```

## 인증
모든 API는 인증 필요. JWT 토큰 사용 권장.
```
Authorization: Bearer <token>
```

## API 엔드포인트

### 1. 사용자 목록 조회

#### 부여 대상자 목록
```http
GET /api/v1/users/eligible
```

**Query Parameters:**
- `page` (optional): 페이지 번호 (기본값: 1)
- `limit` (optional): 페이지당 항목 수 (기본값: 20)
- `department` (optional): 부서 필터

**Response 200:**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": "user-001",
        "name": "홍길동",
        "email": "hong@example.com",
        "department": "개발팀",
        "vacation_balance": {
          "total_days": 15,
          "used_days": 5,
          "remaining_days": 10
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45,
      "total_pages": 3
    }
  }
}
```

#### 비대상자 목록
```http
GET /api/v1/users/ineligible
```

**Response 200:** (동일한 구조)

### 2. 휴가 수동 부여

```http
POST /api/v1/admin/vacation/assign
```

**Request Body:**
```json
{
  "user_id": "user-001",
  "days_granted": 5,
  "reason": "특별 근무에 대한 보상",
  "valid_from": "2026-02-01",
  "valid_until": "2026-12-31"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "assignment": {
      "id": "assign-001",
      "user_id": "user-001",
      "admin_id": "admin-001",
      "days_granted": 5,
      "reason": "특별 근무에 대한 보상",
      "valid_from": "2026-02-01",
      "valid_until": "2026-12-31",
      "created_at": "2026-01-30T09:00:00Z"
    },
    "updated_balance": {
      "total_days": 20,
      "used_days": 5,
      "remaining_days": 15
    }
  }
}
```

**Error Responses:**

400 Bad Request:
```json
{
  "success": false,
  "error": {
    "code": "INVALID_INPUT",
    "message": "부여 일수는 양수여야 합니다."
  }
}
```

403 Forbidden:
```json
{
  "success": false,
  "error": {
    "code": "NOT_ELIGIBLE",
    "message": "해당 직원은 휴가 수동 부여 대상자가 아닙니다."
  }
}
```

401 Unauthorized:
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "관리자 권한이 필요합니다."
  }
}
```

### 3. 휴가 부여 이력 조회

#### 전체 이력
```http
GET /api/v1/admin/vacation/assignments
```

**Query Parameters:**
- `page` (optional): 페이지 번호
- `limit` (optional): 페이지당 항목 수
- `user_id` (optional): 특정 직원 필터
- `from_date` (optional): 시작일 필터
- `to_date` (optional): 종료일 필터

**Response 200:**
```json
{
  "success": true,
  "data": {
    "assignments": [
      {
        "id": "assign-001",
        "user": {
          "id": "user-001",
          "name": "홍길동",
          "email": "hong@example.com"
        },
        "admin": {
          "id": "admin-001",
          "name": "김관리"
        },
        "days_granted": 5,
        "reason": "특별 근무에 대한 보상",
        "valid_from": "2026-02-01",
        "valid_until": "2026-12-31",
        "created_at": "2026-01-30T09:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 100,
      "total_pages": 5
    }
  }
}
```

#### 특정 직원 이력
```http
GET /api/v1/users/{user_id}/vacation/assignments
```

**Response 200:** (동일한 구조)

### 4. 직원별 휴가 잔액 조회

```http
GET /api/v1/users/{user_id}/vacation/balance
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "user_id": "user-001",
    "year": 2026,
    "balance": {
      "total_days": 20,
      "used_days": 5,
      "remaining_days": 15
    },
    "assignments_history": [
      {
        "id": "assign-001",
        "days_granted": 5,
        "reason": "특별 근무에 대한 보상",
        "granted_by": "김관리",
        "created_at": "2026-01-30T09:00:00Z"
      }
    ]
  }
}
```

### 5. 대시보드 통계

```http
GET /api/v1/admin/dashboard/stats
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "total_users": 120,
    "eligible_users": 95,
    "ineligible_users": 25,
    "total_assignments_this_year": 450,
    "total_days_granted_this_year": 2250,
    "recent_assignments": [
      {
        "id": "assign-005",
        "user_name": "홍길동",
        "days_granted": 3,
        "created_at": "2026-01-30T08:30:00Z"
      }
    ]
  }
}
```

## 에러 코드

| 코드 | 설명 |
|------|------|
| `INVALID_INPUT` | 입력값 검증 실패 |
| `NOT_FOUND` | 리소스를 찾을 수 없음 |
| `UNAUTHORIZED` | 인증 실패 |
| `FORBIDDEN` | 권한 없음 |
| `NOT_ELIGIBLE` | 부여 대상자가 아님 |
| `INSUFFICIENT_BALANCE` | 휴가 잔액 부족 |
| `INTERNAL_ERROR` | 서버 내부 오류 |

## 보안 고려사항

1. **인증/인가**
   - JWT 토큰 기반 인증
   - 관리자 권한 확인 (RBAC)
   - 토큰 만료 시간 설정 (예: 1시간)

2. **입력 검증**
   - 모든 사용자 입력 검증
   - SQL Injection 방지
   - XSS 방지

3. **감사 로그**
   - 모든 휴가 부여 액션 로깅
   - 관리자 액션 추적

4. **Rate Limiting**
   - API 호출 제한 (예: 100 req/min per user)

## 기술 스택 권장사항

- **Backend**: Node.js (Express/Fastify) 또는 Spring Boot (Java)
- **Database**: PostgreSQL 또는 MySQL
- **인증**: JWT with bcrypt
- **문서화**: Swagger/OpenAPI
- **테스트**: Jest (Node.js) 또는 JUnit (Java)
