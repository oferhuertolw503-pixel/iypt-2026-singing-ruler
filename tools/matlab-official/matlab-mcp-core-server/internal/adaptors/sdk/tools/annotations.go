// Copyright 2026 The MathWorks, Inc.

package tools

import (
	"github.com/modelcontextprotocol/go-sdk/mcp"

	internalannotations "github.com/matlab/matlab-mcp-core-server/internal/adaptors/mcp/tools/annotations"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/sdk/publictypes"
)

type ConvertibleAnnotation interface {
	publictypes.Annotations
	ToToolAnnotations() *mcp.ToolAnnotations
}

type ReadOnlyAnnotation struct {
	publictypes.AnnotationSeal
}

var _ ConvertibleAnnotation = ReadOnlyAnnotation{}

func NewReadOnlyAnnotations() ReadOnlyAnnotation {
	return ReadOnlyAnnotation{}
}

func (a ReadOnlyAnnotation) ToToolAnnotations() *mcp.ToolAnnotations {
	return internalannotations.NewReadOnlyAnnotations().ToToolAnnotations()
}

func newDefaultAnnotation() ReadOnlyAnnotation {
	return NewReadOnlyAnnotations()
}
