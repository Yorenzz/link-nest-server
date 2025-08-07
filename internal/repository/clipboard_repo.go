package repository

import (
	"clipboard-sync-backend/internal/models"

	"gorm.io/gorm"
)

// ClipboardRepository defines the interface for clipboard entry data operations
type ClipboardRepository interface {
	CreateEntry(entry *models.ClipboardEntry) error
	GetEntriesByUserID(userID uint, limit, offset int) ([]models.ClipboardEntry, error)
	// Add more clipboard-related repository methods as needed
}

type clipboardRepository struct {
	db *gorm.DB
}

// NewClipboardRepository creates a new ClipboardRepository
func NewClipboardRepository(db *gorm.DB) ClipboardRepository {
	return &clipboardRepository{db: db}
}

// CreateEntry creates a new clipboard entry in the database
func (r *clipboardRepository) CreateEntry(entry *models.ClipboardEntry) error {
	return r.db.Create(entry).Error
}

// GetEntriesByUserID retrieves clipboard entries for a specific user
func (r *clipboardRepository) GetEntriesByUserID(userID uint, limit, offset int) ([]models.ClipboardEntry, error) {
	var entries []models.ClipboardEntry
	// Order by CreatedAt in descending order to get most recent first
	if err := r.db.Where("user_id = ? AND is_shared = ?", userID, false).Order("created_at DESC").Limit(limit).Offset(offset).Find(&entries).Error; err != nil {
		return nil, err
	}
	return entries, nil
}
