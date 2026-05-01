// Copyright 2025-2026 The MathWorks, Inc.

package matlabmanager_test

import (
	"path/filepath"
	"testing"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager/matlabservices/datatypes"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager/matlabsessionclient/embeddedconnector"
	"github.com/matlab/matlab-mcp-core-server/internal/entities"
	"github.com/matlab/matlab-mcp-core-server/internal/messages"
	"github.com/matlab/matlab-mcp-core-server/internal/testutils"
	configmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/application/config"
	mocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/matlabmanager"
	entitiesmocks "github.com/matlab/matlab-mcp-core-server/mocks/entities"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

func TestMATLABManager_StartMATLABSession_HappyPath(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockSessionClient := &entitiesmocks.MockMATLABSessionClient{}
	expectedMATLABRoot := filepath.Join("path", "to", "matlab", "R2023a")
	expectedSessionID := entities.SessionID(123)

	connectionDetails := embeddedconnector.ConnectionDetails{
		Host: "localhost",
		Port: "1234",
	}

	sessionCleanupFunc := func() error { return nil }

	expectedLocalSessionDetails := datatypes.LocalSessionDetails{
		MATLABRoot:             expectedMATLABRoot,
		IsStartingDirectorySet: false,
	}

	expectedCtx := t.Context()

	mockMATLABServices.EXPECT().
		StartLocalMATLABSession(expectedCtx, mockLogger.AsMockArg(), expectedLocalSessionDetails).
		Return(connectionDetails, sessionCleanupFunc, nil).
		Once()

	mockClientFactory.EXPECT().
		New(connectionDetails).
		Return(mockSessionClient, nil).
		Once()

	mockSessionStore.EXPECT().
		Add(mock.AnythingOfType("*matlabmanager.matlabSessionClientWithCleanup")).
		Return(expectedSessionID).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	startRequest := entities.LocalSessionDetails{
		MATLABRoot:             expectedMATLABRoot,
		IsStartingDirectorySet: false,
	}

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, startRequest)

	// Assert
	require.NoError(t, err)
	assert.Equal(t, expectedSessionID, sessionID)
}

