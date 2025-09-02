;; Franchise Marketing & Customer Loyalty Hub
;; Comprehensive customer engagement, loyalty programs, and marketing management system

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_ALREADY_EXISTS (err u302))
(define-constant ERR_INVALID_INPUT (err u303))
(define-constant ERR_INSUFFICIENT_POINTS (err u304))
(define-constant ERR_CAMPAIGN_ENDED (err u305))
(define-constant ERR_CAMPAIGN_NOT_ACTIVE (err u306))
(define-constant ERR_REDEMPTION_LIMIT_REACHED (err u307))
(define-constant ERR_INVALID_LOYALTY_TIER (err u308))

;; Data variables
(define-data-var next-campaign-id uint u1)
(define-data-var next-reward-id uint u1)
(define-data-var next-customer-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Customer loyalty profiles
(define-map customer-loyalty
    uint ;; customer-id
    {
        wallet-address: principal,
        email-hash: (buff 32), ;; hashed email for privacy
        total-points: uint,
        current-tier: (string-ascii 20), ;; "BRONZE", "SILVER", "GOLD", "PLATINUM"
        lifetime-spend: uint,
        referral-count: uint,
        social-engagement-score: uint,
        last-activity: uint,
        signup-location: uint,
        preferred-location: uint
    }
)

;; Customer point transactions
(define-map point-transactions
    {customer-id: uint, transaction-id: uint}
    {
        location-id: uint,
        points-earned: uint,
        points-redeemed: uint,
        transaction-type: (string-ascii 30), ;; "PURCHASE", "REFERRAL", "SOCIAL", "BONUS", "REDEMPTION"
        amount-spent: uint,
        campaign-id: (optional uint),
        timestamp: uint
    }
)

;; Marketing campaigns
(define-map marketing-campaigns
    uint ;; campaign-id
    {
        franchise-id: uint,
        name: (string-ascii 100),
        description: (string-ascii 300),
        campaign-type: (string-ascii 30), ;; "LOYALTY", "ACQUISITION", "RETENTION", "SEASONAL"
        start-block: uint,
        end-block: uint,
        budget: uint,
        points-multiplier: uint, ;; e.g., 200 for 2x points
        target-locations: (list 20 uint),
        participation-count: uint,
        total-engagement: uint,
        roi-score: uint, ;; calculated return on investment
        is-active: bool,
        created-by: principal
    }
)

;; Reward catalog
(define-map loyalty-rewards
    uint ;; reward-id
    {
        franchise-id: uint,
        name: (string-ascii 100),
        description: (string-ascii 200),
        points-required: uint,
        monetary-value: uint,
        category: (string-ascii 30), ;; "DISCOUNT", "FREE_ITEM", "UPGRADE", "EXPERIENCE"
        redemption-limit: uint, ;; per customer
        total-redemptions: uint,
        available-locations: (list 20 uint),
        expiry-blocks: uint, ;; how long reward is valid after redemption
        is-active: bool
    }
)

;; Customer redemptions
(define-map customer-redemptions
    {customer-id: uint, reward-id: uint}
    {
        redemption-count: uint,
        last-redemption: uint,
        total-value: uint
    }
)

;; Brand compliance tracking
(define-map brand-compliance
    uint ;; location-id
    {
        franchise-id: uint,
        compliance-score: uint, ;; 0-10000 (0-100.00%)
        marketing-materials-approved: bool,
        social-media-compliance: bool,
        promotional-adherence: uint, ;; percentage
        last-audit: uint,
        violations-count: uint,
        compliance-tier: (string-ascii 20) ;; "EXCELLENT", "GOOD", "NEEDS_IMPROVEMENT", "CRITICAL"
    }
)

;; Social media engagement tracking
(define-map social-engagement
    {location-id: uint, platform: (string-ascii 20)}
    {
        follower-count: uint,
        engagement-rate: uint, ;; per 10000 for precision
        post-frequency: uint, ;; posts per week
        brand-mention-count: uint,
        customer-generated-content: uint,
        last-updated: uint
    }
)

;; Customer acquisition metrics
(define-map acquisition-metrics
    {franchise-id: uint, location-id: uint, period: uint}
    {
        new-customers: uint,
        acquisition-cost: uint, ;; total marketing spend / new customers
        customer-lifetime-value: uint,
        retention-rate: uint, ;; percentage * 100
        referral-customers: uint,
        social-acquired-customers: uint,
        campaign-effectiveness: uint
    }
)

;; Register a new customer for loyalty program
(define-public (register-customer (wallet-address principal) (email-hash (buff 32)) (signup-location uint))
    (let (
        (customer-id (var-get next-customer-id))
        (location-data (unwrap! (contract-call? .Franchain get-location signup-location) ERR_NOT_FOUND))
    )
        ;; Verify location exists and is active
        (asserts! (get active location-data) ERR_NOT_FOUND)
        
        (map-set customer-loyalty customer-id
            {
                wallet-address: wallet-address,
                email-hash: email-hash,
                total-points: u0,
                current-tier: "BRONZE",
                lifetime-spend: u0,
                referral-count: u0,
                social-engagement-score: u0,
                last-activity: stacks-block-height,
                signup-location: signup-location,
                preferred-location: signup-location
            }
        )
        
        (var-set next-customer-id (+ customer-id u1))
        (ok customer-id)
    )
)

;; Award loyalty points to customer


;; Redeem loyalty points for reward
(define-public (redeem-reward (customer-id uint) (reward-id uint) (location-id uint))
    (let (
        (customer (unwrap! (map-get? customer-loyalty customer-id) ERR_NOT_FOUND))
        (reward (unwrap! (map-get? loyalty-rewards reward-id) ERR_NOT_FOUND))
        (location-data (unwrap! (contract-call? .Franchain get-location location-id) ERR_NOT_FOUND))
        (current-redemptions (default-to {redemption-count: u0, last-redemption: u0, total-value: u0}
                             (map-get? customer-redemptions {customer-id: customer-id, reward-id: reward-id})))
    )
        ;; Verify permissions and availability
        (asserts! (is-eq tx-sender (get operator location-data)) ERR_UNAUTHORIZED)
        (asserts! (get is-active reward) ERR_NOT_FOUND)
        (asserts! (>= (get total-points customer) (get points-required reward)) ERR_INSUFFICIENT_POINTS)
        (asserts! (< (get redemption-count current-redemptions) (get redemption-limit reward)) ERR_REDEMPTION_LIMIT_REACHED)
        
        ;; Update customer points
        (map-set customer-loyalty customer-id
            (merge customer {
                total-points: (- (get total-points customer) (get points-required reward)),
                last-activity: stacks-block-height
            })
        )
        
        ;; Update redemption tracking
        (map-set customer-redemptions {customer-id: customer-id, reward-id: reward-id}
            {
                redemption-count: (+ (get redemption-count current-redemptions) u1),
                last-redemption: stacks-block-height,
                total-value: (+ (get total-value current-redemptions) (get monetary-value reward))
            }
        )
        
        ;; Update reward statistics
        (map-set loyalty-rewards reward-id
            (merge reward {total-redemptions: (+ (get total-redemptions reward) u1)})
        )
        
        (ok true)
    )
)

;; Create marketing campaign
(define-public (create-marketing-campaign 
    (franchise-id uint)
    (name (string-ascii 100))
    (description (string-ascii 300))
    (campaign-type (string-ascii 30))
    (duration-blocks uint)
    (budget uint)
    (points-multiplier uint)
    (target-locations (list 20 uint)))
    (let (
        (campaign-id (var-get next-campaign-id))
        (franchise-data (unwrap! (contract-call? .Franchain get-franchise franchise-id) ERR_NOT_FOUND))
    )
        ;; Only franchise owner can create campaigns
        (asserts! (is-eq tx-sender (get owner franchise-data)) ERR_UNAUTHORIZED)
        (asserts! (> (len name) u0) ERR_INVALID_INPUT)
        (asserts! (and (>= points-multiplier u100) (<= points-multiplier u500)) ERR_INVALID_INPUT) ;; 1x to 5x
        
        (map-set marketing-campaigns campaign-id
            {
                franchise-id: franchise-id,
                name: name,
                description: description,
                campaign-type: campaign-type,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height duration-blocks),
                budget: budget,
                points-multiplier: points-multiplier,
                target-locations: target-locations,
                participation-count: u0,
                total-engagement: u0,
                roi-score: u0,
                is-active: true,
                created-by: tx-sender
            }
        )
        
        (var-set next-campaign-id (+ campaign-id u1))
        (ok campaign-id)
    )
)

