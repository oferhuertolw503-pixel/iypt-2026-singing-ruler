// Copyright 2026 The MathWorks, Inc.

package tools

import (
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/sdk/publictypes"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/sdk/tools"
)

type Annotations = publictypes.Annotations

func NewReadOnlyAnnotations() Annotations {
	return tools.NewReadOnlyAnnotations()
}
