;; Monitoring Protocol Contract
;; Tracks long-term carbon retention and monitoring schedules

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_MONITORING_NOT_FOUND (err u301))
(define-constant ERR_INVALID_PERIOD (err u302))
(define-constant ERR_OVERDUE_MONITORING (err u303))

;; Monitoring frequency constants (in blocks)
(define-constant MONITORING_FREQUENCY_QUARTERLY u2160) ;; ~90 days
(define-constant MONITORING_FREQUENCY_ANNUAL u8640)   ;; ~360 days

;; Data structures
(define-map monitoring-schedules
  { project-id: uint }
  {
    frequency: uint,
    last-monitoring: uint,
    next-monitoring: uint,
    monitoring-count: uint,
    active: bool
  }
)

(define-map monitoring-reports
  { report-id: uint }
  {
    project-id: uint,
    reporter: principal,
    report-date: uint,
    retention-rate: uint, ;; percentage (0-100)
    notes: (string-ascii 200),
    verified: bool
  }
)

(define-map report-counter { id: uint } { count: uint })

;; Initialize report counter
(map-set report-counter { id: u0 } { count: u0 })

;; Read-only functions
(define-read-only (get-monitoring-schedule (project-id uint))
  (map-get? monitoring-schedules { project-id: project-id })
)

(define-read-only (get-monitoring-report (report-id uint))
  (map-get? monitoring-reports { report-id: report-id })
)

(define-read-only (get-report-count)
  (default-to u0 (get count (map-get? report-counter { id: u0 })))
)

(define-read-only (is-monitoring-overdue (project-id uint))
  (match (get-monitoring-schedule project-id)
    schedule
      (and
        (get active schedule)
        (>= block-height (get next-monitoring schedule))
      )
    false
  )
)

;; Public functions
(define-public (setup-monitoring (project-id uint) (frequency uint))
  (begin
    (asserts! (or (is-eq frequency MONITORING_FREQUENCY_QUARTERLY)
                  (is-eq frequency MONITORING_FREQUENCY_ANNUAL)) ERR_INVALID_PERIOD)

    (map-set monitoring-schedules
      { project-id: project-id }
      {
        frequency: frequency,
        last-monitoring: block-height,
        next-monitoring: (+ block-height frequency),
        monitoring-count: u0,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (submit-monitoring-report (project-id uint) (retention-rate uint) (notes (string-ascii 200)))
  (let
    (
      (current-count (get-report-count))
      (new-report-id (+ current-count u1))
      (schedule (unwrap! (get-monitoring-schedule project-id) ERR_MONITORING_NOT_FOUND))
    )
    (asserts! (<= retention-rate u100) ERR_INVALID_PERIOD)
    (asserts! (get active schedule) ERR_UNAUTHORIZED)

    (map-set monitoring-reports
      { report-id: new-report-id }
      {
        project-id: project-id,
        reporter: tx-sender,
        report-date: block-height,
        retention-rate: retention-rate,
        notes: notes,
        verified: false
      }
    )

    (map-set report-counter { id: u0 } { count: new-report-id })

    ;; Update monitoring schedule
    (map-set monitoring-schedules
      { project-id: project-id }
      (merge schedule {
        last-monitoring: block-height,
        next-monitoring: (+ block-height (get frequency schedule)),
        monitoring-count: (+ (get monitoring-count schedule) u1)
      })
    )

    (ok new-report-id)
  )
)

(define-public (verify-monitoring-report (report-id uint))
  (let
    (
      (report (unwrap! (get-monitoring-report report-id) ERR_MONITORING_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set monitoring-reports
      { report-id: report-id }
      (merge report { verified: true })
    )
    (ok true)
  )
)

(define-public (suspend-monitoring (project-id uint))
  (let
    (
      (schedule (unwrap! (get-monitoring-schedule project-id) ERR_MONITORING_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set monitoring-schedules
      { project-id: project-id }
      (merge schedule { active: false })
    )
    (ok true)
  )
)
