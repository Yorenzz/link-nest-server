package models

type User struct {
	ID       uint   `gorm:"primaryKey" json:"id"`
	Email    string `gorm:"unique;not null" json:"email"`
	Password string `gorm:"not null" json:"-"` // Store hashed password
	// Add other user-related fields as needed, e.g., created_at, updated_at
}

// TableName specifies the table name for GORM
func (User) TableName() string {
	return "users"
}


