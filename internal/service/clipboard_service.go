package service

import (
	_ "errors"
	"fmt"
	"log"

	"clipboard-sync-backend/internal/models"
	"clipboard-sync-backend/internal/repository"
)

// ClipboardService defines the interface for clipboard-related business logic
type ClipboardService interface {
	CreateClipboardEntry(userID uint, contentType, content, sourceDevice string) (*models.ClipboardEntry, error)
	GetUserClipboardHistory(userID uint, limit, offset int) ([]models.ClipboardEntry, error)
	// Add more clipboard-related service methods as needed
}

type clipboardService struct {
	clipboardRepo repository.ClipboardRepository
}

// NewClipboardService creates a new ClipboardService
func NewClipboardService(clipboardRepo repository.ClipboardRepository) ClipboardService {
	return &clipboardService{clipboardRepo: clipboardRepo}
}

// CreateClipboardEntry handles the creation of a new clipboard entry
func (s *clipboardService) CreateClipboardEntry(userID uint, contentType, content, sourceDevice string) (*models.ClipboardEntry, error) {
	// TODO: Implement content encryption before saving

	entry := &models.ClipboardEntry{
		UserID:       userID,
		ContentType:  contentType,
		Content:      content, // This should be encrypted content
		SourceDevice: sourceDevice,
		IsShared:     false, // Default to personal entry
	}

	if err := s.clipboardRepo.CreateEntry(entry); err != nil {
		return nil, fmt.Errorf("failed to create clipboard entry: %w", err)
	}

	log.Printf("Clipboard entry created for user %d, type: %s", userID, contentType)
	return entry, nil
}

// GetUserClipboardHistory retrieves a user's personal clipboard history
func (s *clipboardService) GetUserClipboardHistory(userID uint, limit, offset int) ([]models.ClipboardEntry, error) {
	if limit <= 0 || limit > 100 { // Enforce reasonable limits
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	entries, err := s.clipboardRepo.GetEntriesByUserID(userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get user clipboard history: %w", err)
	}

	// TODO: Implement content decryption before returning

	return entries, nil
}
