package config

import (
	"log/slog"
	"os"
)

type Config struct {
	DatabaseURL string
	ChannelName string
}

func Load() Config {
	cfg := Config{
		DatabaseURL: os.Getenv("DATABASE_URL"),
		ChannelName: os.Getenv("PG_CHANNEL"),
	}

	if cfg.DatabaseURL == "" {
		slog.Error("DATABASE_URL is required")
		os.Exit(1)
	}

	if cfg.ChannelName == "" {
		cfg.ChannelName = "events"
	}
	return cfg
}
