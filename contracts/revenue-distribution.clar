;; Revenue Distribution Contract
;; Allocates income from completed infrastructure

(define-data-var contract-owner principal tx-sender)

;; Project revenue information
(define-map projects
  { project-id: uint }
  {
    total-revenue: uint,
    last-distribution: uint,
    is-active: bool,
    project-owner: principal,
    is-completed: bool
  }
)

;; Revenue claimed by investors
(define-map revenue-claimed
  { project-id: uint, investor: principal }
  { amount: uint }
)

;; Ownership percentages (in a real implementation, this would come from the investment contract)
(define-map ownership-percentages
  { project-id: uint, investor: principal }
  { percentage: uint }  ;; in basis points (100% = 10000)
)

;; Initialize a project for revenue distribution
(define-public (initialize-project (project-id uint) (project-owner principal) (is-completed bool))
  (begin
    ;; In a real implementation, we would check if the project is completed
    ;; through the construction-milestone contract
    ;; For simplicity, we'll accept a boolean parameter
    (asserts! is-completed (err u402))

    (map-set projects
      { project-id: project-id }
      {
        total-revenue: u0,
        last-distribution: u0,
        is-active: true,
        project-owner: project-owner,
        is-completed: is-completed
      }
    )

    (ok true)
  )
)

;; Set ownership percentage for an investor
(define-public (set-ownership-percentage (project-id uint) (investor principal) (percentage uint))
  (begin
    (asserts! (<= percentage u10000) (err u407))

    (map-set ownership-percentages
      { project-id: project-id, investor: investor }
      { percentage: percentage }
    )

    (ok true)
  )
)

;; Add revenue to a project
(define-public (add-revenue (project-id uint) (amount uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u403)))
  )
    (asserts! (get is-active project) (err u404))

    (map-set projects
      { project-id: project-id }
      (merge project {
        total-revenue: (+ (get total-revenue project) amount),
        last-distribution: block-height
      })
    )

    (ok true)
  )
)

;; Claim revenue for an investor
(define-public (claim-revenue (project-id uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u403)))
    (ownership (default-to { percentage: u0 } (map-get? ownership-percentages { project-id: project-id, investor: tx-sender })))
    (claimed (default-to { amount: u0 } (map-get? revenue-claimed { project-id: project-id, investor: tx-sender })))
    (total-revenue (get total-revenue project))
    (entitled-amount (/ (* total-revenue (get percentage ownership)) u10000))
    (claimable-amount (- entitled-amount (get amount claimed)))
  )
    (asserts! (get is-active project) (err u404))
    (asserts! (> claimable-amount u0) (err u405))

    ;; In a real implementation, this would transfer tokens to the investor

    (map-set revenue-claimed
      { project-id: project-id, investor: tx-sender }
      { amount: entitled-amount }
    )

    (ok claimable-amount)
  )
)

;; Deactivate a project (no more revenue)
(define-public (deactivate-project (project-id uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u403)))
  )
    (asserts! (is-eq tx-sender (get project-owner project)) (err u406))

    (map-set projects
      { project-id: project-id }
      (merge project { is-active: false })
    )

    (ok true)
  )
)

;; Get claimable revenue for an investor
(define-read-only (get-claimable-revenue (project-id uint) (investor principal))
  (let (
    (project (default-to
              {
                total-revenue: u0,
                last-distribution: u0,
                is-active: false,
                project-owner: tx-sender,
                is-completed: false
              }
              (map-get? projects { project-id: project-id })))
    (ownership (default-to { percentage: u0 } (map-get? ownership-percentages { project-id: project-id, investor: investor })))
    (claimed (default-to { amount: u0 } (map-get? revenue-claimed { project-id: project-id, investor: investor })))
    (total-revenue (get total-revenue project))
    (entitled-amount (/ (* total-revenue (get percentage ownership)) u10000))
  )
    (- entitled-amount (get amount claimed))
  )
)

;; Get project revenue information
(define-read-only (get-project-revenue (project-id uint))
  (map-get? projects { project-id: project-id })
)
