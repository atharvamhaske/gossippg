package listener

type Event struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	Data any    `json:"data,omitempty"`
}
