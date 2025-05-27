;; Ecosystem Restoration Contract
;; Finances ecosystem regeneration projects

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_PROJECT_NOT_FOUND (err u401))
(define-constant ERR_INSUFFICIENT_FUNDING (err u402))
(define-constant ERR_INVALID_MILESTONE (err u403))

;; Project statuses
(define-constant STATUS_PROPOSED u1)
(define-constant STATUS_FUNDED u2)
(define-constant STATUS_IN_PROGRESS u3)
(define-constant STATUS_COMPLETED u4)

;; Restoration project structure
(define-map restoration-projects
  { project-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    project-lead: principal,
    funding-goal: uint,
    current-funding: uint,
    ecosystem-type: (string-ascii 50),
    expected-impact: uint,
    status: uint,
    start-block: uint,
    target-completion: uint
  }
)

;; Project milestones
(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    funding-release: uint,
    completed: bool,
    verification-block: uint
  }
)

;; Project counter
(define-data-var project-counter uint u0)

;; Create restoration project
(define-public (create-restoration-project
  (name (string-ascii 100))
  (location (string-ascii 100))
  (funding-goal uint)
  (ecosystem-type (string-ascii 50))
  (expected-impact uint)
  (completion-blocks uint))
  (let
    (
      (project-id (+ (var-get project-counter) u1))
    )
    (map-set restoration-projects
      { project-id: project-id }
      {
        name: name,
        location: location,
        project-lead: tx-sender,
        funding-goal: funding-goal,
        current-funding: u0,
        ecosystem-type: ecosystem-type,
        expected-impact: expected-impact,
        status: STATUS_PROPOSED,
        start-block: block-height,
        target-completion: (+ block-height completion-blocks)
      }
    )
    (var-set project-counter project-id)
    (ok project-id)
  )
)

;; Fund restoration project
(define-public (fund-project (project-id uint) (amount uint))
  (let
    (
      (project (unwrap! (map-get? restoration-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
      (new-funding (+ (get current-funding project) amount))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (map-set restoration-projects
      { project-id: project-id }
      (merge project {
        current-funding: new-funding,
        status: (if (>= new-funding (get funding-goal project)) STATUS_FUNDED STATUS_PROPOSED)
      })
    )
    (ok new-funding)
  )
)

;; Add project milestone
(define-public (add-milestone
  (project-id uint)
  (milestone-id uint)
  (description (string-ascii 200))
  (funding-release uint))
  (let
    (
      (project (unwrap! (map-get? restoration-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get project-lead project)) ERR_UNAUTHORIZED)

    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        description: description,
        funding-release: funding-release,
        completed: false,
        verification-block: u0
      }
    )
    (ok true)
  )
)

;; Complete milestone
(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project (unwrap! (map-get? restoration-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
      (milestone (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
    )
    (asserts! (is-eq tx-sender (get project-lead project)) ERR_UNAUTHORIZED)

    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone {
        completed: true,
        verification-block: block-height
      })
    )

    ;; Release milestone funding
    (try! (as-contract (stx-transfer? (get funding-release milestone) tx-sender (get project-lead project))))
    (ok true)
  )
)

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? restoration-projects { project-id: project-id })
)

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)
