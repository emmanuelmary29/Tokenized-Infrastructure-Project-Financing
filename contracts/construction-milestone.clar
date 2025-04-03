;; Construction Milestone Contract
;; Monitors progress against project plan

(define-data-var contract-owner principal tx-sender)

;; Project milestones
(define-map projects
  { project-id: uint }
  {
    total-milestones: uint,
    completed-milestones: uint,
    project-owner: principal,
    is-completed: bool,
    funding-closed: bool
  }
)

;; Milestone details
(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-utf8 200),
    funding-percentage: uint,  ;; in basis points (100% = 10000)
    is-completed: bool,
    is-funded: bool
  }
)

;; Initialize project milestones
(define-public (initialize-project (project-id uint) (project-owner principal) (funding-closed bool))
  (begin
    ;; In a real implementation, we would check if funding is closed
    ;; through the investment-management contract
    ;; For simplicity, we'll accept a boolean parameter
    (asserts! funding-closed (err u302))

    (map-set projects
      { project-id: project-id }
      {
        total-milestones: u0,
        completed-milestones: u0,
        project-owner: project-owner,
        is-completed: false,
        funding-closed: funding-closed
      }
    )

    (ok true)
  )
)

;; Add a milestone to a project
(define-public (add-milestone
    (project-id uint)
    (milestone-id uint)
    (description (string-utf8 200))
    (funding-percentage uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u303)))
  )
    (asserts! (is-eq tx-sender (get project-owner project)) (err u304))
    (asserts! (is-none (map-get? milestones { project-id: project-id, milestone-id: milestone-id })) (err u305))
    (asserts! (<= funding-percentage u10000) (err u306))

    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        description: description,
        funding-percentage: funding-percentage,
        is-completed: false,
        is-funded: false
      }
    )

    (map-set projects
      { project-id: project-id }
      (merge project { total-milestones: (+ (get total-milestones project) u1) })
    )

    (ok true)
  )
)

;; Complete a milestone
(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) (err u303)))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err u307)))
  )
    (asserts! (is-eq tx-sender (get project-owner project)) (err u304))
    (asserts! (not (get is-completed milestone)) (err u308))

    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone { is-completed: true })
    )

    (map-set projects
      { project-id: project-id }
      (merge project {
        completed-milestones: (+ (get completed-milestones project) u1),
        is-completed: (is-eq (+ (get completed-milestones project) u1) (get total-milestones project))
      })
    )

    (ok true)
  )
)

;; Fund a milestone
(define-public (fund-milestone (project-id uint) (milestone-id uint))
  (let (
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err u307)))
  )
    (asserts! (get is-completed milestone) (err u309))
    (asserts! (not (get is-funded milestone)) (err u310))

    ;; In a real implementation, this would transfer funds from an escrow

    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone { is-funded: true })
    )

    (ok true)
  )
)

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

;; Get project progress
(define-read-only (get-project-progress (project-id uint))
  (map-get? projects { project-id: project-id })
)
