// Copyright 2026 The MathWorks, Inc.

package telemetry_test

import (
	"testing"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/telemetry"
	"github.com/matlab/matlab-mcp-core-server/internal/messages"
	"github.com/matlab/matlab-mcp-core-server/internal/testutils"
	configmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/application/config"
	telemetrymocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/telemetry"
	instrumentsmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/telemetry/otel/instruments"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric/noop"
)

func TestNewOTELTelemetry_HappyPath(t *testing.T) {
	// Arrange
	mockInstrumentFactory := &telemetrymocks.MockInstrumentFactory{}
	defer mockInstrumentFactory.AssertExpectations(t)

	mockInt64Counter := &instrumentsmocks.MockInt64Counter{}
	defer mockInt64Counter.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockOSLayer := &telemetrymocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockServerDefinition := &telemetrymocks.MockDefinition{}
	defer mockServerDefinition.AssertExpectations(t)

	mockOSVersionProvider := &telemetrymocks.MockOSVersionProvider{}
	defer mockOSVersionProvider.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	meter := noop.NewMeterProvider().Meter("test")

	mockInstrumentFactory.EXPECT().
		NewInt64Counter(meter, "server.starts", "Number of times the server has started", "{start}").
		Return(mockInt64Counter, nil).
		Once()

	// Act
	result, err := telemetry.NewOTELTelemetryForTesting(testLogger, meter, mockInstrumentFactory, mockConfig, nil, mockOSLayer, mockOSVersionProvider, mockServerDefinition)

	// Assert
	require.NoError(t, err)
	assert.NotNil(t, result)
}

func TestNewOTELTelemetry_InstrumentCreationFails(t *testing.T) {
	// Arrange
	mockInstrumentFactory := &telemetrymocks.MockInstrumentFactory{}
	defer mockInstrumentFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockOSLayer := &telemetrymocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockServerDefinition := &telemetrymocks.MockDefinition{}
	defer mockServerDefinition.AssertExpectations(t)

	mockOSVersionProvider := &telemetrymocks.MockOSVersionProvider{}
	defer mockOSVersionProvider.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	meter := noop.NewMeterProvider().Meter("test")
	instrumentError := assert.AnError
	expectedError := messages.New_StartupErrors_TelemetryInitializationFailed_Error()

	mockInstrumentFactory.EXPECT().
		NewInt64Counter(meter, "server.starts", "Number of times the server has started", "{start}").
		Return(nil, instrumentError).
		Once()

	// Act
	result, err := telemetry.NewOTELTelemetryForTesting(testLogger, meter, mockInstrumentFactory, mockConfig, nil, mockOSLayer, mockOSVersionProvider, mockServerDefinition)

	// Assert
	require.Nil(t, result)
	require.Equal(t, expectedError, err)
}

func TestOTELTelemetry_RecordServerStart_HappyPath(t *testing.T) {
	// Arrange
	mockInstrumentFactory := &telemetrymocks.MockInstrumentFactory{}
	defer mockInstrumentFactory.AssertExpectations(t)

	mockInt64Counter := &instrumentsmocks.MockInt64Counter{}
	defer mockInt64Counter.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockOSLayer := &telemetrymocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockServerDefinition := &telemetrymocks.MockDefinition{}
	defer mockServerDefinition.AssertExpectations(t)

	mockOSVersionProvider := &telemetrymocks.MockOSVersionProvider{}
	defer mockOSVersionProvider.AssertExpectations(t)

	mockDirectory := &telemetrymocks.MockDirectory{}
	defer mockDirectory.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	meter := noop.NewMeterProvider().Meter("test")

	expectedVersion := "v1.2.3"
	expectedName := "matlab-mcp-core-server"
	expectedOS := "linux"
	expectedSpecifiedParameters := []string{"disable-telemetry", "log-level"}
	expectedOSVersion := "Debian GNU/Linux 12"
	expectedInstanceID := "test-instance-id"
	expectedConfigDetails := `{"key":"value"}`

	expectedAttributes := []attribute.KeyValue{
		attribute.String("server.instance_id", expectedInstanceID),
		attribute.String("server.name", expectedName),
		attribute.String("server.version", expectedVersion),
		attribute.StringSlice("server.specified_parameters", expectedSpecifiedParameters),
		attribute.String("server.config_details", expectedConfigDetails),
		attribute.String("server.os", expectedOS),
		attribute.String("server.os_version", expectedOSVersion),
	}

	mockInstrumentFactory.EXPECT().
		NewInt64Counter(meter, "server.starts", "Number of times the server has started", "{start}").
		Return(mockInt64Counter, nil).
		Once()

	mockConfig.EXPECT().
		WatchdogMode().
		Return(false).
		Once()

	mockDirectory.EXPECT().
		ID().
		Return(expectedInstanceID).
		Once()

	mockServerDefinition.EXPECT().
		Name().
		Return(expectedName).
		Once()

	mockConfig.EXPECT().
		Version().
		Return(expectedVersion).
		Once()

	mockConfig.EXPECT().
		SpecifiedParameters().
		Return(expectedSpecifiedParameters).
		Once()

	mockConfig.EXPECT().
		AsPIISafeJSONString().
		Return(expectedConfigDetails).
		Once()

	mockOSLayer.EXPECT().
		GOOS().
		Return(expectedOS).
		Once()

	mockOSVersionProvider.EXPECT().
		Version().
		Return(expectedOSVersion, nil).
		Once()

	mockInt64Counter.EXPECT().
		Add(mock.Anything, int64(1), expectedAttributes).
		Once()

	otelTelemetry, err := telemetry.NewOTELTelemetryForTesting(testLogger, meter, mockInstrumentFactory, mockConfig, mockDirectory, mockOSLayer, mockOSVersionProvider, mockServerDefinition)
	require.NoError(t, err)

	// Act
	otelTelemetry.RecordServerStart(t.Context())

	// Assert
	// Assertions are verified via deferred mock expectations.
}

