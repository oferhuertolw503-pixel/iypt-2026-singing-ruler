// Copyright 2026 The MathWorks, Inc.

package retry

import (
	"time"
)

const defaultLinearRetryInterval = 100 * time.Millisecond

type linearRetryStrategy struct {
	retryInterval time.Duration
}

func NewLinearRetryStrategy(retryInterval time.Duration) RetryStrategy {
	if retryInterval <= 0 {
		retryInterval = defaultLinearRetryInterval
	}

	return &linearRetryStrategy{
		retryInterval: retryInterval,
	}
}

func (l *linearRetryStrategy) C() <-chan time.Time {
	return time.Tick(l.retryInterval)
}

func (l *linearRetryStrategy) lock() {}
