// Copyright 2026 The MathWorks, Inc.

package retry_test

import (
	"testing"
	"testing/synctest"
	"time"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/time/retry"
	"github.com/stretchr/testify/assert"
)

func TestNewLinearRetryStrategy_ReturnsNonNilStrategy(t *testing.T) {
	// Arrange
	retryInterval := 10 * time.Millisecond

	// Act
	strategy := retry.NewLinearRetryStrategy(retryInterval)

	// Assert
	assert.NotNil(t, strategy)
}

func TestLinearRetryStrategy_C_ReturnsChannel(t *testing.T) {
	// Arrange
	retryInterval := 10 * time.Millisecond
	strategy := retry.NewLinearRetryStrategy(retryInterval)

	// Act
	ch := strategy.C()

	// Assert
	assert.NotNil(t, ch)
}

func TestLinearRetryStrategy_C_TicksAtInterval(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		// Arrange
		retryInterval := 50 * time.Millisecond
		strategy := retry.NewLinearRetryStrategy(retryInterval)
		ch := strategy.C()

		// Assert: not ready before interval
		time.Sleep(retryInterval - time.Nanosecond)
		synctest.Wait()
		select {
		case <-ch:
			t.Fatal("channel ticked before interval elapsed")
		default:
		}

		// Assert: ready after interval
		time.Sleep(time.Nanosecond)
		synctest.Wait()
		select {
		case <-ch:
		default:
			t.Fatal("channel did not tick after interval elapsed")
		}
	})
}

func TestNewLinearRetryStrategy_UsesDefaultForNegativeDuration(t *testing.T) {
	// Arrange
	negativeDuration := -10 * time.Millisecond

	// Act
	strategy := retry.NewLinearRetryStrategy(negativeDuration)

	// Assert
	assert.NotNil(t, strategy)
	assert.NotNil(t, strategy.C())
}

func TestLinearRetryStrategy_CanBeReusedConcurrently(t *testing.T) {
	// Arrange
	retryInterval := 10 * time.Millisecond
	strategy := retry.NewLinearRetryStrategy(retryInterval)

	// Act
	ch1 := strategy.C()
	ch2 := strategy.C()

	// Assert
	assert.NotNil(t, ch1)
	assert.NotNil(t, ch2)
	assert.NotEqual(t, ch1, ch2, "each call to C() should return a new channel")
}
