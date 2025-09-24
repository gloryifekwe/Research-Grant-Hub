;; Automated Research Grant Distribution Smart Contract
;; This contract manages the submission, evaluation, and distribution of research grants
;; based on proposal quality metrics and automated scoring systems

;; Contract constants for configuration
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-PROPOSAL-TITLE-LENGTH u200)
(define-constant MAX-PROPOSAL-DESCRIPTION-LENGTH u2000)
(define-constant MIN-FUNDING-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-FUNDING-AMOUNT u100000000000) ;; 100,000 STX maximum
(define-constant EVALUATION-PERIOD u144) ;; 144 blocks (~24 hours)
(define-constant MIN-EVALUATOR-COUNT u3)
(define-constant MAX-SCORE u100)
(define-constant PASSING-SCORE-THRESHOLD u70)
(define-constant MAX-CONTRACT-FUNDING u1000000000000) ;; 1,000,000 STX maximum contract balance

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PROPOSAL-TITLE (err u102))
(define-constant ERR-INVALID-PROPOSAL-DESCRIPTION (err u103))
(define-constant ERR-INVALID-FUNDING-AMOUNT (err u104))
(define-constant ERR-PROPOSAL-ALREADY-EXISTS (err u105))
(define-constant ERR-PROPOSAL-ALREADY-EVALUATED (err u106))
(define-constant ERR-EVALUATION-PERIOD-NOT-ENDED (err u107))
(define-constant ERR-INSUFFICIENT-CONTRACT-BALANCE (err u108))
(define-constant ERR-EVALUATOR-ALREADY-VOTED (err u109))
(define-constant ERR-INVALID-SCORE (err u110))
(define-constant ERR-NOT-AUTHORIZED-EVALUATOR (err u111))
(define-constant ERR-PROPOSAL-ALREADY-FUNDED (err u112))
(define-constant ERR-PROPOSAL-NOT-APPROVED (err u113))
(define-constant ERR-EVALUATION-PERIOD-ACTIVE (err u114))
(define-constant ERR-INSUFFICIENT-EVALUATIONS (err u115))
(define-constant ERR-TRANSFER-FAILED (err u116))
(define-constant ERR-INVALID-EVALUATOR (err u117))
(define-constant ERR-CONTRACT-BALANCE-OVERFLOW (err u118))

;; Data variables for contract state management
(define-data-var next-proposal-id uint u1)
(define-data-var total-grants-distributed uint u0)
(define-data-var contract-balance uint u0)

;; Data maps for storing contract information
;; Main proposal storage with all proposal details
(define-map proposals
    { proposal-id: uint }
    {
        title: (string-ascii 200),
        description: (string-ascii 2000),
        researcher: principal,
        funding-requested: uint,
        submission-block: uint,
        status: (string-ascii 20), ;; "pending", "approved", "rejected", "funded"
        total-score: uint,
        evaluation-count: uint,
        final-score: uint
    }
)

;; Individual evaluator scores for each proposal
(define-map proposal-evaluations
    { proposal-id: uint, evaluator: principal }
    {
        technical-score: uint,
        innovation-score: uint,
        feasibility-score: uint,
        impact-score: uint,
        overall-score: uint,
        evaluation-block: uint
    }
)

;; Authorized evaluators who can score proposals
(define-map authorized-evaluators
    { evaluator: principal }
    { 
        authorized: bool,
        evaluation-count: uint,
        reputation-score: uint
    }
)

;; Funding history tracking for transparency
(define-map funding-history
    { proposal-id: uint }
    {
        amount-funded: uint,
        funding-block: uint,
        funding-transaction: (optional (buff 32))
    }
)

;; Read-only functions for querying contract state
;; Get complete proposal details by ID
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

;; Get evaluation details for a specific proposal and evaluator
(define-read-only (get-proposal-evaluation (proposal-id uint) (evaluator principal))
    (map-get? proposal-evaluations { proposal-id: proposal-id, evaluator: evaluator })
)

;; Check if a principal is an authorized evaluator
(define-read-only (is-authorized-evaluator (evaluator principal))
    (match (map-get? authorized-evaluators { evaluator: evaluator })
        evaluator-info (get authorized evaluator-info)
        false
    )
)

;; Get current contract statistics
(define-read-only (get-contract-stats)
    {
        next-proposal-id: (var-get next-proposal-id),
        total-grants-distributed: (var-get total-grants-distributed),
        contract-balance: (var-get contract-balance)
    }
)

;; Get funding history for a specific proposal
(define-read-only (get-funding-history (proposal-id uint))
    (map-get? funding-history { proposal-id: proposal-id })
)

;; Calculate if evaluation period has ended for a proposal
(define-read-only (is-evaluation-period-ended (submission-block uint))
    (>= (- block-height submission-block) EVALUATION-PERIOD)
)