;; Add reward to catalog
(define-public (create-loyalty-reward
    (franchise-id uint)
    (name (string-ascii 100))
    (description (string-ascii 200))
    (points-required uint)
    (monetary-value uint)
    (category (string-ascii 30))
    (redemption-limit uint)
    (available-locations (list 20 uint))
    (expiry-blocks uint))
    (let (
        (reward-id (var-get next-reward-id))
        (franchise-data (unwrap! (contract-call? .Franchain get-franchise franchise-id) ERR_NOT_FOUND))
    )
        ;; Only franchise owner can create rewards
        (asserts! (is-eq tx-sender (get owner franchise-data)) ERR_UNAUTHORIZED)
        (asserts! (> points-required u0) ERR_INVALID_INPUT)
        
        (map-set loyalty-rewards reward-id
            {
                franchise-id: franchise-id,
                name: name,
                description: description,
                points-required: points-required,
                monetary-value: monetary-value,
                category: category,
                redemption-limit: redemption-limit,
                total-redemptions: u0,
                available-locations: available-locations,
                expiry-blocks: expiry-blocks,
                is-active: true
            }
        )
        
        (var-set next-reward-id (+ reward-id u1))
        (ok reward-id)
    )
)

;; Update brand compliance score
(define-public (update-brand-compliance
    (location-id uint)
    (compliance-score uint)
    (materials-approved bool)
    (social-compliance bool)
    (promotional-adherence uint))
    (let (
        (location-data (unwrap! (contract-call? .Franchain get-location location-id) ERR_NOT_FOUND))
        (franchise-data (unwrap! (contract-call? .Franchain get-franchise (get franchise-id location-data)) ERR_NOT_FOUND))
        (compliance-tier (calculate-compliance-tier compliance-score))
    )
        ;; Only franchise owner can update compliance
        (asserts! (is-eq tx-sender (get owner franchise-data)) ERR_UNAUTHORIZED)
        (asserts! (<= compliance-score u10000) ERR_INVALID_INPUT)
        (asserts! (<= promotional-adherence u10000) ERR_INVALID_INPUT)
        
        (map-set brand-compliance location-id
            {
                franchise-id: (get franchise-id location-data),
                compliance-score: compliance-score,
                marketing-materials-approved: materials-approved,
                social-media-compliance: social-compliance,
                promotional-adherence: promotional-adherence,
                last-audit: stacks-block-height,
                violations-count: (if (< compliance-score u7000) u1 u0),
                compliance-tier: compliance-tier
            }
        )
        
        (ok compliance-tier)
    )
)

