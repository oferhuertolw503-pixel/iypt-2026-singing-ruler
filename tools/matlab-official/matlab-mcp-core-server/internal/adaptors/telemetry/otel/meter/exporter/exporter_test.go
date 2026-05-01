// Copyright 2026 The MathWorks, Inc.

package exporter_test

import (
	"testing"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/telemetry/otel/meter/exporter"
	"github.com/matlab/matlab-mcp-core-server/internal/messages"
	"github.com/matlab/matlab-mcp-core-server/internal/testutils"
	configmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/application/config"
	exportermocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/telemetry/otel/meter/exporter"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewFactory_HappyPath(t *testing.T) {
	// Arrange
	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	// Act
	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Assert
	assert.NotNil(t, factory, "Factory should not be nil")
}

func TestFactory_New_HappyPath(t *testing.T) {
	// Arrange
	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	expectedEndpoint := "localhost:4317"

	mockLoggerFactory.EXPECT().
		GetGlobalLogger().
		Return(testLogger, nil).
		Once()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_ENDPOINT").
		Return("", false).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT").
		Return("", false).
		Once()

	mockConfig.EXPECT().
		TelemetryCollectorEndpoint().
		Return(expectedEndpoint).
		Once()

	mockConfig.EXPECT().
		TelemetryCollectorEndpointInsecure().
		Return(false).
		Once()

	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Act
	result, err := factory.New()

	// Assert
	require.NoError(t, err)
	require.NotNil(t, result)
}

func TestFactory_New_LoggerError(t *testing.T) {
	// Arrange
	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	expectedError := messages.AnError

	mockLoggerFactory.EXPECT().
		GetGlobalLogger().
		Return(nil, expectedError).
		Once()

	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Act
	result, err := factory.New()

	// Assert
	require.Nil(t, result)
	require.ErrorIs(t, err, expectedError)
}

func TestFactory_New_ConfigError(t *testing.T) {
	// Arrange
	testLogger := testutils.NewInspectableLogger()

	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	expectedError := messages.AnError

	mockLoggerFactory.EXPECT().
		GetGlobalLogger().
		Return(testLogger, nil).
		Once()

	mockConfigFactory.EXPECT().
		Config().
		Return(nil, expectedError).
		Once()

	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Act
	result, err := factory.New()

	// Assert
	require.Nil(t, result, "Exporter should be nil when config fails")
	require.ErrorIs(t, err, expectedError)
}

func TestFactory_New_InsecureEndpoint(t *testing.T) {
	// Arrange
	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()
	expectedEndpoint := "localhost:4317"

	mockLoggerFactory.EXPECT().
		GetGlobalLogger().
		Return(testLogger, nil).
		Once()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_ENDPOINT").
		Return("", false).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT").
		Return("", false).
		Once()

	mockConfig.EXPECT().
		TelemetryCollectorEndpoint().
		Return(expectedEndpoint).
		Once()

	mockConfig.EXPECT().
		TelemetryCollectorEndpointInsecure().
		Return(true).
		Once()

	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Act
	result, err := factory.New()

	// Assert
	require.NoError(t, err)
	require.NotNil(t, result)
}

func TestFactory_New_OTELEndpointEnvVarSet(t *testing.T) {
	// Arrange
	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()

	mockLoggerFactory.EXPECT().
		GetGlobalLogger().
		Return(testLogger, nil).
		Once()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_ENDPOINT").
		Return("http://env-endpoint:4318", true).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT").
		Return("", false).
		Once()

	mockConfig.EXPECT().
		TelemetryCollectorEndpointInsecure().
		Return(false).
		Once()

	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Act
	result, err := factory.New()

	// Assert
	require.NoError(t, err)
	require.NotNil(t, result)
}

func TestFactory_New_OTELMetricsEndpointEnvVarSet(t *testing.T) {
	// Arrange
	mockLoggerFactory := &exportermocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfigFactory := &exportermocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockOSLayer := &exportermocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	testLogger := testutils.NewInspectableLogger()

	mockLoggerFactory.EXPECT().
		GetGlobalLogger().
		Return(testLogger, nil).
		Once()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_ENDPOINT").
		Return("", false).
		Once()

	mockOSLayer.EXPECT().
		LookupEnv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT").
		Return("http://metrics-endpoint:4318", true).
		Once()

	mockConfig.EXPECT().
		TelemetryCollectorEndpointInsecure().
		Return(false).
		Once()

	factory := exporter.NewFactory(mockLoggerFactory, mockConfigFactory, mockOSLayer)

	// Act
	result, err := factory.New()

	// Assert
	require.NoError(t, err)
	require.NotNil(t, result)
}
