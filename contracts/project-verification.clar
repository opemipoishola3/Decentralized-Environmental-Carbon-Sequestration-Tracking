;; Project Verification Contract
;; Validates carbon capture initiatives and manages project registration

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROJECT_EXISTS (err u101))
(define-constant ERR_PROJECT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Project status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Data structures
(define-map projects
  { project-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 100),
    project-type: (string-ascii 50),
    status: uint,
    verification-date: uint,
    verifier: (optional principal)
  }
)

(define-map project-counter { id: uint } { count: uint })

;; Initialize project counter
(map-set project-counter { id: u0 } { count: u0 })

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-project-count)
  (default-to u0 (get count (map-get? project-counter { id: u0 })))
)

(define-read-only (is-project-verified (project-id uint))
  (match (get-project project-id)
    project (is-eq (get status project) STATUS_VERIFIED)
    false
  )
)

;; Public functions
(define-public (register-project (name (string-ascii 100)) (location (string-ascii 100)) (project-type (string-ascii 50)))
  (let
    (
      (current-count (get-project-count))
      (new-project-id (+ current-count u1))
    )
    (asserts! (is-none (get-project new-project-id)) ERR_PROJECT_EXISTS)

    (map-set projects
      { project-id: new-project-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        project-type: project-type,
        status: STATUS_PENDING,
        verification-date: u0,
        verifier: none
      }
    )

    (map-set project-counter { id: u0 } { count: new-project-id })
    (ok new-project-id)
  )
)

(define-public (verify-project (project-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status project) STATUS_PENDING) ERR_INVALID_STATUS)

    (map-set projects
      { project-id: project-id }
      (merge project {
        status: STATUS_VERIFIED,
        verification-date: block-height,
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)

(define-public (reject-project (project-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status project) STATUS_PENDING) ERR_INVALID_STATUS)

    (map-set projects
      { project-id: project-id }
      (merge project {
        status: STATUS_REJECTED,
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)
