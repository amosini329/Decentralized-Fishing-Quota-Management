;; Quota Allocation Contract
;; Manages sustainable catch limits by species

(define-data-var admin principal tx-sender)

;; Species data structure
(define-map species
  { species-id: (string-ascii 20) }
  {
    name: (string-ascii 50),
    total-quota: uint,
    allocated-quota: uint,
    season-start: uint,
    season-end: uint
  }
)

;; Vessel quota allocation
(define-map vessel-quotas
  {
    vessel-id: (string-ascii 20),
    species-id: (string-ascii 20)
  }
  {
    allocated-amount: uint,
    remaining-amount: uint,
    allocation-date: uint
  }
)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Add or update a species
(define-public (set-species
    (species-id (string-ascii 20))
    (name (string-ascii 50))
    (total-quota uint)
    (season-start uint)
    (season-end uint))
  (if (is-admin)
    (begin
      (map-set species
        { species-id: species-id }
        {
          name: name,
          total-quota: total-quota,
          allocated-quota: u0,
          season-start: season-start,
          season-end: season-end
        }
      )
      (ok true)
    )
    (err u1) ;; Not authorized
  )
)

;; Update total quota for a species
(define-public (update-total-quota
    (species-id (string-ascii 20))
    (new-total-quota uint))
  (let ((species-data (unwrap! (map-get? species { species-id: species-id }) (err u2))))
    (if (is-admin)
      (begin
        (map-set species
          { species-id: species-id }
          (merge species-data { total-quota: new-total-quota })
        )
        (ok true)
      )
      (err u1) ;; Not authorized
    )
  )
)

;; Allocate quota to a vessel
(define-public (allocate-quota
    (vessel-id (string-ascii 20))
    (species-id (string-ascii 20))
    (amount uint))
  (let (
      (species-data (unwrap! (map-get? species { species-id: species-id }) (err u2)))
      (current-allocated (get allocated-quota species-data))
      (total-quota (get total-quota species-data))
      (allocation-date (get-block-info? time (- block-height u1)))
    )
    (if (is-admin)
      (if (<= (+ current-allocated amount) total-quota)
        (begin
          ;; Update species allocated quota
          (map-set species
            { species-id: species-id }
            (merge species-data { allocated-quota: (+ current-allocated amount) })
          )
          ;; Set vessel quota
          (map-set vessel-quotas
            {
              vessel-id: vessel-id,
              species-id: species-id
            }
            {
              allocated-amount: amount,
              remaining-amount: amount,
              allocation-date: (default-to u0 allocation-date)
            }
          )
          (ok true)
        )
        (err u3) ;; Exceeds total quota
      )
      (err u1) ;; Not authorized
    )
  )
)

;; Read-only function to get species information
(define-read-only (get-species-info (species-id (string-ascii 20)))
  (map-get? species { species-id: species-id })
)

;; Read-only function to get vessel quota
(define-read-only (get-vessel-quota (vessel-id (string-ascii 20)) (species-id (string-ascii 20)))
  (map-get? vessel-quotas { vessel-id: vessel-id, species-id: species-id })
)

;; Set a new admin (only current admin can do this)
(define-public (set-admin (new-admin principal))
  (if (is-admin)
    (begin
      (var-set admin new-admin)
      (ok true)
    )
    (err u4) ;; Not the admin
  )
)

;; Internal function to update remaining quota (called by catch reporting contract)
(define-public (update-remaining-quota
    (vessel-id (string-ascii 20))
    (species-id (string-ascii 20))
    (catch-amount uint))
  (let (
      (quota-data (unwrap! (map-get? vessel-quotas { vessel-id: vessel-id, species-id: species-id }) (err u2)))
      (remaining (get remaining-amount quota-data))
    )
    (if (<= catch-amount remaining)
      (begin
        (map-set vessel-quotas
          { vessel-id: vessel-id, species-id: species-id }
          (merge quota-data { remaining-amount: (- remaining catch-amount) })
        )
        (ok true)
      )
      (err u5) ;; Exceeds remaining quota
    )
  )
)
