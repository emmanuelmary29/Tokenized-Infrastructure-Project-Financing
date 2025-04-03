;; Investment Management Contract
;; Tracks capital contributions and ownership

(define-data-var contract-owner principal tx-sender)

;; Project funding information
(define-map projects
  { project-id: uint }
  {
    total-funding: uint,
    funding-target: uint,
    is-funding-open: bool,
    project-owner: principal,
    is-verified: bool
  }
)

;; Investor holdings for each project
(define-map investments
  { project-id: uint, investor: principal }
  { amount: uint }
)

;; Total tokens issued for a project
(define-map project-tokens
  { project-id: uint }
  { total-tokens: uint }
)

;; Initialize a project for funding
(define-public (initialize-project (project-id uint) (funding-target uint) (is-verified bool))
  (begin
    ;; In a real implementation, we would check if the project is verified
    ;; through the project-verification contract
    ;; For simplicity, we'll accept a boolean parameter
    (asserts! is-verified (err u200))

    (map-set projects
      { project-id: project-id }
      {
        total-funding: u0,
        funding-target: funding-target,
        is-funding-open: true,
        project-owner: tx-sender,
        is-verified: is-verified
      }
    )

    (map-set project-tokens
      { project-id: project-id }
      { total-tokens: u0 }
    )

    (ok true)
  )
)

;; Invest in a project
(define-public (invest (project-id uint) (amount uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u203)))
    (current-investment (default-to { amount: u0 } (map-get? investments { project-id: project-id, investor: tx-sender })))
    (new-total-funding (+ (get total-funding project) amount))
  )
    (asserts! (get is-funding-open project) (err u204))
    (asserts! (<= new-total-funding (get funding-target project)) (err u205))

    ;; Update project funding
    (map-set projects
      { project-id: project-id }
      (merge project { total-funding: new-total-funding })
    )

    ;; Update investor's contribution
    (map-set investments
      { project-id: project-id, investor: tx-sender }
      { amount: (+ (get amount current-investment) amount) }
    )

    ;; Issue tokens (1:1 with investment amount for simplicity)
    (let (
      (tokens (default-to { total-tokens: u0 } (map-get? project-tokens { project-id: project-id })))
    )
      (map-set project-tokens
        { project-id: project-id }
        { total-tokens: (+ (get total-tokens tokens) amount) }
      )
    )

    (ok true)
  )
)

;; Close funding for a project
(define-public (close-funding (project-id uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u203)))
  )
    (asserts! (is-eq tx-sender (get project-owner project)) (err u206))

    (map-set projects
      { project-id: project-id }
      (merge project { is-funding-open: false })
    )

    (ok true)
  )
)

;; Get investment amount for an investor
(define-read-only (get-investment (project-id uint) (investor principal))
  (default-to { amount: u0 } (map-get? investments { project-id: project-id, investor: investor }))
)

;; Get project funding status
(define-read-only (get-project-funding (project-id uint))
  (map-get? projects { project-id: project-id })
)

;; Get ownership percentage (simplified)
(define-read-only (get-ownership-percentage (project-id uint) (investor principal))
  (let (
    (investment (get amount (default-to { amount: u0 } (map-get? investments { project-id: project-id, investor: investor }))))
    (tokens (default-to { total-tokens: u0 } (map-get? project-tokens { project-id: project-id })))
    (total-tokens (get total-tokens tokens))
  )
    (if (is-eq total-tokens u0)
      u0
      (/ (* investment u10000) total-tokens)  ;; Returns basis points (100% = 10000)
    )
  )
)
