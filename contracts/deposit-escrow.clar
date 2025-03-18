;; Deposit Escrow Contract
;; Holds security deposits during tenancy

(define-data-var admin principal tx-sender)

;; Map of rental agreements
(define-map rental-agreements
{ agreement-id: (string-ascii 32) }
{
  tenant: principal,
  landlord: principal,
  property-id: (string-ascii 32),
  deposit-amount: uint,
  rent-amount: uint,
  start-date: uint,
  end-date: uint,
  status: (string-ascii 16),
  creation-time: uint
}
)

;; Map of deposits
(define-map deposits
{ agreement-id: (string-ascii 32) }
{
  amount: uint,
  paid-at: uint,
  held-until: uint,
  status: (string-ascii 16),
  release-approval: {
    tenant-approved: bool,
    landlord-approved: bool,
    approval-time: uint
  }
}
)

;; Map of deposit transactions
(define-map deposit-transactions
{
  agreement-id: (string-ascii 32),
  transaction-id: uint
}
{
  transaction-type: (string-ascii 16),
  amount: uint,
  from: principal,
  to: principal,
  time: uint,
  notes: (string-ascii 256)
}
)

;; Counter for deposit transactions
(define-data-var transaction-counter uint u0)

;; Create a new rental agreement
(define-public (create-agreement
  (agreement-id (string-ascii 32))
  (tenant principal)
  (landlord principal)
  (property-id (string-ascii 32))
  (deposit-amount uint)
  (rent-amount uint)
  (start-date uint)
  (end-date uint))
(let ((current-time (default-to u0 (get-block-info? time u0))))
  (asserts! (not (is-some (map-get? rental-agreements { agreement-id: agreement-id }))) (err u403))
  (asserts! (or (is-eq tx-sender tenant) (is-eq tx-sender landlord) (is-eq tx-sender (var-get admin))) (err u403))

  (map-insert rental-agreements
    { agreement-id: agreement-id }
    {
      tenant: tenant,
      landlord: landlord,
      property-id: property-id,
      deposit-amount: deposit-amount,
      rent-amount: rent-amount,
      start-date: start-date,
      end-date: end-date,
      status: "created",
      creation-time: current-time
    }
  )

  (ok true)
)
)

;; Pay deposit
(define-public (pay-deposit (agreement-id (string-ascii 32)))
(let ((agreement (unwrap! (map-get? rental-agreements { agreement-id: agreement-id }) (err u404)))
      (current-time (default-to u0 (get-block-info? time u0))))
  (asserts! (is-eq tx-sender (get tenant agreement)) (err u403))
  (asserts! (is-eq (get status agreement) "created") (err u400))

  ;; In a real implementation, this would transfer STX from the tenant to the contract
  ;; For simplicity, we'll just record that the deposit was paid

  ;; Record the deposit
  (map-insert deposits
    { agreement-id: agreement-id }
    {
      amount: (get deposit-amount agreement),
      paid-at: current-time,
      held-until: (get end-date agreement),
      status: "held",
      release-approval: {
        tenant-approved: false,
        landlord-approved: false,
        approval-time: u0
      }
    }
  )

  ;; Record the transaction
  (let ((transaction-id (var-get transaction-counter)))
    (var-set transaction-counter (+ transaction-id u1))

    (map-insert deposit-transactions
      {
        agreement-id: agreement-id,
        transaction-id: transaction-id
      }
      {
        transaction-type: "deposit-paid",
        amount: (get deposit-amount agreement),
        from: (get tenant agreement),
        to: (var-get admin), ;; Contract holds the deposit
        time: current-time,
        notes: "Security deposit paid"
      }
    )
  )

  ;; Update agreement status
  (map-set rental-agreements
    { agreement-id: agreement-id }
    (merge agreement { status: "active" })
  )

  (ok true)
)
)

