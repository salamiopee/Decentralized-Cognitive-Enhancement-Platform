;; Attention Restoration Therapy Contract
;; Rehabilitates focus and concentration abilities damaged by digital distraction

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-USER-NOT-FOUND (err u402))
(define-constant ERR-SESSION-NOT-FOUND (err u403))
(define-constant ERR-THERAPY-COMPLETE (err u404))
(define-constant MIN-ATTENTION-SPAN u5)
(define-constant MAX-ATTENTION-SPAN u300)

;; Data Variables
(define-data-var therapy-session-counter uint u0)
(define-data-var attention-test-counter uint u0)

;; Data Maps
(define-map user-attention-profiles
  principal
  {
    baseline-span: uint,
    current-span: uint,
    peak-span: uint,
    distraction-resistance: uint,
    focus-quality: uint,
    therapy-level: uint,
    sessions-completed: uint,
    last-assessment: uint,
    improvement-rate: uint
  }
)

(define-map therapy-sessions
  uint
  {
    user: principal,
    session-type: (string-ascii 40),
    duration: uint,
    difficulty-level: uint,
    start-time: uint,
    end-time: (optional uint),
    distractions-resisted: uint,
    focus-breaks: uint,
    completion-rate: uint,
    improvement-score: (optional uint)
  }
)

(define-map attention-tests
  uint
  {
    user: principal,
    test-type: (string-ascii 30),
    duration: uint,
    correct-responses: uint,
    total-stimuli: uint,
    reaction-time: uint,
    accuracy-score: uint,
    attention-span: uint,
    timestamp: uint
  }
)

(define-map distraction-patterns
  {user: principal, pattern-type: (string-ascii 30)}
  {
    frequency: uint,
    intensity: uint,
    trigger-contexts: (string-ascii 100),
    resistance-level: uint,
    last-occurrence: uint
  }
)

(define-map focus-techniques
  {user: principal, technique: (string-ascii 40)}
  {
    effectiveness-rating: uint,
    usage-count: uint,
    success-rate: uint,
    preferred-duration: uint,
    last-used: uint
  }
)

;; Public Functions

;; Initialize user attention profile
(define-public (initialize-attention-profile (baseline-span uint))
  (let ((user tx-sender))
    (asserts! (>= baseline-span MIN-ATTENTION-SPAN) ERR-INVALID-INPUT)
    (asserts! (<= baseline-span MAX-ATTENTION-SPAN) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? user-attention-profiles user)) ERR-INVALID-INPUT)

    (map-set user-attention-profiles user {
      baseline-span: baseline-span,
      current-span: baseline-span,
      peak-span: baseline-span,
      distraction-resistance: u20,
      focus-quality: u50,
      therapy-level: u1,
      sessions-completed: u0,
      last-assessment: block-height,
      improvement-rate: u0
    })

    (ok true)
  )
)

;; Start attention restoration therapy session
(define-public (start-therapy-session (session-type (string-ascii 40)) (duration uint) (difficulty uint))
  (let (
    (user tx-sender)
    (session-id (+ (var-get therapy-session-counter) u1))
    (user-profile (unwrap! (map-get? user-attention-profiles user) ERR-USER-NOT-FOUND))
  )
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (asserts! (<= duration u180) ERR-INVALID-INPUT) ;; Max 3 hours
    (asserts! (> difficulty u0) ERR-INVALID-INPUT)
    (asserts! (<= difficulty u10) ERR-INVALID-INPUT)

    (map-set therapy-sessions session-id {
      user: user,
      session-type: session-type,
      duration: duration,
      difficulty-level: difficulty,
      start-time: block-height,
      end-time: none,
      distractions-resisted: u0,
      focus-breaks: u0,
      completion-rate: u0,
      improvement-score: none
    })

    (var-set therapy-session-counter session-id)
    (ok session-id)
  )
)

;; Complete therapy session with results
(define-public (complete-therapy-session (session-id uint) (distractions-resisted uint) (focus-breaks uint) (completion-rate uint))
  (let (
    (user tx-sender)
    (session (unwrap! (map-get? therapy-sessions session-id) ERR-SESSION-NOT-FOUND))
    (user-profile (unwrap! (map-get? user-attention-profiles user) ERR-USER-NOT-FOUND))
  )
    (asserts! (is-eq (get user session) user) ERR-NOT-AUTHORIZED)
    (asserts! (<= completion-rate u100) ERR-INVALID-INPUT)

    ;; Calculate improvement score
    (let ((improvement (calculate-session-improvement completion-rate distractions-resisted focus-breaks (get difficulty-level session))))
      ;; Update session
      (map-set therapy-sessions session-id (merge session {
        end-time: (some block-height),
        distractions-resisted: distractions-resisted,
        focus-breaks: focus-breaks,
        completion-rate: completion-rate,
        improvement-score: (some improvement)
      }))

      ;; Update user profile
      (let (
        (new-span (+ (get current-span user-profile) (/ improvement u20)))
        (new-resistance (+ (get distraction-resistance user-profile) (/ distractions-resisted u10)))
        (new-quality (+ (get focus-quality user-profile) (/ completion-rate u10)))
      )
        (map-set user-attention-profiles user (merge user-profile {
          current-span: new-span,
          peak-span: (if (> new-span (get peak-span user-profile)) new-span (get peak-span user-profile)),
          distraction-resistance: (if (> new-resistance u100) u100 new-resistance),
          focus-quality: (if (> new-quality u100) u100 new-quality),
          sessions-completed: (+ (get sessions-completed user-profile) u1),
          last-assessment: block-height,
          improvement-rate: improvement
        }))
      )
    )

    (ok true)
  )
)

