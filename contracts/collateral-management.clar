;; collateral-management contract

(define-map collaterals
  { loan-id: uint }
  {
    asset: (string-ascii 64),
    amount: uint,
    liquidation-ratio: uint,
    liquidated: bool
  }
)

(define-constant ERR-UNAUTHORIZED u101)
(define-constant ERR-COLLATERAL-EXISTS u102)
(define-constant ERR-INVALID-LOAN u103)
(define-constant ERR-INSUFFICIENT-COLLATERAL u104)

(define-public (add-collateral (loan-id uint) (asset (string-ascii 64)) (amount uint) (liquidation-ratio uint))
  (let
    (
      (loan (unwrap! (contract-call? .loan-management get-loan loan-id) (err ERR-INVALID-LOAN)))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) (err ERR-UNAUTHORIZED))
    (asserts! (is-none (map-get? collaterals { loan-id: loan-id })) (err ERR-COLLATERAL-EXISTS))
    (try! (transfer-asset asset amount tx-sender (as-contract tx-sender)))
    (ok (map-set collaterals
      { loan-id: loan-id }
      {
        asset: asset,
        amount: amount,
        liquidation-ratio: liquidation-ratio,
        liquidated: false
      }
    ))
  )
)

(define-public (liquidate-collateral (loan-id uint))
  (let
    (
      (loan (unwrap! (contract-call? .loan-management get-loan loan-id) (err ERR-INVALID-LOAN)))
      (collateral (unwrap! (map-get? collaterals { loan-id: loan-id }) (err ERR-INVALID-LOAN)))
    )
    (asserts! (is-eq (some tx-sender) (get lender loan)) (err ERR-UNAUTHORIZED))
    (asserts! (not (get liquidated collateral)) (err ERR-INVALID-LOAN))
    (asserts! (< (* (get amount loan) u100) (* (get amount collateral) (get liquidation-ratio collateral))) (err ERR-INSUFFICIENT-COLLATERAL))
    (try! (transfer-asset (get asset collateral) (get amount collateral) (as-contract tx-sender) tx-sender))
    (ok (map-set collaterals
      { loan-id: loan-id }
      (merge collateral { liquidated: true })
    ))
  )
)

(define-read-only (get-collateral (loan-id uint))
  (map-get? collaterals { loan-id: loan-id })
)

(define-private (transfer-asset (asset (string-ascii 64)) (amount uint) (sender principal) (recipient principal))
  (if (is-eq asset "STX")
    (stx-transfer? amount sender recipient)
    (err u404) ;; Asset not supported
  )
)

