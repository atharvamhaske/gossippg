# gossippg — a Postgres LISTEN/NOTIFY listener in Go

> A tiny Go implementation listener for Postgres `LISTEN/NOTIFY`, which decodes JSON payloads and dispatches them to a handler and we can consume them from any client using that JSON payloads.

----

## Overview

This project connects to Postgres, `LISTEN`s on a channel (default: `events`), and processes notifications whose payload is JSON:

## How It Works

Postgres `NOTIFY` can only send a **text** payload. To still send structured data, this project sends **JSON-as-text**:

- The SQL triggers call `pg_notify('events', jsonb_build_object(...)::text)`. That means Postgres is literally pushing a JSON string over the notification channel.
- On the Go side, lib/pq keeps a long-lived connection open and `LISTEN`s on the channel (default `events`). It also reports connection state changes (connected/disconnected/reconnected) via the listener callback, which we log.
- When a notification arrives, lib/pq delivers it on `pl.Notify`. We take `n.Extra` (the string payload), decode it into an `Event`, and keep `Event.Data` as **raw JSON bytes** (`json.RawMessage`) so the original JSON shape is preserved.
- Finally, the handler (`internal/handler.Log`) prints `data` as a JSON string (instead of Go’s `map[...]` format), so what you see in logs matches what was actually sent.

```mermaid
sequenceDiagram
    participant App as Go Listener (lib/pq)
    participant PG as Postgres

    App->>PG: CONNECT
    App->>PG: LISTEN events
    Note over App: eventCallBack logs connection state

    PG-->>App: NOTIFY events, '<json text>'
    App->>App: json.Unmarshal(payload) -> Event
    App->>App: handler(ctx, Event)
```

## Setup (Recommended)

### 1) Start Postgres with Docker

```bash
make docker-up
```

### 2) Configure env

```bash
cp env.example .env
```

`env.example` is set up to match `docker-compose.yml` defaults.

### 3) Apply schema + triggers

```bash
make migrate
```

### 4) Run the listener

```bash
make run
```

### 5) Fire test events

```bash
make sql-all
```
