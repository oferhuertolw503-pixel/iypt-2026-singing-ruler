// Copyright 2026 The MathWorks, Inc.

package tools_test

import (
	"testing"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/sdk/tools"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewReadOnlyAnnotations_HappyPath(t *testing.T) {
	// Act
	annotations := tools.NewReadOnlyAnnotations()

	// Assert
	require.IsType(t, tools.ReadOnlyAnnotation{}, annotations)

	result := annotations.ToToolAnnotations()
	require.NotNil(t, result)
	assert.True(t, result.ReadOnlyHint)
	require.NotNil(t, result.DestructiveHint)
	assert.False(t, *result.DestructiveHint)
	assert.False(t, result.IdempotentHint)
	require.NotNil(t, result.OpenWorldHint)
	assert.False(t, *result.OpenWorldHint)
}
