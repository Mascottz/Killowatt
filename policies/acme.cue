package killowatt

// the acme production account.
acme: #Policy & {
	account: "acme-prod"

	daily_limit_cents:  250_00 // $250.00 a day
	hourly_limit_cents: 60_00  // $60.00 an hour

	burst: {
		window_seconds: 600
		limit_cents:    40_00 // $40.00 in any 10 minutes; retry storms land here first
	}

	action: "hard_stop"

	exempt: ["rds-prod-backups"]
}