;; Approve deposit release
(define-public (approve-release (agreement-id (string-ascii 32)))
(let ((agreement (unwrap! (map-get? rental-agreements { agreement-id: agreement-id }) (err u404)))
      (deposit (unwrap! (map-get? deposits { agreement-id: agreement-id }) (err u404)))
      (current-time (default-to u0 (get-block-info? time u0))))

  ;; Check if caller is tenant or landlord
  (asserts! (or (is-eq tx-sender (get tenant agreement)) (is-eq tx-sender (get landlord agreement))) (err u403))

  ;; Update approval based on who called
  (if (is-eq tx-sender (get tenant agreement))
    (map-set deposits
      { agreement-id: agreement-id }
      (merge deposit {
        release-approval: (merge (get release-approval deposit) {
          tenant-approved: true,
          approval-time: current-time
        })
      })
    )
    (map-set deposits
      { agreement-id: agreement-id }
      (merge deposit {
        release-approval: (merge (get release-approval deposit) {
          landlord-approved: true,
          approval-time: current-time
        })
      })
    )
  )

  ;; Check if both parties have approved
  (let ((updated-deposit (unwrap! (map-get? deposits { agreement-id: agreement-id }) (err u500))))
    (if (and
          (get tenant-approved (get release-approval updated-deposit))
          (get landlord-approved (get release-approval updated-deposit))
        )
      (release-deposit agreement-id)
      (ok false)
    )
  )
)
)

;; Release deposit (private function)
(define-private (release-deposit (agreement-id (string-ascii 32)))
(let ((agreement (unwrap! (map-get? rental-agreements { agreement-id: agreement-id }) (err u404)))
      (deposit (unwrap! (map-get? deposits { agreement-id: agreement-id }) (err u404)))
      (current-time (default-to u0 (get-block-info? time u0))))

  ;; In a real implementation, this would transfer STX from the contract to the tenant
  ;; For simplicity, we'll just record that the deposit was released

  ;; Update deposit status
  (map-set deposits
    { agreement-id: agreement-id }
    (merge deposit { status: "released" })
  )

  ;; Record the transaction
  (let ((transaction-id (var-get transaction-counter)))
    (var-set transaction-counter (+ transaction-id u1))

    (map-insert deposit-transactions
      {
        agreement-id: agreement-id,
        transaction-id: transaction-id
      }
      {
        transaction-type: "deposit-released",
        amount: (get amount deposit),
        from: (var-get admin), ;; Contract releases the deposit
        to: (get tenant agreement),
        time: current-time,
        notes: "Security deposit released"
      }
    )
  )

  ;; Update agreement status
  (map-set rental-agreements
    { agreement-id: agreement-id }
    (merge agreement { status: "completed" })
  )

  (ok true)
)
)

;; Claim deposit (landlord claims for damages)
(define-public (claim-deposit
  (agreement-id (string-ascii 32))
  (claim-amount uint)
  (reason (string-ascii 256)))
(let ((agreement (unwrap! (map-get? rental-agreements { agreement-id: agreement-id }) (err u404)))
      (deposit (unwrap! (map-get? deposits { agreement-id: agreement-id }) (err u404))))

  (asserts! (is-eq tx-sender (get landlord agreement)) (err u403))
  (asserts! (is-eq (get status deposit) "held") (err u400))
  (asserts! (<= claim-amount (get amount deposit)) (err u400))

  ;; Update deposit status to disputed
  (map-set deposits
    { agreement-id: agreement-id }
    (merge deposit { status: "disputed" })
  )

  (ok true)
)
)

;; Get rental agreement
(define-read-only (get-agreement (agreement-id (string-ascii 32)))
(map-get? rental-agreements { agreement-id: agreement-id })
)

;; Get deposit
(define-read-only (get-deposit (agreement-id (string-ascii 32)))
(map-get? deposits { agreement-id: agreement-id })
)

;; Get deposit transaction
(define-read-only (get-transaction (agreement-id (string-ascii 32)) (transaction-id uint))
(map-get? deposit-transactions { agreement-id: agreement-id, transaction-id: transaction-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
(begin
  (asserts! (is-eq tx-sender (var-get admin)) (err u403))
  (var-set admin new-admin)
  (ok true)
)
)
