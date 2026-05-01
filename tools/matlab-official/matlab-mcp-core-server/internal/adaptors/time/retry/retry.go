// Copyright 2026 The MathWorks, Inc.

package retry

import (
	"context"
	"errors"
	"time"
)

var (
	ErrInvalidRetryStrategy = errors.New("invalid retry strategy")
)

type RetryStrategy interface {
	C() <-chan time.Time
	lock() // unexported to prevent external implementations; add new strategies to this package
}

// Retry repeatedly calls fn using the given retry strategy until one of the following conditions is met:
//   - fn returns a non-nil error: stop immediately and return the error.
//   - fn returns (output, true, nil): stop retrying and return output.
//   - fn returns (_, false, nil): keep retrying.
//   - ctx is canceled: stop and return ctx.Err() (or context.Cause if set).
func Retry[OutputType any](ctx context.Context, fn func() (OutputType, bool, error), retryStrategy RetryStrategy) (OutputType, error) {
	var zeroValue OutputType

	if retryStrategy == nil {
		return zeroValue, ErrInvalidRetryStrategy
	}

	if err := context.Cause(ctx); err != nil {
		return zeroValue, err
	}

	retryC := retryStrategy.C()

	for {
		output, ok, err := fn()
		if err != nil {
			return zeroValue, err
		}

		if ok {
			return output, nil
		}

		select {
		case <-retryC:
			// Try again
		case <-ctx.Done():
			return zeroValue, context.Cause(ctx)
		}
	}
}
