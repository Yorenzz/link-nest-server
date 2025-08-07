package database

import (
	"fmt"
	"log"
	"sync"

	"clipboard-sync-backend/configs"
	"clipboard-sync-backend/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	dbInstance *gorm.DB
	once       sync.Once
)

// InitDB initializes the database connection
func InitDB(cfg *configs.Config) *gorm.DB {
	once.Do(func() {
		dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
			cfg.Database.Host,
			cfg.Database.User,
			cfg.Database.Password,
			cfg.Database.DBName,
			cfg.Database.Port,
			cfg.Database.SSLMode,
		)

		var err error
		dbInstance, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Info), // Log SQL queries
		})
		if err != nil {
			log.Fatalf("Failed to connect to database: %v", err)
		}

		log.Println("Database connection established.")

		// Auto-migrate models
		err = dbInstance.AutoMigrate(&models.User{}, &models.ClipboardEntry{}, &models.Team{}, &models.TeamMember{})
		if err != nil {
			log.Fatalf("Failed to auto-migrate database: %v", err)
		}
		log.Println("Database auto-migration completed.")
	})
	return dbInstance
}

// GetDB returns the initialized database instance
func GetDB() *gorm.DB {
	if dbInstance == nil {
		log.Fatal("Database not initialized. Call InitDB first.")
	}
	return dbInstance
}
