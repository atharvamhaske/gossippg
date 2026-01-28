FROM golang:1.25-alpine AS build

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o /out/gossippg ./cmd

FROM alpine:3.21

WORKDIR /app
COPY --from=build /out/gossippg /usr/local/bin/gossippg

ENV PG_CHANNEL=events
ENTRYPOINT ["/usr/local/bin/gossippg"]


