package models

import (
	"time"

	"gorm.io/gorm"
)

type Team struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	Name      string         `gorm:"unique;not null" json:"name"`
	CreatorID uint           `gorm:"not null" json:"creator_id"`
	Creator   User           `gorm:"foreignKey:CreatorID" json:"-"`
	Members   []TeamMember   `gorm:"foreignKey:TeamID" json:"members"`
	CreatedAt time.Time      `gorm:"autoCreateTime" json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
}

type TeamMember struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	TeamID    uint           `gorm:"not null" json:"team_id"`
	Team      Team           `gorm:"foreignKey:TeamID" json:"-"`
	UserID    uint           `gorm:"not null" json:"user_id"`
	User      User           `gorm:"foreignKey:UserID" json:"-"`
	Role      string         `gorm:"type:varchar(50);not null;default:\'member\'" json:"role"` // e.g., "admin", "member"
	JoinedAt  time.Time      `gorm:"autoCreateTime" json:"joined_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
}

// TableName specifies the table name for GORM
func (Team) TableName() string {
	return "teams"
}

func (TeamMember) TableName() string {
	return "team_members"
}


