package listener

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/lib/pq"
)

type HandlerFunc func(context.Context, Event) error

type Listener struct {
	connStr string
	channel string
	handler HandlerFunc
}

var defaultHandler HandlerFunc = func(ctx context.Context, e Event) error {
	slog.Info("received event", "type", e.Type, "id", e.ID)
	return nil
}

func New(connStr, channel string, opts ...Option) *Listener {
	l := &Listener{
		connStr: connStr,
		channel: channel,
		handler: defaultHandler,
	}

	for _, opt := range opts {
		opt(l)
	}

	return l
}

func listenerEventTypeString(e pq.ListenerEventType) string {
	switch e {
	case pq.ListenerEventConnected:
		return "connected"
	case pq.ListenerEventDisconnected:
		return "disconnected"
	case pq.ListenerEventReconnected:
		return "reconnected"
	case pq.ListenerEventConnectionAttemptFailed:
		return "connection_attempt_failed"
	default:
		return fmt.Sprintf("unknown(%d)", int(e))
	}
}

func (l *Listener) eventCallBack(e pq.ListenerEventType, err error) {
	if err != nil {
		slog.Error("listener event error", "err", err)
		return
	}

	slog.Info("listener event", "type", listenerEventTypeString(e))
}

func (l *Listener) Start(ctx context.Context) error {
	slog.Info("starting postgres listener", "channel", l.channel)

	pl := pq.NewListener(
		l.connStr,
		10*time.Second,
		time.Minute,
		l.eventCallBack,
	)

	defer func() {
		_ = pl.UnlistenAll()
		_ = pl.Close()
	}()

	if err := pl.Listen(l.channel); err != nil {
		return err
	}

	// Keep a periodic tick so we can wake up even if no notifications arrive.
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			if errors.Is(ctx.Err(), context.Canceled) {
				return nil
			}
			return ctx.Err()

		case n := <-pl.Notify:
			if n == nil {
				// lib/pq can send nil notifications on reconnects; ignore.
				continue
			}

			var ev Event
			if err := json.Unmarshal([]byte(n.Extra), &ev); err != nil {
				slog.Error("failed to decode notification payload", "err", err, "payload", n.Extra)
				continue
			}

			if err := l.handler(ctx, ev); err != nil {
				slog.Error("listener handler error", "err", err, "type", ev.Type, "id", ev.ID)
			}

		case <-ticker.C:
			// Trigger an internal state check / reconnect if needed.
			_ = pl.Ping()
		}
	}
}
