package api

import (
	"net/http"
	"strconv"

	"clipboard-sync-backend/internal/service"

	"github.com/gin-gonic/gin"
)

type ClipboardHandler struct {
	clipboardService service.ClipboardService
}

func NewClipboardHandler(clipboardService service.ClipboardService) *ClipboardHandler {
	return &ClipboardHandler{clipboardService: clipboardService}
}

type CreateEntryRequest struct {
	ContentType string `json:"content_type" binding:"required"`
	Content     string `json:"content" binding:"required"`
	SourceDevice string `json:"source_device"`
}

// CreateClipboardEntry handles creating a new clipboard entry
func (h *ClipboardHandler) CreateClipboardEntry(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req CreateEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	entry, err := h.clipboardService.CreateClipboardEntry(
		userID.(uint),
		req.ContentType,
		req.Content,
		req.SourceDevice,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Clipboard entry created successfully", "entry": entry})
}

// GetClipboardHistory handles retrieving user's clipboard history
func (h *ClipboardHandler) GetClipboardHistory(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 20
	}
	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	entries, err := h.clipboardService.GetUserClipboardHistory(userID.(uint), limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Clipboard history retrieved successfully", "entries": entries})
}


