;; Property Condition Contract
;; Records state of property at move-in and move-out

(define-data-var admin principal tx-sender)

;; Map of property records
(define-map property-records
{ property-id: (string-ascii 32) }
{
  owner: principal,
  address: (string-ascii 256),
  property-type: (string-ascii 32),
  bedrooms: uint,
  bathrooms: uint,
  registration-date: uint,
  status: (string-ascii 16)
}
)

;; Map of condition reports
(define-map condition-reports
{
  agreement-id: (string-ascii 32),
  report-type: (string-ascii 16) ;; "move-in" or "move-out"
}
{
  inspector: principal,
  inspection-date: uint,
  overall-condition: (string-ascii 16),
  document-hash: (buff 32),
  tenant-signature: {
    signed: bool,
    signed-at: uint
  },
  landlord-signature: {
    signed: bool,
    signed-at: uint
  },
  status: (string-ascii 16)
}
)

;; Map of room conditions
(define-map room-conditions
{
  agreement-id: (string-ascii 32),
  report-type: (string-ascii 16),
  room-id: (string-ascii 32)
}
{
  room-type: (string-ascii 32),
  condition: (string-ascii 16),
  damage-description: (string-ascii 256),
  image-hashes: (list 10 (buff 32)),
  notes: (string-ascii 256)
}
)

;; Map of damage claims
(define-map damage-claims
{
  agreement-id: (string-ascii 32),
  claim-id: (string-ascii 32)
}
{
  room-id: (string-ascii 32),
  damage-description: (string-ascii 256),
  repair-cost: uint,
  image-hashes: (list 5 (buff 32)),
  claimed-by: principal,
  claim-date: uint,
  status: (string-ascii 16)
}
)

;; Register a property
(define-public (register-property
  (property-id (string-ascii 32))
  (address (string-ascii 256))
  (property-type (string-ascii 32))
  (bedrooms uint)
  (bathrooms uint))
(let ((current-time (default-to u0 (get-block-info? time u0))))
  (asserts! (not (is-some (map-get? property-records { property-id: property-id }))) (err u403))

  (map-insert property-records
    { property-id: property-id }
    {
      owner: tx-sender,
      address: address,
      property-type: property-type,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      registration-date: current-time,
      status: "active"
    }
  )

  (ok true)
)
)

;; Create a condition report
(define-public (create-condition-report
  (agreement-id (string-ascii 32))
  (report-type (string-ascii 16))
  (overall-condition (string-ascii 16))
  (document-hash (buff 32)))
(let ((current-time (default-to u0 (get-block-info? time u0))))

  (asserts! (or (is-eq report-type "move-in") (is-eq report-type "move-out")) (err u400))

  (map-insert condition-reports
    {
      agreement-id: agreement-id,
      report-type: report-type
    }
    {
      inspector: tx-sender,
      inspection-date: current-time,
      overall-condition: overall-condition,
      document-hash: document-hash,
      tenant-signature: {
        signed: false,
        signed-at: u0
      },
      landlord-signature: {
        signed: false,
        signed-at: u0
      },
      status: "pending"
    }
  )

  (ok true)
)
)

;; Add room condition to report
(define-public (add-room-condition
  (agreement-id (string-ascii 32))
  (report-type (string-ascii 16))
  (room-id (string-ascii 32))
  (room-type (string-ascii 32))
  (condition (string-ascii 16))
  (damage-description (string-ascii 256))
  (image-hashes (list 10 (buff 32)))
  (notes (string-ascii 256)))
(let ((report (unwrap! (map-get? condition-reports { agreement-id: agreement-id, report-type: report-type }) (err u404))))

  (asserts! (is-eq tx-sender (get inspector report)) (err u403))
  (asserts! (is-eq (get status report) "pending") (err u400))

  (map-insert room-conditions
    {
      agreement-id: agreement-id,
      report-type: report-type,
      room-id: room-id
    }
    {
      room-type: room-type,
      condition: condition,
      damage-description: damage-description,
      image-hashes: image-hashes,
      notes: notes
    }
  )

  (ok true)
)
)

