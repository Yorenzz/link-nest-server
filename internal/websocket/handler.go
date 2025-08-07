package websocket

import (
	"encoding/json"
	"log"
	"net/http"

	"clipboard-sync-backend/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// TODO: Allow specific origins in production
		return true
	},
}

// WsHandler handles WebSocket connections
type WsHandler struct {
	manager          *Manager
	clipboardService service.ClipboardService
}

// NewWsHandler creates a new WsHandler
func NewWsHandler(manager *Manager, clipboardService service.ClipboardService) *WsHandler {
	return &WsHandler{manager: manager, clipboardService: clipboardService}
}

// ServeWs handles the WebSocket upgrade and connection lifecycle
func (h *WsHandler) ServeWs(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade to websocket: %v", err)
		return
	}

	client := &Client{
		UserID: userID.(uint),
		Conn:   conn,
		Send:   make(chan []byte, 256),
	}

	h.manager.RegisterClient(client)

	// Allow collection of information about the remote connection.
	go h.writePump(client)
	go h.readPump(client)
}

// readPump pumps messages from the websocket connection to the manager.
func (h *WsHandler) readPump(client *Client) {
	defer func() {
		h.manager.UnregisterClient(client)
		client.Conn.Close()
	}()
	for {
		_, message, err := client.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}

		// Handle incoming WebSocket message (e.g., new clipboard content from client)
		var msg struct {
			ContentType string `json:"content_type"`
			Content     string `json:"content"`
			SourceDevice string `json:"source_device"`
		}
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("Error unmarshalling websocket message: %v", err)
			continue
		}

		if msg.ContentType == "" || msg.Content == "" {
			log.Println("Received empty content type or content from websocket")
			continue
		}

		// Save to database
		entry, err := h.clipboardService.CreateClipboardEntry(
			client.UserID,
			msg.ContentType,
			msg.Content,
			msg.SourceDevice,
		)
		if err != nil {
			log.Printf("Error saving clipboard entry from websocket: %v", err)
			continue
		}

		// Broadcast to other devices of the same user
		// Convert entry to JSON to send back
		jsonEntry, err := json.Marshal(entry)
		if err != nil {
			log.Printf("Error marshalling entry for broadcast: %v", err)
			continue
		}
		h.manager.SendToUser(client.UserID, jsonEntry)
	}
}

// writePump pumps messages from the manager to the websocket connection.
func (h *WsHandler) writePump(client *Client) {
	defer func() {
		client.Conn.Close()
	}()
	for {
		select {
			case message, ok := <-client.Send:
				if !ok {
					// The manager closed the channel.
					client.Conn.WriteMessage(websocket.CloseMessage, []byte{})
					return
				}
				if err := client.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
					log.Printf("Error writing message to websocket: %v", err)
					return
				}
		}
	}
}


