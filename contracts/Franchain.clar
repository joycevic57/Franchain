(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_INVALID_LOCATION (err u104))
(define-constant ERR_LICENSE_EXPIRED (err u105))
(define-constant ERR_INACTIVE_FRANCHISE (err u106))

(define-data-var franchise-counter uint u0)
(define-data-var location-counter uint u0)
(define-data-var total-revenue uint u0)

(define-map franchises 
    uint 
    {
        owner: principal,
        name: (string-ascii 50),
        fee: uint,
        royalty-rate: uint,
        active: bool,
        created-at: uint
    }
)

(define-map locations
    uint
    {
        franchise-id: uint,
        operator: principal,
        address: (string-ascii 100),
        license-expiry: uint,
        active: bool,
        revenue: uint,
        created-at: uint
    }
)

(define-map franchise-operators
    {franchise-id: uint, operator: principal}
    {location-count: uint, total-revenue: uint}
)

(define-map operator-permissions
    {franchise-id: uint, operator: principal}
    bool
)

(define-public (create-franchise (name (string-ascii 50)) (fee uint) (royalty-rate uint))
    (let ((franchise-id (+ (var-get franchise-counter) u1)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= royalty-rate u10000) ERR_UNAUTHORIZED)
        (map-set franchises franchise-id {
            owner: tx-sender,
            name: name,
            fee: fee,
            royalty-rate: royalty-rate,
            active: true,
            created-at: stacks-block-height
        })
        (var-set franchise-counter franchise-id)
        (ok franchise-id)
    )
)

(define-public (purchase-license (franchise-id uint) (operator principal) (address (string-ascii 100)) (duration uint))
    (let (
        (franchise (unwrap! (map-get? franchises franchise-id) ERR_NOT_FOUND))
        (location-id (+ (var-get location-counter) u1))
        (license-expiry (+ stacks-block-height duration))
    )
        (asserts! (get active franchise) ERR_INACTIVE_FRANCHISE)
        (asserts! (>= (stx-get-balance tx-sender) (get fee franchise)) ERR_INSUFFICIENT_PAYMENT)
        
        (try! (stx-transfer? (get fee franchise) tx-sender (get owner franchise)))
        
        (map-set locations location-id {
            franchise-id: franchise-id,
            operator: operator,
            address: address,
            license-expiry: license-expiry,
            active: true,
            revenue: u0,
            created-at: stacks-block-height
        })
        
        (map-set operator-permissions {franchise-id: franchise-id, operator: operator} true)
        
        (let ((current-data (default-to {location-count: u0, total-revenue: u0} 
                            (map-get? franchise-operators {franchise-id: franchise-id, operator: operator}))))
            (map-set franchise-operators {franchise-id: franchise-id, operator: operator} {
                location-count: (+ (get location-count current-data) u1),
                total-revenue: (get total-revenue current-data)
            })
        )
        
        (var-set location-counter location-id)
        (ok location-id)
    )
)

(define-public (record-revenue (location-id uint) (amount uint))
    (let (
        (location (unwrap! (map-get? locations location-id) ERR_NOT_FOUND))
        (franchise (unwrap! (map-get? franchises (get franchise-id location)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (asserts! (get active location) ERR_INVALID_LOCATION)
        (asserts! (> (get license-expiry location) stacks-block-height) ERR_LICENSE_EXPIRED)
        
        (let ((royalty-amount (/ (* amount (get royalty-rate franchise)) u10000)))
            (try! (stx-transfer? royalty-amount tx-sender (get owner franchise)))
            
            (map-set locations location-id (merge location {revenue: (+ (get revenue location) amount)}))
            
            (let ((operator-data (unwrap! (map-get? franchise-operators 
                                         {franchise-id: (get franchise-id location), operator: tx-sender}) ERR_NOT_FOUND)))
                (map-set franchise-operators {franchise-id: (get franchise-id location), operator: tx-sender}
                    (merge operator-data {total-revenue: (+ (get total-revenue operator-data) amount)}))
            )
            
            (var-set total-revenue (+ (var-get total-revenue) amount))
            (ok royalty-amount)
        )
    )
)

(define-public (renew-license (location-id uint) (duration uint))
    (let (
        (location (unwrap! (map-get? locations location-id) ERR_NOT_FOUND))
        (franchise (unwrap! (map-get? franchises (get franchise-id location)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (asserts! (>= (stx-get-balance tx-sender) (get fee franchise)) ERR_INSUFFICIENT_PAYMENT)
        
        (try! (stx-transfer? (get fee franchise) tx-sender (get owner franchise)))
        
        (map-set locations location-id (merge location {
            license-expiry: (+ (get license-expiry location) duration)
        }))
        
        (ok true)
    )
)

(define-public (deactivate-location (location-id uint))
    (let ((location (unwrap! (map-get? locations location-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (map-set locations location-id (merge location {active: false}))
        (ok true)
    )
)

(define-public (update-franchise-status (franchise-id uint) (active bool))
    (let ((franchise (unwrap! (map-get? franchises franchise-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (map-set franchises franchise-id (merge franchise {active: active}))
        (ok true)
    )
)

(define-public (update-franchise-fee (franchise-id uint) (new-fee uint))
    (let ((franchise (unwrap! (map-get? franchises franchise-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (map-set franchises franchise-id (merge franchise {fee: new-fee}))
        (ok true)
    )
)

(define-public (transfer-franchise-ownership (franchise-id uint) (new-owner principal))
    (let ((franchise (unwrap! (map-get? franchises franchise-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (map-set franchises franchise-id (merge franchise {owner: new-owner}))
        (ok true)
    )
)

(define-read-only (get-franchise (franchise-id uint))
    (map-get? franchises franchise-id)
)

(define-read-only (get-location (location-id uint))
    (map-get? locations location-id)
)

(define-read-only (get-operator-data (franchise-id uint) (operator principal))
    (map-get? franchise-operators {franchise-id: franchise-id, operator: operator})
)

(define-read-only (is-license-valid (location-id uint))
    (match (map-get? locations location-id)
        location (and (get active location) (> (get license-expiry location) stacks-block-height))
        false
    )
)

(define-read-only (get-franchise-count)
    (var-get franchise-counter)
)

(define-read-only (get-location-count)
    (var-get location-counter)
)

(define-read-only (get-total-revenue)
    (var-get total-revenue)
)

(define-read-only (has-operator-permission (franchise-id uint) (operator principal))
    (default-to false (map-get? operator-permissions {franchise-id: franchise-id, operator: operator}))
)

(define-read-only (calculate-royalty (franchise-id uint) (amount uint))
    (match (map-get? franchises franchise-id)
        franchise (/ (* amount (get royalty-rate franchise)) u10000)
        u0
    )
)

(define-read-only (get-franchise-revenue (franchise-id uint))
    (fold calculate-franchise-total (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) {franchise-id: franchise-id, total: u0})
)

(define-private (calculate-franchise-total (location-index uint) (data {franchise-id: uint, total: uint}))
    (match (map-get? locations location-index)
        location (if (is-eq (get franchise-id location) (get franchise-id data))
                    {franchise-id: (get franchise-id data), total: (+ (get total data) (get revenue location))}
                    data)
        data
    )
)
