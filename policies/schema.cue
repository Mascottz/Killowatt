package killowatt

// a spend policy. money is integer cents everywhere; floats never touch money.
#Policy: {
	account: string

	// hard ceilings
	daily_limit_cents:  int & >0
	hourly_limit_cents: int & >0 & <=daily_limit_cents

	// the loop catcher; a runaway shows up here first
	burst: {
		window_seconds: int & >=1
		limit_cents:    int & >0
	}

	// what a trip does
	action: *"hard_stop" | "throttle" | "alert_only"

	// recorded, but never counted against limits
	exempt: [...string]
}
