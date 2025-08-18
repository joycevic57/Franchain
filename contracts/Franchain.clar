(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_INVALID_LOCATION (err u104))
(define-constant ERR_LICENSE_EXPIRED (err u105))
(define-constant ERR_INACTIVE_FRANCHISE (err u106))
(define-constant ERR_REVIEW_NOT_FOUND (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_REVIEW_ALREADY_EXISTS (err u109))
(define-constant ERR_INSUFFICIENT_REVIEWS (err u110))
(define-constant ERR_TERRITORY_NOT_FOUND (err u111))
(define-constant ERR_TERRITORY_CONFLICT (err u112))
(define-constant ERR_INVALID_COORDINATES (err u113))
(define-constant ERR_TERRITORY_ALREADY_ASSIGNED (err u114))
(define-constant ERR_TERRITORY_NOT_AVAILABLE (err u115))

(define-data-var franchise-counter uint u0)
(define-data-var location-counter uint u0)
(define-data-var total-revenue uint u0)
(define-data-var review-counter uint u0)
(define-data-var territory-counter uint u0)

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

(define-map reviews
    uint
    {
        location-id: uint,
        reviewer: principal,
        rating: uint,
        comment: (string-ascii 200),
        created-at: uint,
        verified: bool
    }
)

(define-map location-ratings
    uint
    {
        total-ratings: uint,
        sum-ratings: uint,
        average-rating: uint,
        review-count: uint
    }
)

(define-map reviewer-history
    {reviewer: principal, location-id: uint}
    bool
)

(define-map territories
    uint
    {
        franchise-id: uint,
        name: (string-ascii 100),
        north-lat: uint,
        south-lat: uint,
        east-lng: uint,
        west-lng: uint,
        population: uint,
        market-value: uint,
        assigned-operator: (optional principal),
        active: bool,
        created-at: uint
    }
)

(define-map territory-assignments
    {franchise-id: uint, operator: principal}
    {territory-ids: (list 10 uint), territory-count: uint}
)

(define-map territory-conflicts
    {territory-id: uint, conflicting-territory-id: uint}
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

(define-public (submit-review (location-id uint) (rating uint) (comment (string-ascii 200)))
    (let (
        (location (unwrap! (map-get? locations location-id) ERR_NOT_FOUND))
        (review-id (+ (var-get review-counter) u1))
        (reviewer-key {reviewer: tx-sender, location-id: location-id})
    )
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
        (asserts! (get active location) ERR_INVALID_LOCATION)
        (asserts! (is-none (map-get? reviewer-history reviewer-key)) ERR_REVIEW_ALREADY_EXISTS)
        
        (map-set reviews review-id {
            location-id: location-id,
            reviewer: tx-sender,
            rating: rating,
            comment: comment,
            created-at: stacks-block-height,
            verified: false
        })
        
        (map-set reviewer-history reviewer-key true)
        
        (let (
            (current-ratings (default-to {total-ratings: u0, sum-ratings: u0, average-rating: u0, review-count: u0}
                             (map-get? location-ratings location-id)))
            (new-total (+ (get total-ratings current-ratings) u1))
            (new-sum (+ (get sum-ratings current-ratings) rating))
            (new-average (/ new-sum new-total))
        )
            (map-set location-ratings location-id {
                total-ratings: new-total,
                sum-ratings: new-sum,
                average-rating: new-average,
                review-count: new-total
            })
        )
        
        (var-set review-counter review-id)
        (ok review-id)
    )
)

(define-public (verify-review (review-id uint))
    (let (
        (review (unwrap! (map-get? reviews review-id) ERR_REVIEW_NOT_FOUND))
        (location (unwrap! (map-get? locations (get location-id review)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (map-set reviews review-id (merge review {verified: true}))
        (ok true)
    )
)

(define-public (respond-to-review (review-id uint) (response (string-ascii 300)))
    (let (
        (review (unwrap! (map-get? reviews review-id) ERR_REVIEW_NOT_FOUND))
        (location (unwrap! (map-get? locations (get location-id review)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (ok true)
    )
)

(define-public (flag-review (review-id uint))
    (let (
        (review (unwrap! (map-get? reviews review-id) ERR_REVIEW_NOT_FOUND))
        (location (unwrap! (map-get? locations (get location-id review)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (map-set reviews review-id (merge review {verified: false}))
        (ok true)
    )
)

(define-public (update-location-rating (location-id uint))
    (let (
        (location (unwrap! (map-get? locations location-id) ERR_NOT_FOUND))
        (current-ratings (default-to {total-ratings: u0, sum-ratings: u0, average-rating: u0, review-count: u0}
                         (map-get? location-ratings location-id)))
    )
        (asserts! (is-eq tx-sender (get operator location)) ERR_UNAUTHORIZED)
        (asserts! (> (get total-ratings current-ratings) u0) ERR_INSUFFICIENT_REVIEWS)
        
        (let ((new-average (/ (get sum-ratings current-ratings) (get total-ratings current-ratings))))
            (map-set location-ratings location-id (merge current-ratings {average-rating: new-average}))
        )
        (ok true)
    )
)

(define-read-only (get-review (review-id uint))
    (map-get? reviews review-id)
)

(define-read-only (get-location-rating (location-id uint))
    (map-get? location-ratings location-id)
)

(define-read-only (has-reviewed (reviewer principal) (location-id uint))
    (default-to false (map-get? reviewer-history {reviewer: reviewer, location-id: location-id}))
)

(define-read-only (get-average-rating (location-id uint))
    (match (map-get? location-ratings location-id)
        rating-data (get average-rating rating-data)
        u0
    )
)

(define-read-only (get-review-count (location-id uint))
    (match (map-get? location-ratings location-id)
        rating-data (get review-count rating-data)
        u0
    )
)

(define-read-only (get-total-reviews)
    (var-get review-counter)
)

(define-read-only (is-review-verified (review-id uint))
    (match (map-get? reviews review-id)
        review (get verified review)
        false
    )
)

(define-read-only (calculate-franchise-rating (franchise-id uint))
    (fold calculate-franchise-rating-total (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
          {franchise-id: franchise-id, total-sum: u0, total-count: u0, average: u0})
)

(define-private (calculate-franchise-rating-total (location-index uint) 
                                                  (data {franchise-id: uint, total-sum: uint, total-count: uint, average: uint}))
    (match (map-get? locations location-index)
        location (if (is-eq (get franchise-id location) (get franchise-id data))
                    (match (map-get? location-ratings location-index)
                        rating-data 
                        (let (
                            (new-sum (+ (get total-sum data) (get sum-ratings rating-data)))
                            (new-count (+ (get total-count data) (get total-ratings rating-data)))
                        )
                            {
                                franchise-id: (get franchise-id data),
                                total-sum: new-sum,
                                total-count: new-count,
                                average: (if (> new-count u0) (/ new-sum new-count) u0)
                            }
                        )
                        data
                    )
                    data)
        data
    )
)

(define-public (create-territory (franchise-id uint) (name (string-ascii 100)) 
                                (north-lat uint) (south-lat uint) (east-lng uint) (west-lng uint)
                                (population uint) (market-value uint))
    (let (
        (franchise (unwrap! (map-get? franchises franchise-id) ERR_NOT_FOUND))
        (territory-id (+ (var-get territory-counter) u1))
    )
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (asserts! (get active franchise) ERR_INACTIVE_FRANCHISE)
        (asserts! (and (> north-lat south-lat) (> east-lng west-lng)) ERR_INVALID_COORDINATES)
        (asserts! (is-none (get overlap-found (check-territory-overlap franchise-id north-lat south-lat east-lng west-lng))) ERR_TERRITORY_CONFLICT)
        
        (map-set territories territory-id {
            franchise-id: franchise-id,
            name: name,
            north-lat: north-lat,
            south-lat: south-lat,
            east-lng: east-lng,
            west-lng: west-lng,
            population: population,
            market-value: market-value,
            assigned-operator: none,
            active: true,
            created-at: stacks-block-height
        })
        
        (var-set territory-counter territory-id)
        (ok territory-id)
    )
)

(define-public (assign-territory (territory-id uint) (operator principal))
    (let (
        (territory (unwrap! (map-get? territories territory-id) ERR_TERRITORY_NOT_FOUND))
        (franchise (unwrap! (map-get? franchises (get franchise-id territory)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (asserts! (get active territory) ERR_TERRITORY_NOT_AVAILABLE)
        (asserts! (is-none (get assigned-operator territory)) ERR_TERRITORY_ALREADY_ASSIGNED)
        
        (map-set territories territory-id (merge territory {assigned-operator: (some operator)}))
        
        (let (
            (assignment-key {franchise-id: (get franchise-id territory), operator: operator})
            (current-assignments (default-to {territory-ids: (list), territory-count: u0}
                                 (map-get? territory-assignments assignment-key)))
        )
            (map-set territory-assignments assignment-key {
                territory-ids: (unwrap! (as-max-len? 
                                        (append (get territory-ids current-assignments) territory-id) u10) ERR_TERRITORY_CONFLICT),
                territory-count: (+ (get territory-count current-assignments) u1)
            })
        )
        
        (ok true)
    )
)

(define-public (transfer-territory (territory-id uint) (new-operator principal))
    (let (
        (territory (unwrap! (map-get? territories territory-id) ERR_TERRITORY_NOT_FOUND))
        (franchise (unwrap! (map-get? franchises (get franchise-id territory)) ERR_NOT_FOUND))
        (current-operator (unwrap! (get assigned-operator territory) ERR_TERRITORY_NOT_AVAILABLE))
    )
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (asserts! (get active territory) ERR_TERRITORY_NOT_AVAILABLE)
        
        (map-set territories territory-id (merge territory {assigned-operator: (some new-operator)}))
        
        (let (
            (old-assignment-key {franchise-id: (get franchise-id territory), operator: current-operator})
            (new-assignment-key {franchise-id: (get franchise-id territory), operator: new-operator})
            (old-assignments (unwrap! (map-get? territory-assignments old-assignment-key) ERR_NOT_FOUND))
            (new-assignments (default-to {territory-ids: (list), territory-count: u0}
                             (map-get? territory-assignments new-assignment-key)))
        )
            (map-set territory-assignments old-assignment-key {
                territory-ids: (filter remove-territory-id (get territory-ids old-assignments)),
                territory-count: (- (get territory-count old-assignments) u1)
            })
            
            (map-set territory-assignments new-assignment-key {
                territory-ids: (unwrap! (as-max-len? 
                                        (append (get territory-ids new-assignments) territory-id) u10) ERR_TERRITORY_CONFLICT),
                territory-count: (+ (get territory-count new-assignments) u1)
            })
        )
        
        (ok true)
    )
)

(define-public (deactivate-territory (territory-id uint))
    (let (
        (territory (unwrap! (map-get? territories territory-id) ERR_TERRITORY_NOT_FOUND))
        (franchise (unwrap! (map-get? franchises (get franchise-id territory)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (map-set territories territory-id (merge territory {active: false, assigned-operator: none}))
        (ok true)
    )
)

(define-public (update-territory-data (territory-id uint) (population uint) (market-value uint))
    (let (
        (territory (unwrap! (map-get? territories territory-id) ERR_TERRITORY_NOT_FOUND))
        (franchise (unwrap! (map-get? franchises (get franchise-id territory)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get owner franchise)) ERR_UNAUTHORIZED)
        (map-set territories territory-id (merge territory {
            population: population,
            market-value: market-value
        }))
        (ok true)
    )
)

(define-read-only (get-territory (territory-id uint))
    (map-get? territories territory-id)
)

(define-read-only (get-territory-assignments (franchise-id uint) (operator principal))
    (map-get? territory-assignments {franchise-id: franchise-id, operator: operator})
)

(define-read-only (is-territory-available (territory-id uint))
    (match (map-get? territories territory-id)
        territory (and (get active territory) (is-none (get assigned-operator territory)))
        false
    )
)

(define-read-only (get-territory-count)
    (var-get territory-counter)
)

(define-read-only (calculate-franchise-territory-value (franchise-id uint))
    (fold calculate-territory-value-total (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
          {franchise-id: franchise-id, total-value: u0, total-population: u0})
)

(define-read-only (check-territory-overlap (franchise-id uint) (north-lat uint) (south-lat uint) (east-lng uint) (west-lng uint))
    (fold check-overlap-with-territory (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
          {franchise-id: franchise-id, north-lat: north-lat, south-lat: south-lat, 
           east-lng: east-lng, west-lng: west-lng, overlap-found: none})
)

(define-private (remove-territory-id (territory-id uint))
    false
)

(define-private (calculate-territory-value-total (territory-index uint) 
                                                (data {franchise-id: uint, total-value: uint, total-population: uint}))
    (match (map-get? territories territory-index)
        territory (if (is-eq (get franchise-id territory) (get franchise-id data))
                     {
                         franchise-id: (get franchise-id data),
                         total-value: (+ (get total-value data) (get market-value territory)),
                         total-population: (+ (get total-population data) (get population territory))
                     }
                     data)
        data
    )
)

(define-private (check-overlap-with-territory (territory-index uint)
                                             (params {franchise-id: uint, north-lat: uint, south-lat: uint,
                                                     east-lng: uint, west-lng: uint, overlap-found: (optional uint)}))
    (match (map-get? territories territory-index)
        territory (if (and (is-eq (get franchise-id territory) (get franchise-id params))
                          (get active territory)
                          (is-none (get overlap-found params)))
                     (if (territories-overlap 
                            (get north-lat params) (get south-lat params) (get east-lng params) (get west-lng params)
                            (get north-lat territory) (get south-lat territory) (get east-lng territory) (get west-lng territory))
                         (merge params {overlap-found: (some territory-index)})
                         params)
                     params)
        params
    )
)

(define-private (territories-overlap (n1 uint) (s1 uint) (e1 uint) (w1 uint) (n2 uint) (s2 uint) (e2 uint) (w2 uint))
    (and (not (> s1 n2)) (not (> s2 n1)) (not (> w1 e2)) (not (> w2 e1)))
)



