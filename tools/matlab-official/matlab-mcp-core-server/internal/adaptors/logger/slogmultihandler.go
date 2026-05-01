// Copyright 2025 The MathWorks, Inc.

package logger

import (
	"context"
	"log/slog"
)

type Handler interface {
	slog.Handler
}

type SlogMultiHandler struct {
	handlers []Handler
}

func NewMultiHandler(handlers ...Handler) *SlogMultiHandler {
	return &SlogMultiHandler{
		handlers: handlers,
	}
}

// Enabled checks if any of the underlying handlers are enabled for the given level.
func (h *SlogMultiHandler) Enabled(ctx context.Context, level slog.Level) bool {
	for _, handler := range h.handlers {
		if handler.Enabled(ctx, level) {
			return true
		}
	}

	return false
}

func (h *SlogMultiHandler) Handle(ctx context.Context, record slog.Record) error {
	var err error
	for _, handler := range h.handlers {
		if handler.Enabled(ctx, record.Level) {
			thisErr := handler.Handle(ctx, record)
			if err == nil && thisErr != nil {
				err = thisErr
			}
		}
	}

	return err
}

func (h *SlogMultiHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	for i, handler := range h.handlers {
		h.handlers[i] = handler.WithAttrs(attrs)
	}

	return h
}

func (h *SlogMultiHandler) WithGroup(name string) slog.Handler {
	for i, handler := range h.handlers {
		h.handlers[i] = handler.WithGroup(name)
	}

	return h
}
