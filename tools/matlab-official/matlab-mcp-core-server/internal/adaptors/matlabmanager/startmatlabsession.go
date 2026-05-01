// Copyright 2025-2026 The MathWorks, Inc.

package matlabmanager

import (
	"context"
	"errors"
	"fmt"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager/matlabservices/datatypes"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager/matlabsessionclient/embeddedconnector"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/matlabmanager/matlabsessionstore"
	"github.com/matlab/matlab-mcp-core-server/internal/entities"
)

var (
	ErrNoMATLABSessionDiscovered = errors.New("no MATLAB session discovered")
)

func (m *MATLABManager) StartMATLABSession(ctx context.Context, sessionLogger entities.Logger, startRequest entities.SessionDetails) (entities.SessionID, error) {
	var zeroValue entities.SessionID
	var client matlabsessionstore.MATLABSessionClientWithCleanup

	switch request := startRequest.(type) {
	case entities.LocalSessionDetails:
		localSessionLogger := sessionLogger.With("matlab-root", request.MATLABRoot)
		// For now, we return embedded connector details, to decouple the session start logic from the client creation.
		embeddedConnectorEndpoint, sessionCleanup, err := m.matlabServices.StartLocalMATLABSession(
			ctx,
			localSessionLogger,
			datatypes.LocalSessionDetails{
				MATLABRoot:             request.MATLABRoot,
				IsStartingDirectorySet: request.IsStartingDirectorySet,
				StartingDirectory:      request.StartingDirectory,
				ShowMATLABDesktop:      request.ShowMATLABDesktop,
			},
		)
		if err != nil {
			return zeroValue, err
		}
		embeddedConnectorClient, err := m.clientFactory.New(embeddedConnectorEndpoint)
		if err != nil {
			return zeroValue, err
		}
		client = newMATLABSessionClientWithCleanup(embeddedConnectorClient, sessionCleanup)
	case entities.AttachToExistingSession:
		sessionLogger.Info("Attaching to existing session")
		config, messagesErr := m.configFactory.Config()
		if messagesErr != nil {
			return zeroValue, messagesErr
		}

		sessionDetails := config.MATLABSessionConnectionDetails()
		var connectionDetails embeddedconnector.ConnectionDetails

		if sessionDetails != "" {
			sessionLogger.Debug("Attaching to specified existing session")

			thisConnectionDetails, err := m.sessionDiscoverer.FromSessionDetails(sessionLogger, []byte(sessionDetails))
			if err != nil {
				return zeroValue, err
			}

			connectionDetails = thisConnectionDetails
		} else {
			sessionLogger.Debug("Discovering existing MATLAB sessions to attach to")

			discoveredSessions := m.sessionDiscoverer.DiscoverSessions(sessionLogger)
			if len(discoveredSessions) == 0 {
				return zeroValue, ErrNoMATLABSessionDiscovered
			}

			connectionDetails = discoveredSessions[0]
		}

		embeddedConnectorClient, err := m.clientFactory.New(connectionDetails)
		if err != nil {
			return zeroValue, err
		}

		// Check if the session is alive
		response := embeddedConnectorClient.Ping(ctx, sessionLogger)
		if !response.IsAlive {
			return zeroValue, ErrNoMATLABSessionDiscovered
		}

		client = newMATLABSessionClientWithoutCleanup(embeddedConnectorClient)
	default:
		return zeroValue, fmt.Errorf("unknown request type: %T", request)
	}

	return m.sessionStore.Add(client), nil
}
