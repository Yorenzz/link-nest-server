package main

import (
	"clipboard-sync-backend/configs"
	"clipboard-sync-backend/internal/api"
	"clipboard-sync-backend/internal/auth"
	"clipboard-sync-backend/internal/database"
	"clipboard-sync-backend/internal/repository"
	"clipboard-sync-backend/internal/service"
	"clipboard-sync-backend/internal/websocket"
	"fmt"
	"github.com/gin-gonic/gin"
	"log"
	_ "net/http"
)

func main() {
	// 1. Load Configuration
	cfg := configs.LoadConfig()

	// 2. Initialize Database
	db := database.InitDB(cfg)

	// 3. Initialize Repositories
	userRepo := repository.NewUserRepository(db)
	clipboardRepo := repository.NewClipboardRepository(db)

	// 4. Initialize Services
	userService := service.NewUserService(userRepo)
	clipboardService := service.NewClipboardService(clipboardRepo)

	// 5. Initialize API Handlers
	userHandler := api.NewUserHandler(userService)
	clipboardHandler := api.NewClipboardHandler(clipboardService)

	// 6. Initialize WebSocket Manager and Handler
	wsManager := websocket.NewManager()
	go wsManager.Run()
	wsHandler := websocket.NewWsHandler(wsManager, clipboardService)

	// 7. Setup Gin Router
	router := gin.Default()

	// Public routes (no authentication required)
	publicRoutes := router.Group("/api/v1")
	{
		publicRoutes.POST("/register", userHandler.Register)
		publicRoutes.POST("/login", userHandler.Login)
	}

	// Authenticated routes
	authRoutes := router.Group("/api/v1")
	authRoutes.Use(auth.AuthMiddleware())
	{
		authRoutes.POST("/clipboard", clipboardHandler.CreateClipboardEntry)
		authRoutes.GET("/clipboard/history", clipboardHandler.GetClipboardHistory)
		authRoutes.GET("/ws", wsHandler.ServeWs) // WebSocket endpoint
	}

	fmt.Printf("Server is running on %s\n", cfg.Server.Port)
	log.Fatal(router.Run(cfg.Server.Port))
}
