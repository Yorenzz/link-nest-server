package websocket

import (
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// Client represents a single WebSocket connection
type Client struct {
	UserID uint
	Conn   *websocket.Conn
	Send   chan []byte
}

// Manager handles WebSocket client connections and message broadcasting
type Manager struct {
	clients    map[uint]map[*Client]bool // UserID -> map of clients
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

// NewManager creates a new WebSocket Manager
func NewManager() *Manager {
	return &Manager{
		clients:    make(map[uint]map[*Client]bool),
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

// Run starts the WebSocket manager, handling client connections and messages
func (m *Manager) Run() {
	for {
		select {
			case client := <-m.register:
				m.mu.Lock()
				if _, ok := m.clients[client.UserID]; !ok {
					m.clients[client.UserID] = make(map[*Client]bool)
				}
				m.clients[client.UserID][client] = true
				log.Printf("Client registered: UserID %d, Addr %s. Total clients for user: %d", client.UserID, client.Conn.RemoteAddr(), len(m.clients[client.UserID]))
				m.mu.Unlock()

			case client := <-m.unregister:
				m.mu.Lock()
				if _, ok := m.clients[client.UserID]; ok {
					if _, ok := m.clients[client.UserID][client]; ok {
						delete(m.clients[client.UserID], client)
						close(client.Send)
						log.Printf("Client unregistered: UserID %d, Addr %s. Remaining clients for user: %d", client.UserID, client.Conn.RemoteAddr(), len(m.clients[client.UserID]))
						if len(m.clients[client.UserID]) == 0 {
							delete(m.clients, client.UserID)
						}
					}
				}
				m.mu.Unlock()

			case message := <-m.broadcast:
				// This broadcast is for all connected clients, regardless of user
				// For user-specific broadcast, use SendToUser method
				m.mu.RLock()
				for _, userClients := range m.clients {
					for client := range userClients {
						select {
							case client.Send <- message:
							default:
								close(client.Send)
								delete(userClients, client)
						}
					}
				}
				m.mu.RUnlock()
		}
	}
}

// RegisterClient registers a new WebSocket client
func (m *Manager) RegisterClient(client *Client) {
	m.register <- client
}

// UnregisterClient unregisters a WebSocket client
func (m *Manager) UnregisterClient(client *Client) {
	m.unregister <- client
}

// SendToUser sends a message to all connected clients of a specific user
func (m *Manager) SendToUser(userID uint, message []byte) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if clients, ok := m.clients[userID]; ok {
		for client := range clients {
			select {
				case client.Send <- message:
				default:
					close(client.Send)
					delete(clients, client)
			}
		}
	}
}