;; Private helper functions for internal contract logic
;; Validate proposal title length and content
(define-private (is-valid-title (title (string-ascii 200)))
    (and 
        (> (len title) u0)
        (<= (len title) MAX-PROPOSAL-TITLE-LENGTH)
    )
)

;; Validate proposal description length and content
(define-private (is-valid-description (description (string-ascii 2000)))
    (and 
        (> (len description) u0)
        (<= (len description) MAX-PROPOSAL-DESCRIPTION-LENGTH)
    )
)

;; Validate funding amount within acceptable range
(define-private (is-valid-funding-amount (amount uint))
    (and 
        (>= amount MIN-FUNDING-AMOUNT)
        (<= amount MAX-FUNDING-AMOUNT)
    )
)

;; Validate evaluation scores are within valid range
(define-private (is-valid-score (score uint))
    (<= score MAX-SCORE)
)

;; Validate evaluator principal is valid (not contract address, not zero address)
(define-private (is-valid-evaluator (evaluator principal))
    (and
        ;; Evaluator cannot be the contract itself
        (not (is-eq evaluator (as-contract tx-sender)))
        ;; Evaluator cannot be the contract owner (to avoid conflicts of interest)
        (not (is-eq evaluator CONTRACT-OWNER))
        ;; Additional validation could be added here for specific address formats
        true
    )
)

;; Validate contract funding amount to prevent overflow
(define-private (is-valid-contract-funding (amount uint))
    (let 
        (
            (current-balance (var-get contract-balance))
            (new-balance (+ current-balance amount))
        )
        (and
            ;; Amount must be positive
            (> amount u0)
            ;; New balance must not overflow (check if addition is safe)
            (> new-balance current-balance)
            ;; New balance must not exceed maximum contract balance
            (<= new-balance MAX-CONTRACT-FUNDING)
        )
    )
)

;; Calculate weighted overall score from individual component scores
(define-private (calculate-overall-score (technical uint) (innovation uint) (feasibility uint) (impact uint))
    ;; Weighted scoring: technical(25%) + innovation(30%) + feasibility(25%) + impact(20%)
    (/ (+ (* technical u25) (* innovation u30) (* feasibility u25) (* impact u20)) u100)
)

;; Public functions for contract interaction
;; Submit a new research proposal for evaluation
(define-public (submit-proposal 
    (title (string-ascii 200)) 
    (description (string-ascii 2000)) 
    (funding-requested uint))
    (let 
        (
            (proposal-id (var-get next-proposal-id))
        )
        ;; Validate all proposal inputs
        (asserts! (is-valid-title title) ERR-INVALID-PROPOSAL-TITLE)
        (asserts! (is-valid-description description) ERR-INVALID-PROPOSAL-DESCRIPTION)
        (asserts! (is-valid-funding-amount funding-requested) ERR-INVALID-FUNDING-AMOUNT)
        
        ;; Store the new proposal with pending status
        (map-set proposals
            { proposal-id: proposal-id }
            {
                title: title,
                description: description,
                researcher: tx-sender,
                funding-requested: funding-requested,
                submission-block: block-height,
                status: "pending",
                total-score: u0,
                evaluation-count: u0,
                final-score: u0
            }
        )
        
        ;; Increment proposal counter for next submission
        (var-set next-proposal-id (+ proposal-id u1))
        
        (ok proposal-id)
    )
)

;; Evaluate a proposal with detailed scoring across multiple criteria
(define-public (evaluate-proposal 
    (proposal-id uint) 
    (technical-score uint) 
    (innovation-score uint) 
    (feasibility-score uint) 
    (impact-score uint))
    (let 
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (overall-score (calculate-overall-score technical-score innovation-score feasibility-score impact-score))
        )
        ;; Verify evaluator authorization
        (asserts! (is-authorized-evaluator tx-sender) ERR-NOT-AUTHORIZED-EVALUATOR)
        ;; Validate all score inputs
        (asserts! (is-valid-score technical-score) ERR-INVALID-SCORE)
        (asserts! (is-valid-score innovation-score) ERR-INVALID-SCORE)
        (asserts! (is-valid-score feasibility-score) ERR-INVALID-SCORE)
        (asserts! (is-valid-score impact-score) ERR-INVALID-SCORE)
        ;; Check evaluation hasn't already been submitted
        (asserts! (is-none (get-proposal-evaluation proposal-id tx-sender)) ERR-EVALUATOR-ALREADY-VOTED)
        ;; Ensure proposal is still in evaluation period
        (asserts! (not (is-evaluation-period-ended (get submission-block proposal))) ERR-EVALUATION-PERIOD-NOT-ENDED)
        
        ;; Store the detailed evaluation
        (map-set proposal-evaluations
            { proposal-id: proposal-id, evaluator: tx-sender }
            {
                technical-score: technical-score,
                innovation-score: innovation-score,
                feasibility-score: feasibility-score,
                impact-score: impact-score,
                overall-score: overall-score,
                evaluation-block: block-height
            }
        )
        
        ;; Update proposal with new evaluation data
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal {
                total-score: (+ (get total-score proposal) overall-score),
                evaluation-count: (+ (get evaluation-count proposal) u1)
            })
        )
        
        ;; Update evaluator statistics
        (match (map-get? authorized-evaluators { evaluator: tx-sender })
            evaluator-info
            (map-set authorized-evaluators
                { evaluator: tx-sender }
                (merge evaluator-info {
                    evaluation-count: (+ (get evaluation-count evaluator-info) u1)
                })
            )
            false
        )
        
        (ok overall-score)
    )
)

