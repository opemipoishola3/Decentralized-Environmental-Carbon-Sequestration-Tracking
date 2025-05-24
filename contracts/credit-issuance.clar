;; Credit Issuance Contract
;; Creates tradable sequestration units (carbon credits)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INSUFFICIENT_BALANCE (err u501))
(define-constant ERR_CREDIT_NOT_FOUND (err u502))
(define-constant ERR_INVALID_AMOUNT (err u503))
(define-constant ERR_CREDIT_RETIRED (err u504))

;; Credit status constants
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_RETIRED u2)
(define-constant STATUS_SUSPENDED u3)

;; Data structures
(define-map carbon-credits
  { credit-id: uint }
  {
    project-id: uint,
    owner: principal,
    carbon-amount: uint, ;; in tons CO2
    issuance-date: uint,
    vintage-year: uint,
    status: uint,
    verification-standard: uint
  }
)

(define-map credit-balances
  { owner: principal }
  { balance: uint }
)

(define-map credit-counter { id: uint } { count: uint })
(define-map total-credits-issued { id: uint } { total: uint })
(define-map total-credits-retired { id: uint } { total: uint })

;; Initialize counters
(map-set credit-counter { id: u0 } { count: u0 })
(map-set total-credits-issued { id: u0 } { total: u0 })
(map-set total-credits-retired { id: u0 } { total: u0 })

;; Read-only functions
(define-read-only (get-credit (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

(define-read-only (get-balance (owner principal))
  (default-to u0 (get balance (map-get? credit-balances { owner: owner })))
)

(define-read-only (get-credit-count)
  (default-to u0 (get count (map-get? credit-counter { id: u0 })))
)

(define-read-only (get-total-credits-issued)
  (default-to u0 (get total (map-get? total-credits-issued { id: u0 })))
)

(define-read-only (get-total-credits-retired)
  (default-to u0 (get total (map-get? total-credits-retired { id: u0 })))
)

;; Public functions
(define-public (issue-credits (project-id uint) (recipient principal) (carbon-amount uint) (vintage-year uint) (verification-standard uint))
  (let
    (
      (current-count (get-credit-count))
      (new-credit-id (+ current-count u1))
      (current-balance (get-balance recipient))
      (current-total (get-total-credits-issued))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> carbon-amount u0) ERR_INVALID_AMOUNT)

    (map-set carbon-credits
      { credit-id: new-credit-id }
      {
        project-id: project-id,
        owner: recipient,
        carbon-amount: carbon-amount,
        issuance-date: block-height,
        vintage-year: vintage-year,
        status: STATUS_ACTIVE,
        verification-standard: verification-standard
      }
    )

    (map-set credit-counter { id: u0 } { count: new-credit-id })
    (map-set credit-balances { owner: recipient } { balance: (+ current-balance carbon-amount) })
    (map-set total-credits-issued { id: u0 } { total: (+ current-total carbon-amount) })

    (ok new-credit-id)
  )
)

(define-public (transfer-credits (credit-id uint) (recipient principal))
  (let
    (
      (credit (unwrap! (get-credit credit-id) ERR_CREDIT_NOT_FOUND))
      (current-owner (get owner credit))
      (carbon-amount (get carbon-amount credit))
      (sender-balance (get-balance tx-sender))
      (recipient-balance (get-balance recipient))
    )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status credit) STATUS_ACTIVE) ERR_CREDIT_RETIRED)
    (asserts! (>= sender-balance carbon-amount) ERR_INSUFFICIENT_BALANCE)

    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit { owner: recipient })
    )

    (map-set credit-balances { owner: tx-sender } { balance: (- sender-balance carbon-amount) })
    (map-set credit-balances { owner: recipient } { balance: (+ recipient-balance carbon-amount) })

    (ok true)
  )
)

(define-public (retire-credits (credit-id uint))
  (let
    (
      (credit (unwrap! (get-credit credit-id) ERR_CREDIT_NOT_FOUND))
      (current-owner (get owner credit))
      (carbon-amount (get carbon-amount credit))
      (owner-balance (get-balance current-owner))
      (current-retired (get-total-credits-retired))
    )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status credit) STATUS_ACTIVE) ERR_CREDIT_RETIRED)
    (asserts! (>= owner-balance carbon-amount) ERR_INSUFFICIENT_BALANCE)

    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit { status: STATUS_RETIRED })
    )

    (map-set credit-balances { owner: tx-sender } { balance: (- owner-balance carbon-amount) })
    (map-set total-credits-retired { id: u0 } { total: (+ current-retired carbon-amount) })

    (ok true)
  )
)

(define-public (suspend-credits (credit-id uint))
  (let
    (
      (credit (unwrap! (get-credit credit-id) ERR_CREDIT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status credit) STATUS_ACTIVE) ERR_CREDIT_RETIRED)

    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit { status: STATUS_SUSPENDED })
    )
    (ok true)
  )
)