;; Sign condition report
(define-public (sign-condition-report
  (agreement-id (string-ascii 32))
  (report-type (string-ascii 16))
  (is-tenant bool))
(let ((report (unwrap! (map-get? condition-reports { agreement-id: agreement-id, report-type: report-type }) (err u404)))
      (current-time (default-to u0 (get-block-info? time u0))))

  ;; Update signature based on who called
  (if is-tenant
    (map-set condition-reports
      { agreement-id: agreement-id, report-type: report-type }
      (merge report {
        tenant-signature: {
          signed: true,
          signed-at: current-time
        }
      })
    )
    (map-set condition-reports
      { agreement-id: agreement-id, report-type: report-type }
      (merge report {
        landlord-signature: {
          signed: true,
          signed-at: current-time
        }
      })
    )
  )

  ;; Check if both parties have signed
  (let ((updated-report (unwrap! (map-get? condition-reports { agreement-id: agreement-id, report-type: report-type }) (err u500))))
    (if (and
          (get signed (get tenant-signature updated-report))
          (get signed (get landlord-signature updated-report))
        )
      (map-set condition-reports
        { agreement-id: agreement-id, report-type: report-type }
        (merge updated-report { status: "completed" })
      )
      true
    )
  )

  (ok true)
)
)

;; File a damage claim
(define-public (file-damage-claim
  (agreement-id (string-ascii 32))
  (claim-id (string-ascii 32))
  (room-id (string-ascii 32))
  (damage-description (string-ascii 256))
  (repair-cost uint)
  (image-hashes (list 5 (buff 32))))
(let ((current-time (default-to u0 (get-block-info? time u0))))

  (map-insert damage-claims
    {
      agreement-id: agreement-id,
      claim-id: claim-id
    }
    {
      room-id: room-id,
      damage-description: damage-description,
      repair-cost: repair-cost,
      image-hashes: image-hashes,
      claimed-by: tx-sender,
      claim-date: current-time,
      status: "filed"
    }
  )

  (ok true)
)
)

;; Get property record
(define-read-only (get-property (property-id (string-ascii 32)))
(map-get? property-records { property-id: property-id })
)

;; Get condition report
(define-read-only (get-condition-report (agreement-id (string-ascii 32)) (report-type (string-ascii 16)))
(map-get? condition-reports { agreement-id: agreement-id, report-type: report-type })
)

;; Get room condition
(define-read-only (get-room-condition (agreement-id (string-ascii 32)) (report-type (string-ascii 16)) (room-id (string-ascii 32)))
(map-get? room-conditions { agreement-id: agreement-id, report-type: report-type, room-id: room-id })
)

;; Get damage claim
(define-read-only (get-damage-claim (agreement-id (string-ascii 32)) (claim-id (string-ascii 32)))
(map-get? damage-claims { agreement-id: agreement-id, claim-id: claim-id })
)

;; Compare move-in and move-out conditions
(define-read-only (compare-conditions (agreement-id (string-ascii 32)) (room-id (string-ascii 32)))
(let ((move-in (map-get? room-conditions { agreement-id: agreement-id, report-type: "move-in", room-id: room-id }))
      (move-out (map-get? room-conditions { agreement-id: agreement-id, report-type: "move-out", room-id: room-id })))

  (if (and (is-some move-in) (is-some move-out))
    (ok {
      move-in-condition: (get condition (unwrap-panic move-in)),
      move-out-condition: (get condition (unwrap-panic move-out)),
      has-damage: (not (is-eq
        (get condition (unwrap-panic move-in))
        (get condition (unwrap-panic move-out))
      ))
    })
    (err u404)
  )
)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
(begin
  (asserts! (is-eq tx-sender (var-get admin)) (err u403))
  (var-set admin new-admin)
  (ok true)
)
)