;; Finalize proposal evaluation and determine approval status
(define-public (finalize-proposal (proposal-id uint))
    (let 
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (final-score (if (> (get evaluation-count proposal) u0)
                           (/ (get total-score proposal) (get evaluation-count proposal))
                           u0))
            (new-status (if (>= final-score PASSING-SCORE-THRESHOLD) "approved" "rejected"))
        )
        ;; Verify evaluation period has ended
        (asserts! (is-evaluation-period-ended (get submission-block proposal)) ERR-EVALUATION-PERIOD-ACTIVE)
        ;; Ensure minimum number of evaluations received
        (asserts! (>= (get evaluation-count proposal) MIN-EVALUATOR-COUNT) ERR-INSUFFICIENT-EVALUATIONS)
        ;; Check proposal hasn't been finalized already
        (asserts! (is-eq (get status proposal) "pending") ERR-PROPOSAL-ALREADY-EVALUATED)
        
        ;; Update proposal with final results
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal {
                status: new-status,
                final-score: final-score
            })
        )
        
        (ok { final-score: final-score, status: new-status })
    )
)

;; Distribute funding to approved proposals automatically
(define-public (distribute-funding (proposal-id uint))
    (let 
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (funding-amount (get funding-requested proposal))
        )
        ;; Verify proposal is approved and not already funded
        (asserts! (is-eq (get status proposal) "approved") ERR-PROPOSAL-NOT-APPROVED)
        (asserts! (is-none (get-funding-history proposal-id)) ERR-PROPOSAL-ALREADY-FUNDED)
        ;; Check contract has sufficient balance
        (asserts! (>= (var-get contract-balance) funding-amount) ERR-INSUFFICIENT-CONTRACT-BALANCE)
        
        ;; Execute the funding transfer
        (match (stx-transfer? funding-amount (as-contract tx-sender) (get researcher proposal))
            success
            (begin
                ;; Update contract balance and statistics
                (var-set contract-balance (- (var-get contract-balance) funding-amount))
                (var-set total-grants-distributed (+ (var-get total-grants-distributed) funding-amount))
                
                ;; Record funding transaction
                (map-set funding-history
                    { proposal-id: proposal-id }
                    {
                        amount-funded: funding-amount,
                        funding-block: block-height,
                        funding-transaction: none
                    }
                )
                
                ;; Update proposal status to funded
                (map-set proposals
                    { proposal-id: proposal-id }
                    (merge proposal { status: "funded" })
                )
                
                (ok funding-amount)
            )
            error ERR-TRANSFER-FAILED
        )
    )
)

;; Add or update authorized evaluator (admin function)
(define-public (add-authorized-evaluator (evaluator principal))
    (begin
        ;; Only contract owner can authorize evaluators
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        ;; Validate evaluator principal
        (asserts! (is-valid-evaluator evaluator) ERR-INVALID-EVALUATOR)
        
        (map-set authorized-evaluators
            { evaluator: evaluator }
            {
                authorized: true,
                evaluation-count: u0,
                reputation-score: u50 ;; Starting reputation score
            }
        )
        
        (ok true)
    )
)

;; Remove evaluator authorization (admin function)
(define-public (remove-authorized-evaluator (evaluator principal))
    (begin
        ;; Only contract owner can remove evaluator authorization
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        ;; Validate evaluator principal
        (asserts! (is-valid-evaluator evaluator) ERR-INVALID-EVALUATOR)
        
        (map-set authorized-evaluators
            { evaluator: evaluator }
            {
                authorized: false,
                evaluation-count: u0,
                reputation-score: u0
            }
        )
        
        (ok true)
    )
)

;; Fund the contract to enable grant distribution
(define-public (fund-contract (amount uint))
    (begin
        ;; Validate funding amount to prevent overflow
        (asserts! (is-valid-contract-funding amount) ERR-CONTRACT-BALANCE-OVERFLOW)
        
        ;; Transfer STX to contract for grant distribution
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        ;; Update contract balance tracking
        (var-set contract-balance (+ (var-get contract-balance) amount))
        
        (ok (var-get contract-balance))
    )
)