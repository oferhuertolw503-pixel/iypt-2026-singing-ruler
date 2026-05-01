// Copyright 2026 The MathWorks, Inc.

package main

import (
	"github.com/matlab/matlab-mcp-core-server/pkg/tools"
)

type ToolsProviderResources interface {
	Dependencies() Dependencies
}

func ToolsProvider(resources ToolsProviderResources) []tools.Tool {
	pid := resources.Dependencies().ExternalService.PID
	return []tools.Tool{
		NewGetPIDTool(pid),
	}
}