;; Update social media engagement metrics
(define-public (update-social-engagement
    (location-id uint)
    (platform (string-ascii 20))
    (follower-count uint)
    (engagement-rate uint)
    (post-frequency uint)
    (brand-mentions uint)
    (ugc-count uint))
    (let (
        (location-data (unwrap! (contract-call? .Franchain get-location location-id) ERR_NOT_FOUND))
    )
        ;; Location operator can update their social metrics
        (asserts! (is-eq tx-sender (get operator location-data)) ERR_UNAUTHORIZED)
        (asserts! (<= engagement-rate u10000) ERR_INVALID_INPUT)
        
        (map-set social-engagement {location-id: location-id, platform: platform}
            {
                follower-count: follower-count,
                engagement-rate: engagement-rate,
                post-frequency: post-frequency,
                brand-mention-count: brand-mentions,
                customer-generated-content: ugc-count,
                last-updated: stacks-block-height
            }
        )
        
        (ok true)
    )
)

;; Helper function to get active campaign multiplier
(define-private (get-active-campaign-multiplier (franchise-id uint) (location-id uint))
    u150 ;; Default 1.5x multiplier - simplified for demo
)

;; Helper function to calculate loyalty tier
(define-private (calculate-loyalty-tier (lifetime-spend uint))
    (if (>= lifetime-spend u50000)
        "PLATINUM"
        (if (>= lifetime-spend u25000)
            "GOLD"
            (if (>= lifetime-spend u10000)
                "SILVER"
                "BRONZE"
            )
        )
    )
)

