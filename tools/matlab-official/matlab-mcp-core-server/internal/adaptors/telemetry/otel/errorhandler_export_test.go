// Copyright 2026 The MathWorks, Inc.

package otel

import "github.com/matlab/matlab-mcp-core-server/internal/entities"

func NewLoggerErrorHandler(logger entities.Logger) *loggerErrorHandler {
	return newLoggerErrorHandler(logger)
}
