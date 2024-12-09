;; loan-management contract

(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: (optional principal),
    amount: uint,
    interest-rate: uint,
    term: uint,
    start-block: (optional uint),
    status: (string-ascii 20)
  }
)

(define-map user-loans
  { user: principal }
  { active-loans: (list 10 uint) }
)

(define-data-var next-loan-id uint u0)

(define-constant ERR-INVALID-LOAN u100)
(define-constant ERR-UNAUTHORIZED u101)
(define-constant ERR-ALREADY-FUNDED u102)
(define-constant ERR-INSUFFICIENT-FUNDS u103)
(define-constant ERR-LOAN-NOT-ACTIVE u104)

(define-public (request-loan (amount uint) (interest-rate uint) (term uint))
  (let
    (
      (loan-id (var-get next-loan-id))
      (borrower-loans (default-to { active-loans: (list) } (map-get? user-loans { user: tx-sender })))
    )
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: tx-sender,
        lender: none,
        amount: amount,
        interest-rate: interest-rate,
        term: term,
        start-block: none,
        status: "requested"
      }
    )
    (map-set user-loans
      { user: tx-sender }
      { active-loans: (unwrap! (as-max-len? (append (get active-loans borrower-loans) loan-id) u10) (err ERR-INVALID-LOAN)) }
    )
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) (err ERR-INVALID-LOAN)))
      (lender-loans (default-to { active-loans: (list) } (map-get? user-loans { user: tx-sender })))
    )
    (asserts! (is-eq (get status loan) "requested") (err ERR-ALREADY-FUNDED))
    (asserts! (>= (stx-get-balance tx-sender) (get amount loan)) (err ERR-INSUFFICIENT-FUNDS))
    (try! (stx-transfer? (get amount loan) tx-sender (get borrower loan)))
    (map-set loans
      { loan-id: loan-id }
      (merge loan {
        lender: (some tx-sender),
        start-block: (some block-height),
        status: "active"
      })
    )
    (map-set user-loans
      { user: tx-sender }
      { active-loans: (unwrap! (as-max-len? (append (get active-loans lender-loans) loan-id) u10) (err ERR-INVALID-LOAN)) }
    )
    (ok true)
  )
)

(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) (err ERR-INVALID-LOAN)))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) (err ERR-UNAUTHORIZED))
    (asserts! (is-eq (get status loan) "active") (err ERR-LOAN-NOT-ACTIVE))
    (let
      (
        (repayment-amount (calculate-repayment-amount (get amount loan) (get interest-rate loan) (get term loan)))
      )
      (asserts! (>= (stx-get-balance tx-sender) repayment-amount) (err ERR-INSUFFICIENT-FUNDS))
      (try! (stx-transfer? repayment-amount tx-sender (unwrap! (get lender loan) (err ERR-INVALID-LOAN))))
      (map-set loans
        { loan-id: loan-id }
        (merge loan { status: "repaid" })
      )
      (ok true)
    )
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-user-loans (user principal))
  (map-get? user-loans { user: user })
)

(define-private (calculate-repayment-amount (principal uint) (interest-rate uint) (term uint))
  (let
    (
      (interest-amount (/ (* principal interest-rate term) u10000))
    )
    (+ principal interest-amount)
  )
)

