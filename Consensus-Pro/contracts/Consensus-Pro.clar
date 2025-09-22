;; Justice DAO - Crowdsourced Legal Research with Expert Validation
;; A decentralized platform for collaborative legal research

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NOT_FOUND (err u1002))
(define-constant ERR_ALREADY_EXISTS (err u1003))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1004))
(define-constant ERR_INVALID_STATUS (err u1005))
(define-constant ERR_ALREADY_VOTED (err u1006))
(define-constant ERR_NOT_EXPERT (err u1007))

;; Data Variables
(define-data-var next-research-id uint u1)
(define-data-var next-expert-id uint u1)
(define-data-var min-expert-votes uint u3)
(define-data-var research-reward uint u1000000) ;; 1 STX in microSTX
(define-data-var expert-reward uint u500000)   ;; 0.5 STX in microSTX

;; Research Status Types
(define-constant STATUS_SUBMITTED u1)
(define-constant STATUS_UNDER_REVIEW u2)
(define-constant STATUS_VALIDATED u3)
(define-constant STATUS_REJECTED u4)

;; Data Maps
(define-map research-submissions
  uint
  {
    researcher: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    ipfs-hash: (string-ascii 100),
    status: uint,
    created-at: uint,
    reward-claimed: bool,
    validation-votes: uint,
    rejection-votes: uint
  }
)

(define-map experts
  uint
  {
    expert: principal,
    name: (string-ascii 50),
    specialization: (string-ascii 100),
    reputation-score: uint,
    total-validations: uint,
    active: bool,
    registered-at: uint
  }
)

(define-map expert-by-principal
  principal
  uint
)

(define-map research-votes
  {research-id: uint, expert-id: uint}
  {
    vote: bool, ;; true for validate, false for reject
    comment: (string-ascii 200),
    voted-at: uint
  }
)

(define-map user-contributions
  principal
  {
    total-submissions: uint,
    validated-submissions: uint,
    tokens-earned: uint
  }
)

;; Read-only functions

(define-read-only (get-research-submission (research-id uint))
  (map-get? research-submissions research-id)
)

(define-read-only (get-expert (expert-id uint))
  (map-get? experts expert-id)
)

(define-read-only (get-expert-by-principal (expert-principal principal))
  (match (map-get? expert-by-principal expert-principal)
    expert-id (map-get? experts expert-id)
    none
  )
)

(define-read-only (get-research-vote (research-id uint) (expert-id uint))
  (map-get? research-votes {research-id: research-id, expert-id: expert-id})
)

(define-read-only (get-user-contributions (user principal))
  (default-to 
    {total-submissions: u0, validated-submissions: u0, tokens-earned: u0}
    (map-get? user-contributions user)
  )
)

(define-read-only (get-next-research-id)
  (var-get next-research-id)
)

(define-read-only (get-next-expert-id)
  (var-get next-expert-id)
)

(define-read-only (is-expert (user principal))
  (match (map-get? expert-by-principal user)
    expert-id 
      (match (map-get? experts expert-id)
        expert-data (get active expert-data)
        false
      )
    false
  )
)

;; Private functions

(define-private (update-user-stats (user principal) (increment-submissions bool) (increment-validated bool) (token-reward uint))
  (let (
    (current-stats (get-user-contributions user))
    (new-submissions (if increment-submissions 
                       (+ (get total-submissions current-stats) u1)
                       (get total-submissions current-stats)))
    (new-validated (if increment-validated 
                     (+ (get validated-submissions current-stats) u1)
                     (get validated-submissions current-stats)))
    (new-tokens (+ (get tokens-earned current-stats) token-reward))
  )
    (map-set user-contributions user {
      total-submissions: new-submissions,
      validated-submissions: new-validated,
      tokens-earned: new-tokens
    })
  )
)

(define-private (update-expert-reputation (expert-id uint) (correct-vote bool))
  (match (map-get? experts expert-id)
    expert-data
      (let (
        (reputation-change (if correct-vote u10 u0))
        (new-reputation (+ (get reputation-score expert-data) reputation-change))
        (new-validations (+ (get total-validations expert-data) u1))
      )
        (map-set experts expert-id (merge expert-data {
          reputation-score: new-reputation,
          total-validations: new-validations
        }))
        (ok true)
      )
    (err u404)
  )
)

;; Public functions

(define-public (submit-research 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (ipfs-hash (string-ascii 100))
)
  (let (
    (research-id (var-get next-research-id))
  )
    (map-set research-submissions research-id {
      researcher: tx-sender,
      title: title,
      description: description,
      category: category,
      ipfs-hash: ipfs-hash,
      status: STATUS_SUBMITTED,
      created-at: stacks-block-height,
      reward-claimed: false,
      validation-votes: u0,
      rejection-votes: u0
    })
    (update-user-stats tx-sender true false u0)
    (var-set next-research-id (+ research-id u1))
    (ok research-id)
  )
)

