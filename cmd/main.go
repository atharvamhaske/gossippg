package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/atharvamhaske/gossippg/internal/config"
	"github.com/atharvamhaske/gossippg/internal/handler"
	"github.com/atharvamhaske/gossippg/internal/listener"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle SIGINT / SIGTERM (Ctrl+C, k8s stop, docker stop)
	go func() {
		sg := make(chan os.Signal, 1)
		signal.Notify(sg, syscall.SIGINT, syscall.SIGTERM)
		<-sg
		slog.Info("shutdown signal received")
		cancel()
	}()

	cfg := config.Load()

	l := listener.New(
		cfg.DatabaseURL,
		cfg.ChannelName,
		listener.WithHandler(handler.Log),
	)
	if err := l.Start(ctx); err != nil {
		slog.Error("listener exited", "err", err)
	}
}
