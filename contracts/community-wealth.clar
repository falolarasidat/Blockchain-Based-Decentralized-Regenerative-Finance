;; Community Wealth Contract
;; Builds regenerative community prosperity

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_COMMUNITY_NOT_FOUND (err u501))
(define-constant ERR_INSUFFICIENT_BALANCE (err u502))
(define-constant ERR_INVALID_DISTRIBUTION (err u503))

;; Community structure
(define-map communities
  { community-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    admin: principal,
    total-wealth: uint,
    member-count: uint,
    wealth-distribution-model: (string-ascii 50),
    creation-block: uint
  }
)

;; Community members
(define-map community-members
  { community-id: uint, member: principal }
  {
    contribution-score: uint,
    wealth-share: uint,
    join-block: uint,
    active: bool
  }
)

;; Wealth distribution records
(define-map wealth-distributions
  { distribution-id: uint }
  {
    community-id: uint,
    total-amount: uint,
    distribution-block: uint,
    distribution-type: (string-ascii 50)
  }
)

;; Counters
(define-data-var community-counter uint u0)
(define-data-var distribution-counter uint u0)

;; Create community
(define-public (create-community
  (name (string-ascii 100))
  (location (string-ascii 100))
  (wealth-distribution-model (string-ascii 50)))
  (let
    (
      (community-id (+ (var-get community-counter) u1))
    )
    (map-set communities
      { community-id: community-id }
      {
        name: name,
        location: location,
        admin: tx-sender,
        total-wealth: u0,
        member-count: u0,
        wealth-distribution-model: wealth-distribution-model,
        creation-block: block-height
      }
    )
    (var-set community-counter community-id)
    (ok community-id)
  )
)

;; Add community member
(define-public (add-member (community-id uint) (member principal) (contribution-score uint))
  (let
    (
      (community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get admin community)) ERR_UNAUTHORIZED)

    (map-set community-members
      { community-id: community-id, member: member }
      {
        contribution-score: contribution-score,
        wealth-share: u0,
        join-block: block-height,
        active: true
      }
    )

    (map-set communities
      { community-id: community-id }
      (merge community { member-count: (+ (get member-count community) u1) })
    )
    (ok true)
  )
)

;; Contribute to community wealth
(define-public (contribute-wealth (community-id uint) (amount uint))
  (let
    (
      (community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (map-set communities
      { community-id: community-id }
      (merge community { total-wealth: (+ (get total-wealth community) amount) })
    )
    (ok true)
  )
)

;; Distribute wealth to community
(define-public (distribute-wealth (community-id uint) (distribution-type (string-ascii 50)))
  (let
    (
      (community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND))
      (distribution-id (+ (var-get distribution-counter) u1))
      (total-wealth (get total-wealth community))
      (member-count (get member-count community))
      (per-member-share (/ total-wealth member-count))
    )
    (asserts! (is-eq tx-sender (get admin community)) ERR_UNAUTHORIZED)
    (asserts! (> total-wealth u0) ERR_INSUFFICIENT_BALANCE)

    (map-set wealth-distributions
      { distribution-id: distribution-id }
      {
        community-id: community-id,
        total-amount: total-wealth,
        distribution-block: block-height,
        distribution-type: distribution-type
      }
    )

    ;; Reset community wealth after distribution
    (map-set communities
      { community-id: community-id }
      (merge community { total-wealth: u0 })
    )

    (var-set distribution-counter distribution-id)
    (ok per-member-share)
  )
)

;; Get community details
(define-read-only (get-community (community-id uint))
  (map-get? communities { community-id: community-id })
)

;; Get member details
(define-read-only (get-member (community-id uint) (member principal))
  (map-get? community-members { community-id: community-id, member: member })
)

;; Get distribution details
(define-read-only (get-distribution (distribution-id uint))
  (map-get? wealth-distributions { distribution-id: distribution-id })
)
