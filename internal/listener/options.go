package listener

type Option func(*Listener)

func WithHandler(h HandlerFunc) Option {
	return func(l *Listener) {
		if h != nil {
			l.handler = h
		}
	}
}
