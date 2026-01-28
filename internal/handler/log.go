package handler

import (
	"context"
	"log/slog"

	"github.com/atharvamhaske/gossippg/internal/listener"
)

// Log is a basic listener handler that logs the decoded event payload.
func Log(ctx context.Context, e listener.Event) error {
	slog.Info("event received", "type", e.Type, "id", e.ID, "data", e.Data)
	return nil
}


