# Annual Leave System Specification

**Spec ID**: TSK1-YBE3
**Priority**: P0
**Status**: Ready for Dev
**Reference**: [Notion Page](https://www.notion.so/2f9c0f61d07480619639f6bde1b18cec)

## Overview

This specification defines the annual leave (연차) and vacation management system based on Korean Labor Standards Act (근로기준법). The system manages leave creation, allocation, accrual, expiration, carryover, substitute holidays, and notifications.

## 1. Annual Leave Generation Rules

### 1.1 Basic Leave Entitlement

According to Korean Labor Standards Act Article 60:

- **First Year Employment**: Workers who have worked for 80% or more of the first year are entitled to 15 days of annual leave
- **Continued Employment**: After 1 year of continuous service, workers receive 1 additional day per year of service
- **Maximum Leave**: Up to 25 days (15 base days + 10 additional days after 10 years)

### 1.2 Monthly Accrual (First Year)

For employees in their first year:
- 1 day of leave is accrued for each full month worked (with 80% attendance)
- Maximum 11 days can be accrued during the first year
- These days expire after 2 years from the date of accrual

### 1.3 Work Type-Based Configurations

The system supports different leave policies based on employment type:

#### Full-time Employees (정규직)
- Standard annual leave as per Korean Labor Standards Act
- 15 days base + incremental increases

#### Part-time Employees (시간제)
- Proportional leave based on working hours
- Calculated as: `(Working hours / Standard working hours) × Standard leave days`

#### Contract Employees (계약직)
- Leave allocation based on contract terms
- May follow standard rules or custom allocation

## 2. Leave Allocation and Accrual Policies

### 2.1 Allocation Timing

- **Annual allocation**: January 1st of each year (for returning employees)
- **First-year employees**: Monthly accrual on the 1st of each month
- **New hires**: Calculated based on hire date

### 2.2 Accrual Calculation

```
First Year Monthly Accrual = (Days worked / Total working days in month) × 1 day
Annual Allocation = 15 days + (Years of service - 1) days
Maximum = 25 days
```

### 2.3 Decimal Point Handling

- **Rounding Method**: Round up to the nearest 0.5 day
- **Minimum Unit**: 0.5 days
- Examples:
  - 0.1-0.5 days → 0.5 days
  - 0.6-1.0 days → 1.0 days
  - 1.1-1.5 days → 1.5 days

## 3. Expiration and Carryover Policies

### 3.1 Leave Expiration

- Annual leave expires **2 years** from the date of allocation
- First-year monthly accrued leave expires 2 years from accrual date
- System automatically tracks and removes expired leave

### 3.2 Carryover Policy

- **Unused leave**: Automatically carries over to the next year
- **Maximum carryover**: No explicit limit (subject to 2-year expiration)
- **Carryover tracking**: System maintains separate buckets for each year's allocation

### 3.3 Expiration Notifications

The system sends notifications:
- **90 days before expiration**: First warning
- **60 days before expiration**: Second warning
- **30 days before expiration**: Final warning
- **7 days before expiration**: Urgent notification

## 4. Substitute Holiday System (대체휴가)

### 4.1 Generation Rules

Substitute holidays are created when employees work on:
- Legal holidays (법정공휴일)
- Company-designated holidays
- Weekends (if applicable per employment contract)

### 4.2 Compensation Calculation

```
Holiday work hours × 1.5 = Substitute holiday hours
Example: 8 hours work on holiday = 12 hours (1.5 days) substitute leave
```

### 4.3 Usage and Expiration

- **Usage period**: Must be used within 3 months of generation
- **Expiration**: Automatically expires if not used
- **Priority**: Substitute holidays should be used before annual leave

## 5. Leave Usage Units

### 5.1 Minimum Usage Unit

- **Standard unit**: 0.5 days (4 hours)
- **Full day**: 8 hours
- **Half day**: 4 hours

### 5.2 Usage Types

- **Full-day leave**: Entire working day
- **Half-day leave (AM)**: Morning hours (typically 09:00-13:00)
- **Half-day leave (PM)**: Afternoon hours (typically 13:00-18:00)
- **Hourly leave**: For flexible working arrangements (minimum 1 hour)

### 5.3 Usage Rules

- Leave requests must be submitted in advance (company policy defines timeframe)
- Manager approval required
- Cannot use more leave than available balance
- Expired leave cannot be used

## 6. Notification System

### 6.1 Leave Balance Notifications

- **Monthly**: Current leave balance
- **Quarterly**: Projected leave usage and expiration warnings
- **Annual**: Year-end summary and next year's allocation

### 6.2 Expiration Warnings

As defined in section 3.3, automated notifications at:
- 90, 60, 30, and 7 days before expiration

### 6.3 Approval Notifications

- Employee receives notification when leave request is approved/rejected
- Manager receives notification when leave request is submitted
- HR receives notification for leave requests exceeding certain thresholds

### 6.4 Usage Recommendations

- System suggests optimal leave usage to prevent expiration
- Alerts for employees with high unused leave balances
- Monthly reminders for employees with expiring leave

## 7. Data Model Requirements

### 7.1 Core Entities

#### Leave Balance
- Employee ID
- Leave type (annual, substitute, etc.)
- Total allocated
- Used
- Remaining
- Expiration date
- Allocation date
- Year of allocation

#### Leave Transaction
- Transaction ID
- Employee ID
- Leave type
- Amount (in days)
- Transaction type (allocation, usage, expiration, adjustment)
- Date
- Reason/Notes
- Approval status
- Approver ID

#### Leave Request
- Request ID
- Employee ID
- Leave type
- Start date
- End date
- Duration (in days)
- Usage type (full-day, AM, PM, hourly)
- Reason
- Status (pending, approved, rejected, cancelled)
- Requested date
- Approved date
- Approver ID

### 7.2 Configuration Entities

#### Leave Policy
- Policy ID
- Employment type
- Base annual leave days
- Accrual rate
- Maximum leave days
- Expiration period (in days)
- Carryover rules
- Rounding rules

#### Holiday Calendar
- Date
- Holiday name
- Holiday type (legal, company)
- Applicable employment types

## 8. Business Rules

### 8.1 Leave Request Validation

1. Requested leave amount ≤ Available balance
2. Request date is future date or current date
3. No overlapping leave requests for same employee
4. Leave type is valid and active
5. Employee is active (not terminated)

### 8.2 Approval Workflow

1. Employee submits leave request
2. Direct manager receives notification
3. Manager approves/rejects with optional comments
4. System updates leave balance upon approval
5. Employee receives confirmation notification

### 8.3 Automatic Processes

1. **Monthly accrual**: Runs on 1st of each month for first-year employees
2. **Annual allocation**: Runs on January 1st for all eligible employees
3. **Expiration check**: Daily job to identify and process expired leave
4. **Notification scheduler**: Daily job to send upcoming expiration warnings
5. **Usage recommendations**: Weekly job to suggest optimal leave usage

## 9. Reporting Requirements

### 9.1 Employee Reports

- Current leave balance by type
- Leave usage history
- Upcoming expiration dates
- Projected year-end balance

### 9.2 Manager Reports

- Team leave balance summary
- Team leave usage patterns
- Pending leave requests
- Employees with high unused leave

### 9.3 HR Reports

- Company-wide leave statistics
- Leave accrual vs. usage trends
- Compliance reporting (Labor Standards Act)
- Expired leave summary
- Financial implications of unused leave

## 10. Implementation Phases

### Phase 1: Core Leave Management
- Leave balance tracking
- Manual leave allocation
- Basic leave request and approval
- Simple leave usage recording

### Phase 2: Automated Processes
- Automatic monthly accrual
- Automatic annual allocation
- Expiration tracking and processing
- Substitute holiday calculation

### Phase 3: Notifications
- Email/SMS notifications
- Expiration warnings
- Usage recommendations
- Approval workflow notifications

### Phase 4: Advanced Features
- Predictive leave suggestions
- Advanced reporting and analytics
- Mobile app integration
- Calendar integration

## 11. Compliance and Audit

### 11.1 Labor Law Compliance

- System must enforce minimum leave requirements per Korean Labor Standards Act
- Audit log for all leave transactions
- Retention of leave records for 3 years minimum

### 11.2 Audit Trail

All operations must be logged:
- Who performed the action
- What action was performed
- When it was performed
- Before and after values (for updates)
- IP address and device information

### 11.3 Data Privacy

- Leave data is personal information and must be protected
- Access control: Employees see own data, managers see team data, HR sees all
- Secure transmission and storage
- Regular security audits

## 12. Technical Considerations

### 12.1 Performance

- Leave balance queries must be optimized for large employee bases
- Batch processes (accrual, allocation) should run efficiently
- Notification system should handle high volume

### 12.2 Scalability

- System should support growing number of employees
- Archive old leave transactions
- Partition data by year for performance

### 12.3 Reliability

- Transaction consistency for leave operations
- Automatic retry for failed notifications
- Backup and recovery procedures

## 13. Future Enhancements

- Integration with payroll system for unused leave payout
- Machine learning for leave usage prediction
- Chatbot for leave balance queries
- Integration with time tracking systems
- Support for international leave policies

---

**Document Version**: 1.0
**Last Updated**: 2026-01-31
**Author**: Claude (via GitHub Issue #3)
