package models

import (
	"time"

	"gorm.io/gorm"
)

type ClipboardEntry struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	UserID    uint           `gorm:"not null" json:"user_id"`
	User      User           `gorm:"foreignKey:UserID" json:"-"`
	ContentType string       `gorm:"type:varchar(50);not null" json:"content_type"` // e.g., "text", "image"
	Content   string         `gorm:"type:text;not null" json:"content"`         // Encrypted content
	SourceDevice string      `gorm:"type:varchar(255)" json:"source_device"` // e.g., "Chrome on Windows", "Firefox on Android"
	IsShared  bool           `gorm:"default:false" json:"is_shared"`
	TeamID    *uint          `json:"team_id,omitempty"` // Nullable for personal entries
	Team      *Team          `gorm:"foreignKey:TeamID" json:"-"`
	CreatedAt time.Time      `gorm:"autoCreateTime" json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
}

// TableName specifies the table name for GORM
func (ClipboardEntry) TableName() string {
	return "clipboard_entries"
}