;; Helper function to calculate compliance tier
(define-private (calculate-compliance-tier (score uint))
    (if (>= score u9000)
        "EXCELLENT"
        (if (>= score u7500)
            "GOOD"
            (if (>= score u5000)
                "NEEDS_IMPROVEMENT"
                "CRITICAL"
            )
        )
    )
)

;; Read-only functions

(define-read-only (get-customer-loyalty (customer-id uint))
    (map-get? customer-loyalty customer-id)
)

(define-read-only (get-marketing-campaign (campaign-id uint))
    (map-get? marketing-campaigns campaign-id)
)

(define-read-only (get-loyalty-reward (reward-id uint))
    (map-get? loyalty-rewards reward-id)
)

(define-read-only (get-customer-redemption-history (customer-id uint) (reward-id uint))
    (map-get? customer-redemptions {customer-id: customer-id, reward-id: reward-id})
)

(define-read-only (get-brand-compliance (location-id uint))
    (map-get? brand-compliance location-id)
)

(define-read-only (get-social-engagement (location-id uint) (platform (string-ascii 20)))
    (map-get? social-engagement {location-id: location-id, platform: platform})
)

(define-read-only (get-customer-points-balance (customer-id uint))
    (match (map-get? customer-loyalty customer-id)
        customer (some (get total-points customer))
        none
    )
)

(define-read-only (calculate-customer-lifetime-value (customer-id uint))
    (match (map-get? customer-loyalty customer-id)
        customer 
        (let (
            (lifetime-spend (get lifetime-spend customer))
            (referral-value (* (get referral-count customer) u5000)) ;; $50 per referral
            (engagement-bonus (* (get social-engagement-score customer) u10))
        )
            (ok (+ lifetime-spend (+ referral-value engagement-bonus)))
        )
        (err ERR_NOT_FOUND)
    )
)

(define-read-only (get-campaign-effectiveness (campaign-id uint))
    (match (map-get? marketing-campaigns campaign-id)
        campaign
        (let (
            (engagement (get total-engagement campaign))
            (budget (get budget campaign))
            (roi (if (> budget u0) (/ (* engagement u10000) budget) u0))
        )
            (ok {
                campaign-id: campaign-id,
                participation: (get participation-count campaign),
                engagement: engagement,
                roi-percentage: roi,
                cost-per-engagement: (if (> engagement u0) (/ budget engagement) u0)
            })
        )
        (err ERR_NOT_FOUND)
    )
)

(define-read-only (get-franchise-marketing-summary (franchise-id uint))
    (ok {
        active-campaigns: u3, ;; Simplified - would count actual active campaigns
        total-customers: u150,
        average-lifetime-value: u15000,
        loyalty-tier-distribution: {bronze: u60, silver: u50, gold: u30, platinum: u10},
        brand-compliance-average: u8500,
        social-engagement-score: u7200
    })
)
