// Copyright 2026 The MathWorks, Inc.

package functional_test

import (
	"os"
	"path/filepath"

	"github.com/matlab/matlab-mcp-core-server/tests/testutils/facades/filefacade"
	"github.com/matlab/matlab-mcp-core-server/tests/testutils/logs"
	"github.com/matlab/matlab-mcp-core-server/tests/testutils/mcpclient"
	"github.com/matlab/matlab-mcp-core-server/tests/testutils/mcpserver"
	"github.com/matlab/matlab-mcp-core-server/tests/testutils/mockmatlab"
	"github.com/matlab/matlab-mcp-core-server/tests/testutils/pathcontrol"
	"github.com/matlab/matlab-mcp-core-server/tests/testutils/serverlogs"
	"github.com/stretchr/testify/suite"
)

type MockMATLABTestSuite struct {
	suite.Suite
	mcpServerPath  string
	installation   *mockmatlab.Installation
	defaultEnv     []string
	sessionFactory *mcpclient.LoggedSessionFactory
}

func (s *MockMATLABTestSuite) SetupSuite() {
	s.installation = mockmatlab.BuildAndInstall(s.T())

	mcpServerPath, err := mcpserver.NewLocator().GetPath()
	s.Require().NoError(err, "MCP server binary not found — run 'make build' first")
	s.mcpServerPath = mcpServerPath

	mockMATLABBinDir := filepath.Join(s.installation.MATLABRoot, "bin")
	path := pathcontrol.RemoveAllMATLABsFromPath(os.Getenv("PATH"))
	path = pathcontrol.AddToPath(path, []string{mockMATLABBinDir})

	env := pathcontrol.UpdateEnvEntry(os.Environ(), "PATH", path)
	env = pathcontrol.UpdateEnvEntry(env, "MW_MCP_SERVER_EMBEDDED_CONNECTOR_DETAILS_TIMEOUT", "10s")

	s.defaultEnv = env
	sessionFactory, err := mcpclient.NewLoggedSessionFactory(logs.NewReader(), filefacade.RealFileSystem{})
	s.Require().NoError(err)
	s.sessionFactory = sessionFactory
}

// CreateSession creates a mock MATLAB session with debug logging enabled.
// Additional CLI args (e.g. "--extension-file=...") are forwarded to the server.
// Usage:
//
//	session, err := s.CreateSession(mockmatlab.HappyConfig())
//	s.Require().NoError(err)
//	defer s.CleanupSession(session, true)
func (s *MockMATLABTestSuite) CreateSession(cfg mockmatlab.Config, args ...string) (*mcpclient.LoggedSession, error) {
	ctx := s.T().Context()

	value, err := cfg.ToEnvValue()
	s.Require().NoError(err, "failed to serialize mock config")
	env := pathcontrol.UpdateEnvEntry(s.defaultEnv, mockmatlab.EnvMockMATLABConfig, value)

	preparedArgs, err := logs.PrepareSessionCLIArgs(args, "debug", "mcp-functional-logs-")
	s.Require().NoError(err, "should prepare log args")
	s.T().Cleanup(func() {
		s.NoError(os.RemoveAll(preparedArgs.TempBaseDir), "should remove log temp dir")
	})

	client := mcpclient.NewClient(ctx, s.mcpServerPath, env, preparedArgs.Args...)
	session, err := client.CreateSession(ctx)
	if err != nil {
		return nil, err
	}

	loggedSession, err := s.sessionFactory.New(
		session,
		preparedArgs.LogDir,
		"MCP Server Logs (stderr)",
		[]logs.DumpPattern{
			{Glob: "server-*.log", Header: "MCP Server Log File"},
			{Glob: "watchdog-*.log", Header: "MCP Watchdog Log File"},
		},
	)
	if err != nil {
		return nil, err
	}

	return loggedSession, nil
}

// AssertNoErrorLogs checks server log files for ERROR-level entries.
// Use assert (not require) so deferred cleanup continues if this fails.
func (s *MockMATLABTestSuite) AssertNoErrorLogs(session *mcpclient.LoggedSession) {
	errorLogs, err := serverlogs.ReadErrorLogs(session.LogFS())
	s.NoError(err) //nolint:testifylint // assert in defer to avoid FailNow
	s.Empty(errorLogs, "unexpected ERROR logs in server logs")
}

func (s *MockMATLABTestSuite) CleanupSession(session *mcpclient.LoggedSession, assertNoErrorLogs bool) {
	s.T().Helper()
	if err := session.Close(); err != nil {
		s.T().Logf("Ignoring session.Close() error (MCP go-sdk shutdown race): %v", err)
	}
	if assertNoErrorLogs {
		s.AssertNoErrorLogs(session)
	}
	session.DumpLogsOnFailure(s.T())
}
