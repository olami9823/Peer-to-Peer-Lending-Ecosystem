;; c

(define-map credit-scores
  { user: principal }
  { score: uint }
)

(define-map credit-data-providers
  { provider: principal }
  { approved: bool }
)

(define-data-var admin principal tx-sender)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (var-set admin new-admin))
  )
)

(define-public (approve-data-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set credit-data-providers { provider: provider } { approved: true }))
  )
)

(define-public (revoke-data-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set credit-data-providers { provider: provider } { approved: false }))
  )
)

(define-public (update-credit-score (user principal) (new-score uint))
  (let
    (
      (provider-status (default-to { approved: false } (map-get? credit-data-providers { provider: tx-sender })))
    )
    (asserts! (get approved provider-status) (err u403))
    (ok (map-set credit-scores { user: user } { score: new-score }))
  )
)

(define-read-only (get-credit-score (user principal))
  (default-to { score: u0 } (map-get? credit-scores { user: user }))
)

