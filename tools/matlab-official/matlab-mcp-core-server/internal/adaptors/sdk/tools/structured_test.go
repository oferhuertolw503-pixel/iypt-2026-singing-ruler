// Copyright 2026 The MathWorks, Inc.

package tools_test

import (
	"context"
	"testing"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/mcp/tools/basetool"
	publictypes "github.com/matlab/matlab-mcp-core-server/internal/adaptors/sdk/publictypes"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/sdk/tools"
	"github.com/matlab/matlab-mcp-core-server/internal/testutils"
	configmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/application/config"
	definitionmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/application/definition"
	basetoolmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/mcp/tools/basetool"
	publictypesmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/sdk/publictypes"
	toolsmocks "github.com/matlab/matlab-mcp-core-server/mocks/adaptors/sdk/tools"
	"github.com/modelcontextprotocol/go-sdk/mcp"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewStructured_HappyPath(t *testing.T) {
	// Arrange
	mockLoggerFactory := &basetoolmocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockGenericConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMessageCatalog := &definitionmocks.MockMessageCatalog{}
	defer mockMessageCatalog.AssertExpectations(t)

	mockToolCallRequestFactory := &toolsmocks.MockToolCallRequestFactory{}
	defer mockToolCallRequestFactory.AssertExpectations(t)

	mockCallRequest := &publictypesmocks.MockToolCallRequest{}
	defer mockCallRequest.AssertExpectations(t)

	mockLogger := testutils.NewInspectableLogger()

	expectedSession := &mcp.ServerSession{}
	expectedInput := structuredToolInput{Query: "test query"}
	expectedOutput := structuredToolOutput{Result: "success"}

	mockLoggerFactory.EXPECT().
		NewMCPSessionLogger(expectedSession).
		Return(mockLogger, nil).
		Once()

	mockToolCallRequestFactory.EXPECT().
		New(mockLogger.AsMockArg(), mockConfig, mockMessageCatalog).
		Return(mockCallRequest).
		Once()

	tool := tools.NewStructured(
		publictypes.ToolDefinition{Name: "test-tool"},
		func(ctx context.Context, request publictypes.ToolCallRequest, input structuredToolInput) (structuredToolOutput, publictypes.Error) {
			assert.Equal(t, expectedInput, input)
			assert.Equal(t, mockCallRequest, request)
			return expectedOutput, nil
		},
	)

	internalTool := tool.ToInternal(mockToolCallRequestFactory, mockLoggerFactory, mockConfig, mockMessageCatalog).(basetool.ToolWithStructuredContentOutput[structuredToolInput, structuredToolOutput])

	mcpCallToolRequest := &mcp.CallToolRequest{
		Session: expectedSession,
	}

	// Act
	_, output, err := internalTool.Handler()(t.Context(), mcpCallToolRequest, expectedInput)

	// Assert
	require.NoError(t, err)
	assert.Equal(t, expectedOutput, output)
}

func TestNewStructured_HandlerError(t *testing.T) {
	// Arrange
	mockLoggerFactory := &basetoolmocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockGenericConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMessageCatalog := &definitionmocks.MockMessageCatalog{}
	defer mockMessageCatalog.AssertExpectations(t)

	mockToolCallRequestFactory := &toolsmocks.MockToolCallRequestFactory{}
	defer mockToolCallRequestFactory.AssertExpectations(t)

	mockCallRequest := &publictypesmocks.MockToolCallRequest{}
	defer mockCallRequest.AssertExpectations(t)

	mockLogger := testutils.NewInspectableLogger()

	expectedSession := &mcp.ServerSession{}
	expectedError := anI18nError

	mockLoggerFactory.EXPECT().
		NewMCPSessionLogger(expectedSession).
		Return(mockLogger, nil).
		Once()

	mockToolCallRequestFactory.EXPECT().
		New(mockLogger.AsMockArg(), mockConfig, mockMessageCatalog).
		Return(mockCallRequest).
		Once()

	tool := tools.NewStructured(
		publictypes.ToolDefinition{Name: "test-tool"},
		func(ctx context.Context, request publictypes.ToolCallRequest, input structuredToolInput) (structuredToolOutput, publictypes.Error) {
			return structuredToolOutput{}, expectedError
		},
	)

	internalTool := tool.ToInternal(mockToolCallRequestFactory, mockLoggerFactory, mockConfig, mockMessageCatalog).(basetool.ToolWithStructuredContentOutput[structuredToolInput, structuredToolOutput])

	mcpCallToolRequest := &mcp.CallToolRequest{
		Session: expectedSession,
	}

	// Act
	_, output, err := internalTool.Handler()(t.Context(), mcpCallToolRequest, structuredToolInput{})

	// Assert
	require.ErrorIs(t, err, expectedError)
	assert.Equal(t, structuredToolOutput{}, output)
}

func TestNewStructured_HandlerReceivesLogger(t *testing.T) {
	// Arrange
	mockLoggerFactory := &basetoolmocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockGenericConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMessageCatalog := &definitionmocks.MockMessageCatalog{}
	defer mockMessageCatalog.AssertExpectations(t)

	mockToolCallRequestFactory := &toolsmocks.MockToolCallRequestFactory{}
	defer mockToolCallRequestFactory.AssertExpectations(t)

	mockCallRequest := &publictypesmocks.MockToolCallRequest{}
	defer mockCallRequest.AssertExpectations(t)

	mockPkgLogger := &publictypesmocks.MockLogger{}
	defer mockPkgLogger.AssertExpectations(t)

	mockLogger := testutils.NewInspectableLogger()

	expectedSession := &mcp.ServerSession{}
	expectedMessage := "handler received logger"

	mockLoggerFactory.EXPECT().
		NewMCPSessionLogger(expectedSession).
		Return(mockLogger, nil).
		Once()

	mockToolCallRequestFactory.EXPECT().
		New(mockLogger.AsMockArg(), mockConfig, mockMessageCatalog).
		Return(mockCallRequest).
		Once()

	mockCallRequest.EXPECT().
		Logger().
		Return(mockPkgLogger).
		Once()

	mockPkgLogger.EXPECT().
		Info(expectedMessage).
		Return().
		Once()

	tool := tools.NewStructured(
		publictypes.ToolDefinition{Name: "test-tool"},
		func(ctx context.Context, request publictypes.ToolCallRequest, input structuredToolInput) (structuredToolOutput, publictypes.Error) {
			request.Logger().Info(expectedMessage)
			return structuredToolOutput{}, nil
		},
	)

	internalTool := tool.ToInternal(mockToolCallRequestFactory, mockLoggerFactory, mockConfig, mockMessageCatalog).(basetool.ToolWithStructuredContentOutput[structuredToolInput, structuredToolOutput])

	mcpCallToolRequest := &mcp.CallToolRequest{
		Session: expectedSession,
	}

	// Act
	_, _, err := internalTool.Handler()(t.Context(), mcpCallToolRequest, structuredToolInput{Query: "test"})

	// Assert
	require.NoError(t, err)
	// Assertions are verified via deferred mock expectations.
}

func TestNewStructured_HandlerReceivesConfig(t *testing.T) {
	// Arrange
	mockLoggerFactory := &basetoolmocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockGenericConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMessageCatalog := &definitionmocks.MockMessageCatalog{}
	defer mockMessageCatalog.AssertExpectations(t)

	mockToolCallRequestFactory := &toolsmocks.MockToolCallRequestFactory{}
	defer mockToolCallRequestFactory.AssertExpectations(t)

	mockCallRequest := &publictypesmocks.MockToolCallRequest{}
	defer mockCallRequest.AssertExpectations(t)

	mockPkgConfig := &publictypesmocks.MockConfig{}
	defer mockPkgConfig.AssertExpectations(t)

	mockLogger := testutils.NewInspectableLogger()

	expectedSession := &mcp.ServerSession{}
	expectedKey := "test-key"
	expectedValue := "test-value"

	mockLoggerFactory.EXPECT().
		NewMCPSessionLogger(expectedSession).
		Return(mockLogger, nil).
		Once()

	mockToolCallRequestFactory.EXPECT().
		New(mockLogger.AsMockArg(), mockConfig, mockMessageCatalog).
		Return(mockCallRequest).
		Once()

	mockCallRequest.EXPECT().
		Config().
		Return(mockPkgConfig).
		Once()

	mockPkgConfig.EXPECT().
		Get(expectedKey, "").
		Return(expectedValue, nil).
		Once()

	tool := tools.NewStructured(
		publictypes.ToolDefinition{Name: "test-tool"},
		func(ctx context.Context, request publictypes.ToolCallRequest, input structuredToolInput) (structuredToolOutput, publictypes.Error) {
			result, err := request.Config().Get(expectedKey, "")
			require.NoError(t, err)
			assert.Equal(t, expectedValue, result)
			return structuredToolOutput{}, nil
		},
	)

	internalTool := tool.ToInternal(mockToolCallRequestFactory, mockLoggerFactory, mockConfig, mockMessageCatalog).(basetool.ToolWithStructuredContentOutput[structuredToolInput, structuredToolOutput])

	mcpCallToolRequest := &mcp.CallToolRequest{
		Session: expectedSession,
	}

	// Act
	_, _, err := internalTool.Handler()(t.Context(), mcpCallToolRequest, structuredToolInput{Query: "test"})

	// Assert
	require.NoError(t, err)
	// Assertions are verified via deferred mock expectations.
}

func TestNewStructured_DefinitionFieldsForwarded(t *testing.T) {
	// Arrange
	mockLoggerFactory := &basetoolmocks.MockLoggerFactory{}
	defer mockLoggerFactory.AssertExpectations(t)

	mockConfig := &configmocks.MockGenericConfig{}
	defer mockConfig.AssertExpectations(t)

	mockMessageCatalog := &definitionmocks.MockMessageCatalog{}
	defer mockMessageCatalog.AssertExpectations(t)

	mockToolCallRequestFactory := &toolsmocks.MockToolCallRequestFactory{}
	defer mockToolCallRequestFactory.AssertExpectations(t)

	expectedName := "my-tool"
	expectedTitle := "My Tool"
	expectedDescription := "A tool that does things"
	expectedAnnotations := tools.NewReadOnlyAnnotations()

	tool := tools.NewStructured(
		publictypes.ToolDefinition{
			Name:        expectedName,
			Title:       expectedTitle,
			Description: expectedDescription,
			Annotations: expectedAnnotations,
		},
		func(ctx context.Context, request publictypes.ToolCallRequest, input structuredToolInput) (structuredToolOutput, publictypes.Error) {
			return structuredToolOutput{}, nil
		},
	)

	// Act
	internalTool := tool.ToInternal(mockToolCallRequestFactory, mockLoggerFactory, mockConfig, mockMessageCatalog).(basetool.ToolWithStructuredContentOutput[structuredToolInput, structuredToolOutput])

	// Assert
	require.Equal(t, expectedName, internalTool.Name())
	require.Equal(t, expectedTitle, internalTool.Title())
	require.Equal(t, expectedDescription, internalTool.Description())
	require.Equal(t, expectedAnnotations, internalTool.Annotations())
}

type structuredToolInput struct {
	Query string `json:"query"`
}

type structuredToolOutput struct {
	Result string `json:"result"`
}

var anI18nError = &i18nError{} //nolint:gochecknoglobals // anI18nError is an error

type i18nError struct{}

func (e *i18nError) Error() string { return "" }

func (e *i18nError) MWMarker() {}