;; Conduct attention span test
(define-public (conduct-attention-test (test-type (string-ascii 30)) (duration uint) (correct-responses uint) (total-stimuli uint) (reaction-time uint))
  (let (
    (user tx-sender)
    (test-id (+ (var-get attention-test-counter) u1))
    (user-profile (unwrap! (map-get? user-attention-profiles user) ERR-USER-NOT-FOUND))
  )
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (asserts! (> total-stimuli u0) ERR-INVALID-INPUT)
    (asserts! (<= correct-responses total-stimuli) ERR-INVALID-INPUT)
    (asserts! (> reaction-time u0) ERR-INVALID-INPUT)

    (let (
      (accuracy (/ (* correct-responses u100) total-stimuli))
      (attention-span (calculate-attention-span duration accuracy reaction-time))
    )
      (map-set attention-tests test-id {
        user: user,
        test-type: test-type,
        duration: duration,
        correct-responses: correct-responses,
        total-stimuli: total-stimuli,
        reaction-time: reaction-time,
        accuracy-score: accuracy,
        attention-span: attention-span,
        timestamp: block-height
      })

      ;; Update user profile if this is a new peak
      (if (> attention-span (get current-span user-profile))
        (map-set user-attention-profiles user (merge user-profile {
          current-span: attention-span,
          peak-span: (if (> attention-span (get peak-span user-profile)) attention-span (get peak-span user-profile)),
          last-assessment: block-height
        }))
        true
      )
    )

    (var-set attention-test-counter test-id)
    (ok test-id)
  )
)

;; Record distraction pattern
(define-public (record-distraction (pattern-type (string-ascii 30)) (frequency uint) (intensity uint) (context (string-ascii 100)))
  (let (
    (user tx-sender)
    (pattern-key {user: user, pattern-type: pattern-type})
    (user-profile (unwrap! (map-get? user-attention-profiles user) ERR-USER-NOT-FOUND))
  )
    (asserts! (> frequency u0) ERR-INVALID-INPUT)
    (asserts! (<= frequency u100) ERR-INVALID-INPUT)
    (asserts! (> intensity u0) ERR-INVALID-INPUT)
    (asserts! (<= intensity u10) ERR-INVALID-INPUT)

    (map-set distraction-patterns pattern-key {
      frequency: frequency,
      intensity: intensity,
      trigger-contexts: context,
      resistance-level: (get distraction-resistance user-profile),
      last-occurrence: block-height
    })

    (ok true)
  )
)

;; Practice focus technique
(define-public (practice-focus-technique (technique (string-ascii 40)) (duration uint) (success-rate uint))
  (let (
    (user tx-sender)
    (technique-key {user: user, technique: technique})
    (existing-technique (map-get? focus-techniques technique-key))
  )
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (asserts! (<= success-rate u100) ERR-INVALID-INPUT)

    (match existing-technique
      tech (map-set focus-techniques technique-key (merge tech {
        effectiveness-rating: (/ (+ (get effectiveness-rating tech) success-rate) u2),
        usage-count: (+ (get usage-count tech) u1),
        success-rate: (/ (+ (get success-rate tech) success-rate) u2),
        preferred-duration: (/ (+ (get preferred-duration tech) duration) u2),
        last-used: block-height
      }))
      (map-set focus-techniques technique-key {
        effectiveness-rating: success-rate,
        usage-count: u1,
        success-rate: success-rate,
        preferred-duration: duration,
        last-used: block-height
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get user attention profile
(define-read-only (get-attention-profile (user principal))
  (map-get? user-attention-profiles user)
)

;; Get therapy session details
(define-read-only (get-therapy-session (session-id uint))
  (map-get? therapy-sessions session-id)
)

;; Get attention test results
(define-read-only (get-attention-test (test-id uint))
  (map-get? attention-tests test-id)
)

;; Get distraction pattern
(define-read-only (get-distraction-pattern (user principal) (pattern-type (string-ascii 30)))
  (map-get? distraction-patterns {user: user, pattern-type: pattern-type})
)

;; Get focus technique effectiveness
(define-read-only (get-focus-technique (user principal) (technique (string-ascii 40)))
  (map-get? focus-techniques {user: user, technique: technique})
)

;; Calculate attention improvement percentage
(define-read-only (calculate-improvement-percentage (user principal))
  (match (map-get? user-attention-profiles user)
    profile (let (
      (baseline (get baseline-span profile))
      (current (get current-span profile))
    )
      (ok (/ (* (- current baseline) u100) baseline))
    )
    (err ERR-USER-NOT-FOUND)
  )
)

;; Check if user needs therapy escalation
(define-read-only (needs-therapy-escalation (user principal))
  (match (map-get? user-attention-profiles user)
    profile (let (
      (current (get current-span profile))
      (baseline (get baseline-span profile))
      (sessions (get sessions-completed profile))
    )
      (and (< current baseline) (> sessions u10))
    )
    false
  )
)

;; Private Functions

;; Calculate session improvement score
(define-private (calculate-session-improvement (completion uint) (distractions uint) (breaks uint) (difficulty uint))
  (let (
    (base-score (* completion difficulty))
    (distraction-bonus (* distractions u5))
    (break-penalty (* breaks u2))
  )
    (if (> (+ base-score distraction-bonus) break-penalty)
      (- (+ base-score distraction-bonus) break-penalty)
      u0
    )
  )
)

;; Calculate attention span from test results
(define-private (calculate-attention-span (duration uint) (accuracy uint) (reaction-time uint))
  (let (
    (base-span duration)
    (accuracy-factor (/ accuracy u10))
    (speed-factor (/ u1000 reaction-time))
  )
    (+ base-span accuracy-factor speed-factor)
  )
)
