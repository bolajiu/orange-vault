;; Title: OrangeVault Protocol
;; Summary: Decentralized Bitcoin-backed liquidity vaults with automated yield generation on Stacks
;; Description: OrangeVault is a non-custodial DeFi protocol that enables Bitcoin holders to lock STX
;; as collateral in time-locked vaults and earn sustainable yields through protocol-managed liquidity strategies.
;; Users maintain full ownership while earning passive income, with transparent fee structures and flexible
;; lock periods. Built on Stacks Layer 2, OrangeVault bridges Bitcoin's security with DeFi innovation,
;; offering institutional-grade vault management for the next generation of Bitcoin finance.

;; CONSTANTS - Error Codes & Protocol Parameters

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-vault-locked (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-vault-exists (err u105))
(define-constant err-withdrawal-too-early (err u106))

;; Minimum lock period in blocks (~24 hours = 144 blocks)
(define-constant min-lock-period u144)

;; DATA VARIABLES - Protocol State Management

(define-data-var total-value-locked uint u0)
(define-data-var vault-counter uint u0)
(define-data-var protocol-fee-percentage uint u200) ;; 2% = 200 basis points
(define-data-var base-apy uint u800) ;; 8% = 800 basis points

;; DATA MAPS - Storage Structures

(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    amount: uint,
    deposit-block: uint,
    lock-until-block: uint,
    last-claim-block: uint,
    is-active: bool
  }
)

(define-map user-vault-ids
  { user: principal }
  { vault-ids: (list 100 uint) }
)

(define-map accumulated-rewards
  { vault-id: uint }
  { rewards: uint }
)

;; READ-ONLY FUNCTIONS - Query Protocol State

(define-read-only (get-vault (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-user-vaults (user principal))
  (default-to 
    { vault-ids: (list) }
    (map-get? user-vault-ids { user: user })
  )
)

(define-read-only (get-total-value-locked)
  (ok (var-get total-value-locked))
)

(define-read-only (get-protocol-stats)
  (ok {
    total-tvl: (var-get total-value-locked),
    total-vaults: (var-get vault-counter),
    base-apy: (var-get base-apy),
    protocol-fee: (var-get protocol-fee-percentage)
  })
)

(define-read-only (calculate-rewards (vault-id uint))
  (match (get-vault vault-id)
    vault
    (let
      (
        (blocks-elapsed (- stacks-block-height (get last-claim-block vault)))
        (amount (get amount vault))
        ;; APY calculation: (amount * apy * blocks) / (10000 * blocks-per-year)
        ;; Assuming ~52,560 blocks per year (10 min blocks)
        (rewards (/ (* (* amount (var-get base-apy)) blocks-elapsed) u525600000))
      )
      (ok rewards)
    )
    (err err-not-found)
  )
)

;; PUBLIC FUNCTIONS - Core Protocol Operations

(define-public (create-vault (amount uint) (lock-blocks uint))
  (let
    (
      (vault-id (+ (var-get vault-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= lock-blocks min-lock-period) err-vault-locked)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Create vault
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        amount: amount,
        deposit-block: current-block,
        lock-until-block: (+ current-block lock-blocks),
        last-claim-block: current-block,
        is-active: true
      }
    )
    
    ;; Initialize rewards
    (map-set accumulated-rewards
      { vault-id: vault-id }
      { rewards: u0 }
    )
    
    ;; Update user vault list
    (let
      (
        (current-vaults (get vault-ids (get-user-vaults tx-sender)))
        (updated-vaults (unwrap! (as-max-len? (append current-vaults vault-id) u100) err-vault-exists))
      )
      (map-set user-vault-ids
        { user: tx-sender }
        { vault-ids: updated-vaults }
      )
    )
    
    ;; Update TVL
    (var-set total-value-locked (+ (var-get total-value-locked) amount))
    (var-set vault-counter vault-id)
    
    (ok vault-id)
  )
)

(define-public (claim-rewards (vault-id uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) err-not-found))
      (rewards (unwrap! (calculate-rewards vault-id) err-not-found))
      (fee (/ (* rewards (var-get protocol-fee-percentage)) u10000))
      (net-rewards (- rewards fee))
    )
    (asserts! (is-eq (get owner vault) tx-sender) err-owner-only)
    (asserts! (get is-active vault) err-vault-locked)
    (asserts! (> rewards u0) err-insufficient-balance)
    
    ;; Transfer rewards to user
    (try! (as-contract (stx-transfer? net-rewards tx-sender (get owner vault))))
    
    ;; Update last claim block
    (map-set vaults
      { vault-id: vault-id }
      (merge vault { last-claim-block: stacks-block-height })
    )
    
    ;; Update accumulated rewards
    (let
      (
        (current-accumulated (default-to { rewards: u0 } (map-get? accumulated-rewards { vault-id: vault-id })))
        (total-accumulated (+ (get rewards current-accumulated) rewards))
      )
      (map-set accumulated-rewards
        { vault-id: vault-id }
        { rewards: total-accumulated }
      )
    )
    
    (ok net-rewards)
  )
)

(define-public (withdraw-vault (vault-id uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) err-not-found))
      (amount (get amount vault))
    )
    (asserts! (is-eq (get owner vault) tx-sender) err-owner-only)
    (asserts! (get is-active vault) err-vault-locked)
    (asserts! (>= stacks-block-height (get lock-until-block vault)) err-withdrawal-too-early)
    
    ;; Claim any pending rewards first
    (try! (claim-rewards vault-id))
    
    ;; Transfer principal back to user
    (try! (as-contract (stx-transfer? amount tx-sender (get owner vault))))
    
    ;; Deactivate vault
    (map-set vaults
      { vault-id: vault-id }
      (merge vault { is-active: false })
    )
    
    ;; Update TVL
    (var-set total-value-locked (- (var-get total-value-locked) amount))
    
    (ok amount)
  )
)

(define-public (extend-lock (vault-id uint) (additional-blocks uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) err-not-found))
    )
    (asserts! (is-eq (get owner vault) tx-sender) err-owner-only)
    (asserts! (get is-active vault) err-vault-locked)
    (asserts! (> additional-blocks u0) err-invalid-amount)
    
    ;; Update lock period
    (map-set vaults
      { vault-id: vault-id }
      (merge vault { 
        lock-until-block: (+ (get lock-until-block vault) additional-blocks)
      })
    )
    
    (ok true)
  )
)

;; ADMIN FUNCTIONS - Protocol Governance

(define-public (set-base-apy (new-apy uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set base-apy new-apy)
    (ok true)
  )
)

(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10% fee
    (var-set protocol-fee-percentage new-fee)
    (ok true)
  )
)