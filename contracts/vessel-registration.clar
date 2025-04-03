;; Vessel Registration Contract
;; Records details of commercial fishing boats

(define-data-var admin principal tx-sender)

;; Vessel data structure
(define-map vessels
  { vessel-id: (string-ascii 20) }
  {
    owner: principal,
    name: (string-ascii 50),
    length: uint,
    capacity: uint,
    registration-date: uint,
    is-active: bool
  }
)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new vessel
(define-public (register-vessel
    (vessel-id (string-ascii 20))
    (name (string-ascii 50))
    (length uint)
    (capacity uint))
  (let
    ((registration-date (get-block-info? time (- block-height u1))))
    (if (map-insert vessels
          { vessel-id: vessel-id }
          {
            owner: tx-sender,
            name: name,
            length: length,
            capacity: capacity,
            registration-date: (default-to u0 registration-date),
            is-active: true
          })
        (ok true)
        (err u1) ;; Vessel ID already exists
    )
  )
)

;; Update vessel information (only owner can update)
(define-public (update-vessel
    (vessel-id (string-ascii 20))
    (name (string-ascii 50))
    (length uint)
    (capacity uint))
  (let ((vessel-data (unwrap! (map-get? vessels { vessel-id: vessel-id }) (err u2))))
    (if (is-eq tx-sender (get owner vessel-data))
      (begin
        (map-set vessels
          { vessel-id: vessel-id }
          (merge vessel-data {
            name: name,
            length: length,
            capacity: capacity
          })
        )
        (ok true)
      )
      (err u3) ;; Not the vessel owner
    )
  )
)

;; Deactivate a vessel (can be done by owner or admin)
(define-public (deactivate-vessel (vessel-id (string-ascii 20)))
  (let ((vessel-data (unwrap! (map-get? vessels { vessel-id: vessel-id }) (err u2))))
    (if (or (is-eq tx-sender (get owner vessel-data)) (is-admin))
      (begin
        (map-set vessels
          { vessel-id: vessel-id }
          (merge vessel-data { is-active: false })
        )
        (ok true)
      )
      (err u3) ;; Not authorized
    )
  )
)

;; Reactivate a vessel (can be done by owner or admin)
(define-public (reactivate-vessel (vessel-id (string-ascii 20)))
  (let ((vessel-data (unwrap! (map-get? vessels { vessel-id: vessel-id }) (err u2))))
    (if (or (is-eq tx-sender (get owner vessel-data)) (is-admin))
      (begin
        (map-set vessels
          { vessel-id: vessel-id }
          (merge vessel-data { is-active: true })
        )
        (ok true)
      )
      (err u3) ;; Not authorized
    )
  )
)

;; Read-only function to get vessel information
(define-read-only (get-vessel (vessel-id (string-ascii 20)))
  (map-get? vessels { vessel-id: vessel-id })
)

;; Transfer vessel ownership
(define-public (transfer-ownership
    (vessel-id (string-ascii 20))
    (new-owner principal))
  (let ((vessel-data (unwrap! (map-get? vessels { vessel-id: vessel-id }) (err u2))))
    (if (is-eq tx-sender (get owner vessel-data))
      (begin
        (map-set vessels
          { vessel-id: vessel-id }
          (merge vessel-data { owner: new-owner })
        )
        (ok true)
      )
      (err u3) ;; Not the vessel owner
    )
  )
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
