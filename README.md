# gossippg — a Postgres LISTEN/NOTIFY listener in Go

> A tiny Go implementation listener for Postgres `LISTEN/NOTIFY`, which decodes JSON payloads and dispatches them to a handler and we can consume them from any client using that JSON payloads.

## Overview

This project connects to Postgres, `LISTEN`s on a channel (default: `events`), and processes notifications whose payload is JSON:

![Listener architecture](./test.png)

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

## Architecture

```mermaid
flowchart LR
  subgraph Dev["Local Dev Environment"]
    CLI["CLI / Makefile<br/>make run · make sql-all"]
    App["Go Listener Service<br/>cmd/main.go"]
  end

  subgraph PG["Postgres (docker-compose)"]
    DB["DB Schema<br/>sql/migrations"]
    Triggers["NOTIFY Triggers<br/>notify_event + *_notify_insert"]
    Channel["Channel: events<br/>LISTEN / NOTIFY"]
  end

  CLI -->|migrate · seed · notify<br/>make migrate / make sql-all| DB
  DB -->|INSERT fires| Triggers
  Triggers -->|pg_notify channel with JSON-as-text| Channel

  App -->|CONNECT via DATABASE_URL| PG
  App -->|LISTEN events| Channel
  Channel -->|NOTIFY events with JSON payload| App

  App -->|json.Unmarshal -> Event<br/>data kept as raw JSON| App
  App -->|handler.Log prints JSON payload| CLI

  classDef appNode fill:#e3fcec,stroke:#2e7d32,stroke-width:1px,color:#1b5e20;
  classDef pgNode fill:#e3f2fd,stroke:#1565c0,stroke-width:1px,color:#0d47a1;
  classDef cliNode fill:#fff3e0,stroke:#ef6c00,stroke-width:1px,color:#e65100;
  classDef channelNode fill:#f3e5f5,stroke:#8e24aa,stroke-width:1px,color:#4a148c;

  class App appNode
  class DB,Triggers pgNode
  class CLI cliNode
  class Channel channelNode
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

## License

This project is licensed under the **MIT License**. See `LICENSE` for details.