func TestOTELTelemetry_RecordServerStart_WatchdogModeSkips(t *testing.T) {
	// Arrange
	mockInstrumentFactory := &telemetrymocks.MockInstrumentFactory{}
	defer mockInstrumentFactory.AssertExpectations(t)

	mockInt64Counter := &instrumentsmocks.MockInt64Counter{}
	defer mockInt64Counter.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockOSLayer := &telemetrymocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockServerDefinition := &telemetrymocks.MockDefinition{}
	defer mockServerDefinition.AssertExpectations(t)

	mockOSVersionProvider := &telemetrymocks.MockOSVersionProvider{}
	defer mockOSVersionProvider.AssertExpectations(t)

	mockDirectory := &telemetrymocks.MockDirectory{}
	defer mockDirectory.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	meter := noop.NewMeterProvider().Meter("test")

	mockInstrumentFactory.EXPECT().
		NewInt64Counter(meter, "server.starts", "Number of times the server has started", "{start}").
		Return(mockInt64Counter, nil).
		Once()

	mockConfig.EXPECT().
		WatchdogMode().
		Return(true).
		Once()

	otelTelemetry, err := telemetry.NewOTELTelemetryForTesting(testLogger, meter, mockInstrumentFactory, mockConfig, mockDirectory, mockOSLayer, mockOSVersionProvider, mockServerDefinition)
	require.NoError(t, err)

	// Act
	otelTelemetry.RecordServerStart(t.Context())

	// Assert
	// No counter Add() call should occur - verified via deferred mock expectations.
}

func TestOTELTelemetry_RecordServerStart_OSVersionError(t *testing.T) {
	// Arrange
	mockInstrumentFactory := &telemetrymocks.MockInstrumentFactory{}
	defer mockInstrumentFactory.AssertExpectations(t)

	mockInt64Counter := &instrumentsmocks.MockInt64Counter{}
	defer mockInt64Counter.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockOSLayer := &telemetrymocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockServerDefinition := &telemetrymocks.MockDefinition{}
	defer mockServerDefinition.AssertExpectations(t)

	mockOSVersionProvider := &telemetrymocks.MockOSVersionProvider{}
	defer mockOSVersionProvider.AssertExpectations(t)

	mockDirectory := &telemetrymocks.MockDirectory{}
	defer mockDirectory.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	meter := noop.NewMeterProvider().Meter("test")

	expectedVersion := "v1.2.3"
	expectedName := "matlab-mcp-core-server"
	expectedOS := "linux"
	expectedSpecifiedParameters := []string{"disable-telemetry", "log-level"}
	expectedInstanceID := "test-instance-id"
	expectedConfigDetails := `{"key":"value"}`

	expectedAttributes := []attribute.KeyValue{
		attribute.String("server.instance_id", expectedInstanceID),
		attribute.String("server.name", expectedName),
		attribute.String("server.version", expectedVersion),
		attribute.StringSlice("server.specified_parameters", expectedSpecifiedParameters),
		attribute.String("server.config_details", expectedConfigDetails),
		attribute.String("server.os", expectedOS),
		attribute.String("server.os_version", ""),
	}

	mockInstrumentFactory.EXPECT().
		NewInt64Counter(meter, "server.starts", "Number of times the server has started", "{start}").
		Return(mockInt64Counter, nil).
		Once()

	mockConfig.EXPECT().
		WatchdogMode().
		Return(false).
		Once()

	mockDirectory.EXPECT().
		ID().
		Return(expectedInstanceID).
		Once()

	mockServerDefinition.EXPECT().
		Name().
		Return(expectedName).
		Once()

	mockConfig.EXPECT().
		Version().
		Return(expectedVersion).
		Once()

	mockConfig.EXPECT().
		SpecifiedParameters().
		Return(expectedSpecifiedParameters).
		Once()

	mockConfig.EXPECT().
		AsPIISafeJSONString().
		Return(expectedConfigDetails).
		Once()

	mockOSLayer.EXPECT().
		GOOS().
		Return(expectedOS).
		Once()

	mockOSVersionProvider.EXPECT().
		Version().
		Return("", assert.AnError).
		Once()

	mockInt64Counter.EXPECT().
		Add(mock.Anything, int64(1), expectedAttributes).
		Once()

	otelTelemetry, err := telemetry.NewOTELTelemetryForTesting(testLogger, meter, mockInstrumentFactory, mockConfig, mockDirectory, mockOSLayer, mockOSVersionProvider, mockServerDefinition)
	require.NoError(t, err)

	// Act
	otelTelemetry.RecordServerStart(t.Context())

	// Assert
	// Assertions are verified via deferred mock expectations.
}
