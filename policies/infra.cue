package killowatt

// the shared platform account; slower money, looser ceiling, throttle
// instead of hard stop.
infra: #Policy & {
	account: "infra-core"

	daily_limit_cents:  500_00  // $500.00 a day
	hourly_limit_cents: 120_00  // $120.00 an hour

	burst: {
		window_seconds: 600
		limit_cents:    80_00 // $80.00 in any 10 minutes
	}

	action: "throttle"

	exempt: []
}
