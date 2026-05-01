// Copyright 2025-2026 The MathWorks, Inc.

package directory_test

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager/matlabservices/services/localmatlabsession/directory"
	mocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/matlabmanager/matlabservices/services/localmatlabsession/directory"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDirectory_Cleanup_HappyPath(t *testing.T) {
	// Arrange
	mockOSLayer := &mocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	sessionDir := filepath.Join("tmp", "matlab-session-12345")

	mockConfig := &mocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockConfig.EXPECT().
		EmbeddedConnectorDetailsTimeout().
		Return(10 * time.Minute).
		Once()

	cleanupTimeout := 100 * time.Millisecond
	cleanupRetry := 10 * time.Millisecond

	dir := directory.NewDirectory(sessionDir, mockOSLayer, mockConfig)
	dir.SetCleanupTimeout(cleanupTimeout)
	dir.SetCleanupRetry(cleanupRetry)

	mockOSLayer.EXPECT().
		RemoveAll(sessionDir).
		Return(nil).
		Once()

	// Act
	err := dir.Cleanup()

	// Assert
	require.NoError(t, err)
}

func TestDirectory_Cleanup_WaitsForRemoveAllToPass(t *testing.T) {
	// Arrange
	mockOSLayer := &mocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	sessionDir := filepath.Join("tmp", "matlab-session-12345")

	mockConfig := &mocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockConfig.EXPECT().
		EmbeddedConnectorDetailsTimeout().
		Return(10 * time.Minute).
		Once()

	cleanupTimeout := 100 * time.Millisecond
	cleanupRetry := 10 * time.Millisecond

	dir := directory.NewDirectory(sessionDir, mockOSLayer, mockConfig)
	dir.SetCleanupTimeout(cleanupTimeout)
	dir.SetCleanupRetry(cleanupRetry)

	mockOSLayer.EXPECT().
		RemoveAll(sessionDir).
		Return(assert.AnError).
		Once()

	mockOSLayer.EXPECT().
		RemoveAll(sessionDir).
		Return(nil).
		Once()

	// Act
	err := dir.Cleanup()

	// Assert
	require.NoError(t, err)
}

func TestDirectory_Cleanup_Timesout(t *testing.T) {
	// Arrange
	mockOSLayer := &mocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	sessionDir := filepath.Join("tmp", "matlab-session-12345")

	mockConfig := &mocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockConfig.EXPECT().
		EmbeddedConnectorDetailsTimeout().
		Return(10 * time.Minute).
		Once()

	cleanupTimeout := 100 * time.Millisecond
	cleanupRetry := 10 * time.Millisecond

	dir := directory.NewDirectory(sessionDir, mockOSLayer, mockConfig)
	dir.SetCleanupTimeout(cleanupTimeout)
	dir.SetCleanupRetry(cleanupRetry)

	mockOSLayer.EXPECT().
		RemoveAll(sessionDir).
		Return(assert.AnError) // Will be called many times with retry

	// Act
	err := dir.Cleanup()

	// Assert
	require.Error(t, err)
}

func TestDirectory_Cleanup_EmptySessionDir(t *testing.T) {
	// Arrange
	mockOSLayer := &mocks.MockOSLayer{}
	defer mockOSLayer.AssertExpectations(t)

	mockConfig := &mocks.MockConfig{}
	defer mockConfig.AssertExpectations(t)

	mockConfig.EXPECT().
		EmbeddedConnectorDetailsTimeout().
		Return(10 * time.Minute).
		Once()

	cleanupTimeout := 100 * time.Millisecond
	cleanupRetry := 10 * time.Millisecond

	dir := directory.NewDirectory("", mockOSLayer, mockConfig)
	dir.SetCleanupTimeout(cleanupTimeout)
	dir.SetCleanupRetry(cleanupRetry)

	// Act
	err := dir.Cleanup()

	// Assert
	require.NoError(t, err)
}
