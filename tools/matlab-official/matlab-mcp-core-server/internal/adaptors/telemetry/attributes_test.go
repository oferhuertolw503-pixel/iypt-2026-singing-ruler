// Copyright 2026 The MathWorks, Inc.

package telemetry_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/otel/attribute"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/telemetry"
)

func TestNewAttributes_HappyPath(t *testing.T) {
	// Act
	attrs := telemetry.NewAttributes()

	// Assert
	require.NotNil(t, attrs)
}

func TestAttributes_AddString_HappyPath(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "test-key"
	value := "test-value"

	// Act
	err := attrs.AddString(key, value)

	// Assert
	require.NoError(t, err)
	otelAttrs := attrs.AsOTEL()
	require.Len(t, otelAttrs, 1)
	assert.Equal(t, attribute.String(key, value), otelAttrs[0])
}

func TestAttributes_AddString_EmptyKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()

	// Act
	err := attrs.AddString("", "value")

	// Assert
	require.ErrorIs(t, err, telemetry.ErrEmptyKey)
}

func TestAttributes_AddString_DuplicateKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "duplicate-key"
	_ = attrs.AddString(key, "first-value")

	// Act
	err := attrs.AddString(key, "second-value")

	// Assert
	require.ErrorIs(t, err, telemetry.ErrDuplicateKey)
}

func TestAttributes_AddInt64_HappyPath(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "test-key"
	value := int64(42)

	// Act
	err := attrs.AddInt64(key, value)

	// Assert
	require.NoError(t, err)
	otelAttrs := attrs.AsOTEL()
	require.Len(t, otelAttrs, 1)
	assert.Equal(t, attribute.Int64(key, value), otelAttrs[0])
}

func TestAttributes_AddInt64_EmptyKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()

	// Act
	err := attrs.AddInt64("", 42)

	// Assert
	require.ErrorIs(t, err, telemetry.ErrEmptyKey)
}

func TestAttributes_AddInt64_DuplicateKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "duplicate-key"
	_ = attrs.AddInt64(key, 42)

	// Act
	err := attrs.AddInt64(key, 100)

	// Assert
	require.ErrorIs(t, err, telemetry.ErrDuplicateKey)
}

func TestAttributes_AddFloat64_HappyPath(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "test-key"
	value := 3.14

	// Act
	err := attrs.AddFloat64(key, value)

	// Assert
	require.NoError(t, err)
	otelAttrs := attrs.AsOTEL()
	require.Len(t, otelAttrs, 1)
	assert.Equal(t, attribute.Float64(key, value), otelAttrs[0])
}

func TestAttributes_AddFloat64_EmptyKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()

	// Act
	err := attrs.AddFloat64("", 3.14)

	// Assert
	require.ErrorIs(t, err, telemetry.ErrEmptyKey)
}

func TestAttributes_AddFloat64_DuplicateKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "duplicate-key"
	_ = attrs.AddFloat64(key, 3.14)

	// Act
	err := attrs.AddFloat64(key, 2.71)

	// Assert
	require.ErrorIs(t, err, telemetry.ErrDuplicateKey)
}

func TestAttributes_AddBool_HappyPath(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "test-key"
	value := true

	// Act
	err := attrs.AddBool(key, value)

	// Assert
	require.NoError(t, err)
	otelAttrs := attrs.AsOTEL()
	require.Len(t, otelAttrs, 1)
	assert.Equal(t, attribute.Bool(key, value), otelAttrs[0])
}

func TestAttributes_AddBool_EmptyKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()

	// Act
	err := attrs.AddBool("", true)

	// Assert
	require.ErrorIs(t, err, telemetry.ErrEmptyKey)
}

func TestAttributes_AddBool_DuplicateKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "duplicate-key"
	_ = attrs.AddBool(key, true)

	// Act
	err := attrs.AddBool(key, false)

	// Assert
	require.ErrorIs(t, err, telemetry.ErrDuplicateKey)
}

func TestAttributes_AddStringSlice_HappyPath(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "test-key"
	value := []string{"a", "b", "c"}

	// Act
	err := attrs.AddStringSlice(key, value)

	// Assert
	require.NoError(t, err)
	otelAttrs := attrs.AsOTEL()
	require.Len(t, otelAttrs, 1)
	assert.Equal(t, attribute.StringSlice(key, value), otelAttrs[0])
}

func TestAttributes_AddStringSlice_EmptyKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()

	// Act
	err := attrs.AddStringSlice("", []string{"a", "b"})

	// Assert
	require.ErrorIs(t, err, telemetry.ErrEmptyKey)
}

func TestAttributes_AddStringSlice_DuplicateKey(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	key := "duplicate-key"
	_ = attrs.AddStringSlice(key, []string{"a"})

	// Act
	err := attrs.AddStringSlice(key, []string{"b"})

	// Assert
	require.ErrorIs(t, err, telemetry.ErrDuplicateKey)
}

func TestAttributes_AsOTEL_HappyPath(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	expectedKey := "string-key"
	expectedValue := "string-value"
	_ = attrs.AddString(expectedKey, expectedValue)

	// Act
	otelAttrs := attrs.AsOTEL()

	// Assert
	require.Len(t, otelAttrs, 1)
	assert.Equal(t, attribute.String(expectedKey, expectedValue), otelAttrs[0])
}

func TestAttributes_AsOTEL_Empty(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()

	// Act
	otelAttrs := attrs.AsOTEL()

	// Assert
	require.NotNil(t, otelAttrs)
	assert.Empty(t, otelAttrs)
}

func TestAttributes_MultipleAttributes(t *testing.T) {
	// Arrange
	attrs := telemetry.NewAttributes()
	stringKey := "string-key"
	stringValue := "string-value"
	int64Key := "int64-key"
	int64Value := int64(42)
	float64Key := "float64-key"
	float64Value := 3.14
	boolKey := "bool-key"
	boolValue := true
	stringSliceKey := "string-slice-key"
	stringSliceValue := []string{"a", "b", "c"}

	// Act & Assert
	err := attrs.AddString(stringKey, stringValue)
	require.NoError(t, err)
	err = attrs.AddInt64(int64Key, int64Value)
	require.NoError(t, err)
	err = attrs.AddFloat64(float64Key, float64Value)
	require.NoError(t, err)
	err = attrs.AddBool(boolKey, boolValue)
	require.NoError(t, err)
	err = attrs.AddStringSlice(stringSliceKey, stringSliceValue)
	require.NoError(t, err)

	otelAttrs := attrs.AsOTEL()

	require.Len(t, otelAttrs, 5)
	assert.Equal(t, attribute.String(stringKey, stringValue), otelAttrs[0])
	assert.Equal(t, attribute.Int64(int64Key, int64Value), otelAttrs[1])
	assert.Equal(t, attribute.Float64(float64Key, float64Value), otelAttrs[2])
	assert.Equal(t, attribute.Bool(boolKey, boolValue), otelAttrs[3])
	assert.Equal(t, attribute.StringSlice(stringSliceKey, stringSliceValue), otelAttrs[4])
}