(define-public (register-expert 
  (name (string-ascii 50))
  (specialization (string-ascii 100))
)
  (let (
    (expert-id (var-get next-expert-id))
  )
    (asserts! (is-none (map-get? expert-by-principal tx-sender)) ERR_ALREADY_EXISTS)
    
    (map-set experts expert-id {
      expert: tx-sender,
      name: name,
      specialization: specialization,
      reputation-score: u100, ;; Starting reputation
      total-validations: u0,
      active: true,
      registered-at: stacks-block-height
    })
    
    (map-set expert-by-principal tx-sender expert-id)
    (var-set next-expert-id (+ expert-id u1))
    (ok expert-id)
  )
)

(define-public (vote-on-research 
  (research-id uint)
  (validate bool)
  (comment (string-ascii 200))
)
  (let (
    (expert-id-opt (map-get? expert-by-principal tx-sender))
  )
    (asserts! (is-some expert-id-opt) ERR_NOT_EXPERT)
    (let (
      (expert-id (unwrap-panic expert-id-opt))
      (research-opt (map-get? research-submissions research-id))
    )
      (asserts! (is-some research-opt) ERR_NOT_FOUND)
      (asserts! (is-none (map-get? research-votes {research-id: research-id, expert-id: expert-id})) ERR_ALREADY_VOTED)
      
      (let (
        (research (unwrap-panic research-opt))
      )
        (asserts! (is-eq (get status research) STATUS_SUBMITTED) ERR_INVALID_STATUS)
        
        ;; Record the vote
        (map-set research-votes 
          {research-id: research-id, expert-id: expert-id}
          {
            vote: validate,
            comment: comment,
            voted-at: stacks-block-height
          }
        )
        
        ;; Update research vote counts
        (let (
          (new-validation-votes (if validate (+ (get validation-votes research) u1) (get validation-votes research)))
          (new-rejection-votes (if validate (get rejection-votes research) (+ (get rejection-votes research) u1)))
          (total-votes (+ new-validation-votes new-rejection-votes))
        )
          (map-set research-submissions research-id (merge research {
            validation-votes: new-validation-votes,
            rejection-votes: new-rejection-votes,
            status: (if (>= total-votes (var-get min-expert-votes)) STATUS_UNDER_REVIEW STATUS_SUBMITTED)
          }))
          
          ;; Check if we have enough votes to finalize
          (if (>= total-votes (var-get min-expert-votes))
            (finalize-research-status research-id)
            (ok true)
          )
        )
      )
    )
  )
)

(define-public (finalize-research-status (research-id uint))
  (let (
    (research-opt (map-get? research-submissions research-id))
  )
    (asserts! (is-some research-opt) ERR_NOT_FOUND)
    (let (
      (research (unwrap-panic research-opt))
      (validation-votes (get validation-votes research))
      (rejection-votes (get rejection-votes research))
      (is-validated (> validation-votes rejection-votes))
      (new-status (if is-validated STATUS_VALIDATED STATUS_REJECTED))
    )
      (map-set research-submissions research-id (merge research {
        status: new-status
      }))
      
      ;; Reward researcher if validated
      (if is-validated
        (begin
          (try! (stx-transfer? (var-get research-reward) (as-contract tx-sender) (get researcher research)))
          (update-user-stats (get researcher research) false true (var-get research-reward))
        )
        true
      )
      
      (ok is-validated)
    )
  )
)

(define-public (claim-expert-reward (research-id uint))
  (let (
    (expert-id-opt (map-get? expert-by-principal tx-sender))
  )
    (asserts! (is-some expert-id-opt) ERR_NOT_EXPERT)
    (let (
      (expert-id (unwrap-panic expert-id-opt))
      (research-opt (map-get? research-submissions research-id))
      (vote-opt (map-get? research-votes {research-id: research-id, expert-id: expert-id}))
    )
      (asserts! (is-some research-opt) ERR_NOT_FOUND)
      (asserts! (is-some vote-opt) ERR_NOT_FOUND)
      
      (let (
        (research (unwrap-panic research-opt))
        (vote (unwrap-panic vote-opt))
        (is-validated (is-eq (get status research) STATUS_VALIDATED))
        (voted-correctly (is-eq (get vote vote) is-validated))
      )
        (asserts! (or (is-eq (get status research) STATUS_VALIDATED) 
                     (is-eq (get status research) STATUS_REJECTED)) ERR_INVALID_STATUS)
        
        (if voted-correctly
          (begin
            (try! (stx-transfer? (var-get expert-reward) (as-contract tx-sender) tx-sender))
            (try! (update-expert-reputation expert-id true))
            (ok true)
          )
          (begin
            (try! (update-expert-reputation expert-id false))
            (ok false)
          )
        )
      )
    )
  )
)

;; Admin functions

(define-public (set-min-expert-votes (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set min-expert-votes new-min)
    (ok true)
  )
)

(define-public (set-research-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set research-reward new-reward)
    (ok true)
  )
)

(define-public (set-expert-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set expert-reward new-reward)
    (ok true)
  )
)

(define-public (deactivate-expert (expert-principal principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? expert-by-principal expert-principal)
      expert-id
        (match (map-get? experts expert-id)
          expert-data
            (begin
              (map-set experts expert-id (merge expert-data {active: false}))
              (ok true)
            )
          ERR_NOT_FOUND
        )
      ERR_NOT_FOUND
    )
  )
)