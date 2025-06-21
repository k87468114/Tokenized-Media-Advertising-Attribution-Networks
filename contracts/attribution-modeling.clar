;; Attribution Modeling Contract v1
;; Handles multi-touch attribution across advertising touchpoints

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_TOUCHPOINT (err u301))
(define-constant ERR_INVALID_WEIGHT (err u302))
(define-constant ERR_ATTRIBUTION_NOT_FOUND (err u303))

;; Attribution model types
(define-constant MODEL_FIRST_TOUCH u1)
(define-constant MODEL_LAST_TOUCH u2)
(define-constant MODEL_LINEAR u3)
(define-constant MODEL_TIME_DECAY u4)
(define-constant MODEL_POSITION_BASED u5)

;; Data structures
(define-map touchpoints
  { touchpoint-id: uint }
  {
    campaign-id: uint,
    user-id: (string-ascii 100),
    channel: (string-ascii 50),
    timestamp: uint,
    interaction-type: (string-ascii 50),
    value: uint
  }
)

(define-map attribution-weights
  { campaign-id: uint, model-type: uint }
  {
    first-touch-weight: uint,
    last-touch-weight: uint,
    middle-touch-weight: uint,
    decay-factor: uint
  }
)

(define-map user-journeys
  { user-id: (string-ascii 100), campaign-id: uint }
  {
    touchpoint-count: uint,
    first-touchpoint: uint,
    last-touchpoint: uint,
    total-value: uint,
    conversion-value: uint
  }
)

(define-data-var next-touchpoint-id uint u1)

;; Public functions
(define-public (record-touchpoint
  (campaign-id uint)
  (user-id (string-ascii 100))
  (channel (string-ascii 50))
  (interaction-type (string-ascii 50))
  (value uint)
)
  (let ((touchpoint-id (var-get next-touchpoint-id)))
    (map-set touchpoints
      { touchpoint-id: touchpoint-id }
      {
        campaign-id: campaign-id,
        user-id: user-id,
        channel: channel,
        timestamp: block-height,
        interaction-type: interaction-type,
        value: value
      }
    )

    ;; Update user journey
    (match (map-get? user-journeys { user-id: user-id, campaign-id: campaign-id })
      journey-data
      (map-set user-journeys
        { user-id: user-id, campaign-id: campaign-id }
        {
          touchpoint-count: (+ (get touchpoint-count journey-data) u1),
          first-touchpoint: (get first-touchpoint journey-data),
          last-touchpoint: touchpoint-id,
          total-value: (+ (get total-value journey-data) value),
          conversion-value: (get conversion-value journey-data)
        }
      )
      (map-set user-journeys
        { user-id: user-id, campaign-id: campaign-id }
        {
          touchpoint-count: u1,
          first-touchpoint: touchpoint-id,
          last-touchpoint: touchpoint-id,
          total-value: value,
          conversion-value: u0
        }
      )
    )

    (var-set next-touchpoint-id (+ touchpoint-id u1))
    (ok touchpoint-id)
  )
)

(define-public (set-attribution-weights
  (campaign-id uint)
  (model-type uint)
  (first-weight uint)
  (last-weight uint)
  (middle-weight uint)
  (decay-factor uint)
)
  (begin
    (asserts! (<= (+ first-weight last-weight middle-weight) u10000) ERR_INVALID_WEIGHT)
    (map-set attribution-weights
      { campaign-id: campaign-id, model-type: model-type }
      {
        first-touch-weight: first-weight,
        last-touch-weight: last-weight,
        middle-touch-weight: middle-weight,
        decay-factor: decay-factor
      }
    )
    (ok true)
  )
)

(define-public (record-conversion
  (user-id (string-ascii 100))
  (campaign-id uint)
  (conversion-value uint)
)
  (match (map-get? user-journeys { user-id: user-id, campaign-id: campaign-id })
    journey-data
    (begin
      (map-set user-journeys
        { user-id: user-id, campaign-id: campaign-id }
        (merge journey-data { conversion-value: conversion-value })
      )
      (ok true)
    )
    ERR_ATTRIBUTION_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-touchpoint (touchpoint-id uint))
  (map-get? touchpoints { touchpoint-id: touchpoint-id })
)

(define-read-only (get-user-journey (user-id (string-ascii 100)) (campaign-id uint))
  (map-get? user-journeys { user-id: user-id, campaign-id: campaign-id })
)

(define-read-only (get-attribution-weights (campaign-id uint) (model-type uint))
  (map-get? attribution-weights { campaign-id: campaign-id, model-type: model-type })
)

(define-read-only (calculate-first-touch-attribution (user-id (string-ascii 100)) (campaign-id uint))
  (match (map-get? user-journeys { user-id: user-id, campaign-id: campaign-id })
    journey-data (get conversion-value journey-data)
    u0
  )
)

(define-read-only (calculate-last-touch-attribution (user-id (string-ascii 100)) (campaign-id uint))
  (match (map-get? user-journeys { user-id: user-id, campaign-id: campaign-id })
    journey-data (get conversion-value journey-data)
    u0
  )
)

(define-read-only (calculate-linear-attribution (user-id (string-ascii 100)) (campaign-id uint))
  (match (map-get? user-journeys { user-id: user-id, campaign-id: campaign-id })
    journey-data
    (if (> (get touchpoint-count journey-data) u0)
      (/ (get conversion-value journey-data) (get touchpoint-count journey-data))
      u0
    )
    u0
  )
)

(define-read-only (get-total-touchpoints)
  (var-get next-touchpoint-id)
)
