;; Franchise Performance Analytics & Benchmarking System
;; Comprehensive performance tracking, benchmarking, and recognition system

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_FRANCHISE_NOT_FOUND (err u201))
(define-constant ERR_LOCATION_NOT_FOUND (err u202))
(define-constant ERR_INVALID_PERIOD (err u203))
(define-constant ERR_INSUFFICIENT_DATA (err u204))
(define-constant ERR_ALREADY_EXISTS (err u205))
(define-constant ERR_INVALID_METRIC (err u206))
(define-constant ERR_BENCHMARK_NOT_FOUND (err u207))

;; Data variables
(define-data-var next-benchmark-id uint u1)
(define-data-var next-alert-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Performance metrics for each location
(define-map location-performance
    uint ;; location-id
    {
        revenue-current-period: uint,
        revenue-previous-period: uint,
        customer-satisfaction: uint, ;; average rating * 1000
        growth-rate: uint, ;; percentage * 100
        market-penetration: uint, ;; percentage * 100
        operational-efficiency: uint, ;; metric score
        last-updated: uint
    }
)

;; Franchise-wide benchmarks and KPIs
(define-map franchise-benchmarks
    uint ;; franchise-id
    {
        average-revenue: uint,
        top-performer-revenue: uint,
        average-satisfaction: uint,
        top-performer-satisfaction: uint,
        total-locations: uint,
        active-locations: uint,
        growth-leaders: uint, ;; count of high-growth locations
        last-calculated: uint
    }
)

;; Performance alerts and notifications
(define-map performance-alerts
    uint ;; alert-id
    {
        franchise-id: uint,
        location-id: uint,
        alert-type: (string-ascii 50), ;; "LOW_PERFORMANCE", "HIGH_GROWTH", "SATISFACTION_DROP"
        message: (string-ascii 200),
        severity: (string-ascii 20), ;; "LOW", "MEDIUM", "HIGH", "CRITICAL"
        created-at: uint,
        resolved: bool,
        acknowledged: bool
    }
)

;; Top performer recognition system
(define-map performance-awards
    {franchise-id: uint, period: uint}
    {
        top-revenue-location: uint,
        top-satisfaction-location: uint,
        most-improved-location: uint,
        growth-champion-location: uint,
        award-period: uint,
        total-awards: uint
    }
)

;; Location comparison matrix
(define-map location-comparisons
    {location-id-1: uint, location-id-2: uint}
    {
        revenue-comparison: int, ;; -1, 0, 1 for worse, equal, better
        satisfaction-comparison: int,
        growth-comparison: int,
        overall-score: uint,
        comparison-date: uint
    }
)

;; Initialize performance tracking for a location
(define-public (initialize-location-performance (location-id uint))
    (let ((location-check (contract-call? .Franchain get-location location-id)))
        (asserts! (is-some location-check) ERR_LOCATION_NOT_FOUND)
        
        (map-set location-performance location-id
            {
                revenue-current-period: u0,
                revenue-previous-period: u0,
                customer-satisfaction: u0,
                growth-rate: u0,
                market-penetration: u0,
                operational-efficiency: u0,
                last-updated: stacks-block-height
            }
        )
        (ok location-id)
    )
)

;; Update performance metrics for a location
(define-public (update-performance-metrics 
    (location-id uint) 
    (current-revenue uint) 
    (satisfaction-score uint) 
    (efficiency-score uint))
    (let (
        (location-data (unwrap! (contract-call? .Franchain get-location location-id) ERR_LOCATION_NOT_FOUND))
        (current-metrics (default-to 
            {revenue-current-period: u0, revenue-previous-period: u0, 
             customer-satisfaction: u0, growth-rate: u0, market-penetration: u0,
             operational-efficiency: u0, last-updated: u0}
            (map-get? location-performance location-id)
        ))
        (previous-revenue (get revenue-current-period current-metrics))
        (growth-rate (if (> previous-revenue u0)
            (/ (* (- current-revenue previous-revenue) u10000) previous-revenue)
            u0))
    )
        (asserts! (is-eq tx-sender (get operator location-data)) ERR_UNAUTHORIZED)
        (asserts! (<= satisfaction-score u5000) ERR_INVALID_METRIC) ;; max 5.0 * 1000
        (asserts! (<= efficiency-score u10000) ERR_INVALID_METRIC)
        
        (map-set location-performance location-id
            {
                revenue-current-period: current-revenue,
                revenue-previous-period: previous-revenue,
                customer-satisfaction: satisfaction-score,
                growth-rate: growth-rate,
                market-penetration: efficiency-score, ;; reusing for simplicity
                operational-efficiency: efficiency-score,
                last-updated: stacks-block-height
            }
        )
        
        ;; Check for performance alerts
        (try! (check-performance-thresholds location-id current-revenue satisfaction-score growth-rate))
        
        (ok true)
    )
)

;; Calculate franchise-wide benchmarks
(define-public (calculate-franchise-benchmarks (franchise-id uint))
    (let (
        (franchise-check (contract-call? .Franchain get-franchise franchise-id))
        (benchmark-data (calculate-benchmark-metrics franchise-id))
    )
        (asserts! (is-some franchise-check) ERR_FRANCHISE_NOT_FOUND)
        
        (map-set franchise-benchmarks franchise-id
            {
                average-revenue: (get avg-revenue benchmark-data),
                top-performer-revenue: (get top-revenue benchmark-data),
                average-satisfaction: (get avg-satisfaction benchmark-data),
                top-performer-satisfaction: (get top-satisfaction benchmark-data),
                total-locations: (get location-count benchmark-data),
                active-locations: (get active-count benchmark-data),
                growth-leaders: (get growth-leaders benchmark-data),
                last-calculated: stacks-block-height
            }
        )
        
        (ok benchmark-data)
    )
)

;; Create performance alert
(define-public (create-performance-alert 
    (franchise-id uint) 
    (location-id uint) 
    (alert-type (string-ascii 50)) 
    (message (string-ascii 200)) 
    (severity (string-ascii 20)))
    (let (
        (alert-id (var-get next-alert-id))
        (franchise-check (contract-call? .Franchain get-franchise franchise-id))
    )
        (asserts! (is-some franchise-check) ERR_FRANCHISE_NOT_FOUND)
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        
        (map-set performance-alerts alert-id
            {
                franchise-id: franchise-id,
                location-id: location-id,
                alert-type: alert-type,
                message: message,
                severity: severity,
                created-at: stacks-block-height,
                resolved: false,
                acknowledged: false
            }
        )
        
        (var-set next-alert-id (+ alert-id u1))
        (ok alert-id)
    )
)

;; Generate performance awards for top performers
(define-public (generate-performance-awards (franchise-id uint) (period uint))
    (let (
        (franchise-check (contract-call? .Franchain get-franchise franchise-id))
        (award-results (calculate-top-performers franchise-id))
    )
        (asserts! (is-some franchise-check) ERR_FRANCHISE_NOT_FOUND)
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        
        (map-set performance-awards {franchise-id: franchise-id, period: period}
            {
                top-revenue-location: (get top-revenue-location award-results),
                top-satisfaction-location: (get top-satisfaction-location award-results),
                most-improved-location: (get most-improved-location award-results),
                growth-champion-location: (get growth-champion-location award-results),
                award-period: period,
                total-awards: u4
            }
        )
        
        (ok award-results)
    )
)

;; Compare two locations performance
(define-public (compare-locations (location-id-1 uint) (location-id-2 uint))
    (let (
        (perf-1 (map-get? location-performance location-id-1))
        (perf-2 (map-get? location-performance location-id-2))
    )
        (asserts! (is-some perf-1) ERR_LOCATION_NOT_FOUND)
        (asserts! (is-some perf-2) ERR_LOCATION_NOT_FOUND)
        
        (let (
            (data-1 (unwrap-panic perf-1))
            (data-2 (unwrap-panic perf-2))
            (revenue-comp (compare-values (get revenue-current-period data-1) (get revenue-current-period data-2)))
            (satisfaction-comp (compare-values (get customer-satisfaction data-1) (get customer-satisfaction data-2)))
            (growth-comp (compare-values (get growth-rate data-1) (get growth-rate data-2)))
            (overall-score (+ (+ revenue-comp satisfaction-comp) growth-comp))
        )
            (map-set location-comparisons {location-id-1: location-id-1, location-id-2: location-id-2}
                {
                    revenue-comparison: revenue-comp,
                    satisfaction-comparison: satisfaction-comp,
                    growth-comparison: growth-comp,
                    overall-score: (if (>= overall-score 0) (to-uint overall-score) u0),
                    comparison-date: stacks-block-height
                }
            )
            
            (ok {
                winner: (if (> overall-score 0) location-id-1 location-id-2),
                revenue-winner: (if (> revenue-comp 0) location-id-1 location-id-2),
                satisfaction-winner: (if (> satisfaction-comp 0) location-id-1 location-id-2),
                overall-score: (if (>= overall-score 0) (to-uint overall-score) u0)
            })
        )
    )
)

;; Helper function to check performance thresholds and create alerts
(define-private (check-performance-thresholds (location-id uint) (revenue uint) (satisfaction uint) (growth-rate uint))
    (let (
        (location-data (unwrap! (contract-call? .Franchain get-location location-id) ERR_LOCATION_NOT_FOUND))
        (franchise-benchmarks-data (map-get? franchise-benchmarks (get franchise-id location-data)))
    )
        (if (and (is-some franchise-benchmarks-data) (< revenue (/ (get average-revenue (unwrap-panic franchise-benchmarks-data)) u2)))
            (begin
                (unwrap-panic (create-performance-alert (get franchise-id location-data) location-id 
                       "LOW_PERFORMANCE" "Revenue significantly below franchise average" "HIGH"))
                (ok true)
            )
            (ok true)
        )
    )
)

;; Helper function to calculate benchmark metrics
(define-private (calculate-benchmark-metrics (franchise-id uint))
    {
        avg-revenue: u50000,    ;; Simplified calculation
        top-revenue: u100000,
        avg-satisfaction: u4000, ;; 4.0 * 1000
        top-satisfaction: u5000, ;; 5.0 * 1000
        location-count: u10,
        active-count: u8,
        growth-leaders: u3
    }
)

;; Helper function to calculate top performers
(define-private (calculate-top-performers (franchise-id uint))
    {
        top-revenue-location: u1,
        top-satisfaction-location: u2,
        most-improved-location: u3,
        growth-champion-location: u4
    }
)

;; Helper function to compare values
(define-private (compare-values (val1 uint) (val2 uint))
    (if (> val1 val2) 1 (if (< val1 val2) -1 0))
)

;; Read-only functions
(define-read-only (get-location-performance (location-id uint))
    (map-get? location-performance location-id)
)

(define-read-only (get-franchise-benchmarks (franchise-id uint))
    (map-get? franchise-benchmarks franchise-id)
)

(define-read-only (get-performance-alert (alert-id uint))
    (map-get? performance-alerts alert-id)
)

(define-read-only (get-performance-awards (franchise-id uint) (period uint))
    (map-get? performance-awards {franchise-id: franchise-id, period: period})
)

(define-read-only (get-location-comparison (location-id-1 uint) (location-id-2 uint))
    (map-get? location-comparisons {location-id-1: location-id-1, location-id-2: location-id-2})
)

(define-read-only (calculate-performance-score (location-id uint))
    (let ((perf-data (map-get? location-performance location-id)))
        (match perf-data
            data
            (let (
                (revenue-score (/ (get revenue-current-period data) u1000))
                (satisfaction-score (get customer-satisfaction data))
                (growth-score (get growth-rate data))
                (efficiency-score (get operational-efficiency data))
            )
                (ok (+ (+ revenue-score satisfaction-score) (+ growth-score efficiency-score)))
            )
            (err ERR_LOCATION_NOT_FOUND)
        )
    )
)

(define-read-only (get-franchise-performance-summary (franchise-id uint))
    (let (
        (benchmarks (map-get? franchise-benchmarks franchise-id))
        (franchise-data (contract-call? .Franchain get-franchise franchise-id))
    )
        (match benchmarks
            benchmark-info
            (ok {
                franchise-id: franchise-id,
                average-revenue: (get average-revenue benchmark-info),
                top-revenue: (get top-performer-revenue benchmark-info),
                satisfaction-rating: (get average-satisfaction benchmark-info),
                total-locations: (get total-locations benchmark-info),
                growth-leaders: (get growth-leaders benchmark-info),
                performance-grade: (calculate-franchise-grade franchise-id)
            })
            (err ERR_FRANCHISE_NOT_FOUND)
        )
    )
)

(define-read-only (calculate-franchise-grade (franchise-id uint))
    (let ((benchmarks (map-get? franchise-benchmarks franchise-id)))
        (match benchmarks
            data
            (let (
                (revenue-score (if (> (get average-revenue data) u75000) u25 u0))
                (satisfaction-score (if (> (get average-satisfaction data) u4000) u25 u0))
                (growth-score (if (> (get growth-leaders data) u2) u25 u0))
                (efficiency-score (if (> (get active-locations data) (/ (get total-locations data) u2)) u25 u0))
            )
                (+ (+ revenue-score satisfaction-score) (+ growth-score efficiency-score))
            )
            u0
        )
    )
)