func TestMATLABManager_StartMATLABSession_MATLABServicesError(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	expectedMATLABRoot := filepath.Join("path", "to", "matlab", "R2023a")
	expectedError := assert.AnError

	expectedLocalSessionDetails := datatypes.LocalSessionDetails{
		MATLABRoot:             expectedMATLABRoot,
		IsStartingDirectorySet: false,
	}

	expectedCtx := t.Context()

	mockMATLABServices.EXPECT().
		StartLocalMATLABSession(expectedCtx, mockLogger.AsMockArg(), expectedLocalSessionDetails).
		Return(embeddedconnector.ConnectionDetails{}, nil, expectedError).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	startRequest := entities.LocalSessionDetails{
		MATLABRoot:             expectedMATLABRoot,
		IsStartingDirectorySet: false,
	}

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, startRequest)

	// Assert
	require.ErrorIs(t, err, expectedError)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_ClientFactoryError(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	expectedMATLABRoot := filepath.Join("path", "to", "matlab", "R2023a")
	connectionDetails := embeddedconnector.ConnectionDetails{
		Host: "localhost",
		Port: "12345",
	}
	sessionCleanupFunc := func() error { return nil }
	expectedError := assert.AnError

	expectedLocalSessionDetails := datatypes.LocalSessionDetails{
		MATLABRoot:             expectedMATLABRoot,
		IsStartingDirectorySet: false,
	}

	expectedCtx := t.Context()

	mockMATLABServices.EXPECT().
		StartLocalMATLABSession(expectedCtx, mockLogger.AsMockArg(), expectedLocalSessionDetails).
		Return(connectionDetails, sessionCleanupFunc, nil).
		Once()

	mockClientFactory.EXPECT().
		New(connectionDetails).
		Return(nil, expectedError).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	startRequest := entities.LocalSessionDetails{
		MATLABRoot:             expectedMATLABRoot,
		IsStartingDirectorySet: false,
	}

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, startRequest)

	// Assert
	require.ErrorIs(t, err, expectedError)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_HappyPath(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockSessionClient := &entitiesmocks.MockMATLABSessionClient{}
	defer mockSessionClient.AssertExpectations(t)

	expectedSessionID := entities.SessionID(42)

	expectedConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31515",
		APIKey:         "test-api-key",
		CertificatePEM: []byte("cert-content"),
	}

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return("").
		Once()

	mockSessionDiscoverer.EXPECT().
		DiscoverSessions(mockLogger.AsMockArg()).
		Return([]embeddedconnector.ConnectionDetails{expectedConnectionDetails}).
		Once()

	mockClientFactory.EXPECT().
		New(expectedConnectionDetails).
		Return(mockSessionClient, nil).
		Once()

	mockSessionClient.EXPECT().
		Ping(expectedCtx, mockLogger.AsMockArg()).
		Return(entities.PingResponse{IsAlive: true}).
		Once()

	mockSessionStore.EXPECT().
		Add(mock.AnythingOfType("*matlabmanager.matlabSessionClientWithoutCleanup")).
		Return(expectedSessionID).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.NoError(t, err)
	assert.Equal(t, expectedSessionID, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_WithProvidedDetails(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockSessionClient := &entitiesmocks.MockMATLABSessionClient{}
	defer mockSessionClient.AssertExpectations(t)

	expectedSessionID := entities.SessionID(42)

	sessionDetailsJSON := `{"port":31515,"certificate":"/path/to/cert.pem","apiKey":"test-api-key"}`
	expectedConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31515",
		APIKey:         "test-api-key",
		CertificatePEM: []byte("cert-content"),
	}

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return(sessionDetailsJSON).
		Once()

	mockSessionDiscoverer.EXPECT().
		FromSessionDetails(mockLogger.AsMockArg(), []byte(sessionDetailsJSON)).
		Return(expectedConnectionDetails, nil).
		Once()

	mockClientFactory.EXPECT().
		New(expectedConnectionDetails).
		Return(mockSessionClient, nil).
		Once()

	mockSessionClient.EXPECT().
		Ping(expectedCtx, mockLogger.AsMockArg()).
		Return(entities.PingResponse{IsAlive: true}).
		Once()

	mockSessionStore.EXPECT().
		Add(mock.AnythingOfType("*matlabmanager.matlabSessionClientWithoutCleanup")).
		Return(expectedSessionID).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.NoError(t, err)
	assert.Equal(t, expectedSessionID, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_ProvidedDetailsError(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	sessionDetailsJSON := `invalid json`
	expectedError := assert.AnError

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return(sessionDetailsJSON).
		Once()

	mockSessionDiscoverer.EXPECT().
		FromSessionDetails(mockLogger.AsMockArg(), []byte(sessionDetailsJSON)).
		Return(embeddedconnector.ConnectionDetails{}, expectedError).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.ErrorIs(t, err, expectedError)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_ConfigFactoryError(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(nil, messages.AnError).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.ErrorIs(t, err, messages.AnError)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_NoSessionsDiscovered(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return("").
		Once()

	mockSessionDiscoverer.EXPECT().
		DiscoverSessions(mockLogger.AsMockArg()).
		Return(nil).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.ErrorIs(t, err, matlabmanager.ErrNoMATLABSessionDiscovered)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_MultipleSessionsUsesFirst(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockSessionClient := &entitiesmocks.MockMATLABSessionClient{}
	defer mockSessionClient.AssertExpectations(t)

	expectedSessionID := entities.SessionID(100)

	firstConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31515",
		APIKey:         "first-api-key",
		CertificatePEM: []byte("first-cert"),
	}

	secondConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31516",
		APIKey:         "second-api-key",
		CertificatePEM: []byte("second-cert"),
	}

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return("").
		Once()

	mockSessionDiscoverer.EXPECT().
		DiscoverSessions(mockLogger.AsMockArg()).
		Return([]embeddedconnector.ConnectionDetails{firstConnectionDetails, secondConnectionDetails}).
		Once()

	mockClientFactory.EXPECT().
		New(firstConnectionDetails).
		Return(mockSessionClient, nil).
		Once()

	mockSessionClient.EXPECT().
		Ping(expectedCtx, mockLogger.AsMockArg()).
		Return(entities.PingResponse{IsAlive: true}).
		Once()

	mockSessionStore.EXPECT().
		Add(mock.AnythingOfType("*matlabmanager.matlabSessionClientWithoutCleanup")).
		Return(expectedSessionID).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.NoError(t, err)
	assert.Equal(t, expectedSessionID, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_ClientFactoryError(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	expectedConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31515",
		APIKey:         "key",
		CertificatePEM: []byte("cert"),
	}
	expectedError := assert.AnError

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return("").
		Once()

	mockSessionDiscoverer.EXPECT().
		DiscoverSessions(mockLogger.AsMockArg()).
		Return([]embeddedconnector.ConnectionDetails{expectedConnectionDetails}).
		Once()

	mockClientFactory.EXPECT().
		New(expectedConnectionDetails).
		Return(nil, expectedError).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.ErrorIs(t, err, expectedError)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_PingFailure(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockSessionClient := &entitiesmocks.MockMATLABSessionClient{}
	defer mockSessionClient.AssertExpectations(t)

	expectedConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31515",
		APIKey:         "test-api-key",
		CertificatePEM: []byte("cert-content"),
	}

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return("").
		Once()

	mockSessionDiscoverer.EXPECT().
		DiscoverSessions(mockLogger.AsMockArg()).
		Return([]embeddedconnector.ConnectionDetails{expectedConnectionDetails}).
		Once()

	mockClientFactory.EXPECT().
		New(expectedConnectionDetails).
		Return(mockSessionClient, nil).
		Once()

	mockSessionClient.EXPECT().
		Ping(expectedCtx, mockLogger.AsMockArg()).
		Return(entities.PingResponse{IsAlive: false}).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.ErrorIs(t, err, matlabmanager.ErrNoMATLABSessionDiscovered)
	assert.Empty(t, sessionID)
}

func TestMATLABManager_StartMATLABSession_AttachToExistingSession_WithProvidedDetails_PingFailure(t *testing.T) {
	// Arrange
	mockLogger := testutils.NewInspectableLogger()

	mockConfigFactory := &mocks.MockConfigFactory{}
	defer mockConfigFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMATLABServices := &mocks.MockMATLABServices{}
	defer mockMATLABServices.AssertExpectations(t)

	mockSessionStore := &mocks.MockMATLABSessionStore{}
	defer mockSessionStore.AssertExpectations(t)

	mockClientFactory := &mocks.MockMATLABSessionClientFactory{}
	defer mockClientFactory.AssertExpectations(t)

	mockSessionDiscoverer := &mocks.MockSessionDiscoverer{}
	defer mockSessionDiscoverer.AssertExpectations(t)

	mockSessionClient := &entitiesmocks.MockMATLABSessionClient{}
	defer mockSessionClient.AssertExpectations(t)

	sessionDetailsJSON := `{"port":31515,"certificate":"/path/to/cert.pem","apiKey":"test-api-key"}`
	expectedConnectionDetails := embeddedconnector.ConnectionDetails{
		Host:           "localhost",
		Port:           "31515",
		APIKey:         "test-api-key",
		CertificatePEM: []byte("cert-content"),
	}

	expectedCtx := t.Context()

	mockConfigFactory.EXPECT().
		Config().
		Return(mockConfig, nil).
		Once()

	mockConfig.EXPECT().
		MATLABSessionConnectionDetails().
		Return(sessionDetailsJSON).
		Once()

	mockSessionDiscoverer.EXPECT().
		FromSessionDetails(mockLogger.AsMockArg(), []byte(sessionDetailsJSON)).
		Return(expectedConnectionDetails, nil).
		Once()

	mockClientFactory.EXPECT().
		New(expectedConnectionDetails).
		Return(mockSessionClient, nil).
		Once()

	mockSessionClient.EXPECT().
		Ping(expectedCtx, mockLogger.AsMockArg()).
		Return(entities.PingResponse{IsAlive: false}).
		Once()

	manager := matlabmanager.New(mockConfigFactory, mockMATLABServices, mockSessionStore, mockClientFactory, mockSessionDiscoverer)

	// Act
	sessionID, err := manager.StartMATLABSession(expectedCtx, mockLogger, entities.AttachToExistingSession{})

	// Assert
	require.ErrorIs(t, err, matlabmanager.ErrNoMATLABSessionDiscovered)
	assert.Empty(t, sessionID)
}
