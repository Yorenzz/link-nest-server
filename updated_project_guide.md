# 跨平台剪贴板同步工具 - Go Gin项目结构与代码示例指南

本文档旨在详细说明“跨平台剪贴板同步工具”Go Gin后端服务在引入基础封装和示例代码后的项目结构，并提供关键代码文件的作用和示例，以帮助您理解和快速上手开发。

## 1. 项目概览

在之前的项目结构基础上，我们增加了配置管理、数据库连接、GORM模型定义、数据仓库层、业务服务层、JWT认证、Gin API路由以及WebSocket通信等核心组件的实现。这些组件按照职责进行了清晰的划分和封装，遵循了Go语言的最佳实践，旨在构建一个可维护、可扩展且易于测试的后端服务。

## 2. 更新后的项目结构

```
clipboard-sync-backend/
├── cmd/
│   └── server/
│       └── main.go             # 主程序入口，负责初始化和启动服务
├── configs/
│   ├── config.go               # 配置加载和解析
│   └── config.yaml             # 示例配置文件
├── internal/
│   ├── api/
│   │   ├── clipboard.go        # 剪贴板相关API处理函数
│   │   └── user.go             # 用户相关API处理函数
│   ├── auth/
│   │   ├── jwt.go              # JWT生成与解析
│   │   └── middleware.go       # JWT认证中间件
│   ├── database/
│   │   └── db.go               # 数据库连接和GORM初始化
│   ├── models/
│   │   ├── clipboard_entry.go  # 剪贴板条目模型
│   │   ├── team.go             # 团队和团队成员模型 (为未来扩展预留)
│   │   └── user.go             # 用户模型
│   ├── repository/
│   │   ├── clipboard_repo.go   # 剪贴板数据仓库接口与实现
│   │   └── user_repo.go        # 用户数据仓库接口与实现
│   ├── service/
│   │   ├── clipboard_service.go# 剪贴板业务逻辑服务
│   │   └── user_service.go     # 用户业务逻辑服务
│   └── websocket/
│       ├── handler.go          # WebSocket连接处理
│       └── manager.go          # WebSocket连接管理器
├── pkg/                        # 存放可复用的公共包 (目前为空，为未来扩展预留)
├── scripts/                    # 存放辅助脚本 (目前为空，为未来扩展预留)
├── web/                        # 存放前端静态文件 (目前为空，为未来扩展预留)
├── go.mod
├── go.sum
└── project_structure.md        # 原始项目结构说明
```

## 3. 关键代码文件说明与示例

### 3.1 `configs/config.go` 和 `configs/config.yaml`

*   **作用**：负责从`config.yaml`文件中加载应用程序的配置，如服务器端口、数据库连接信息等。使用`viper`库实现配置管理，支持从文件、环境变量等多种来源加载配置。
*   **`configs/config.go` 示例**：
    ```go
    package configs

    import (
    	"log"
    	"sync"

    	"github.com/spf13/viper"
    )

    type Config struct {
    	Server   ServerConfig   `mapstructure:"server"`
    	Database DatabaseConfig `mapstructure:"database"`
    }

    type ServerConfig struct {
    	Port string `mapstructure:"port"`
    }

    type DatabaseConfig struct {
    	Host     string `mapstructure:"host"`
    	Port     string `mapstructure:"port"`
    	User     string `mapstructure:"user"`
    	Password string `mapstructure:"password"`
    	DBName   string `mapstructure:"dbname"`
    	SSLMode  string `mapstructure:"sslmode"`
    }

    var (
    	configOnce sync.Once
    	appConfig  *Config
    )

    func LoadConfig() *Config {
    	configOnce.Do(func() {
    		v := viper.New()
    		v.AddConfigPath("./configs")
    		v.SetConfigName("config")
    		v.SetConfigType("yaml")
    		v.AutomaticEnv()

    		if err := v.ReadInConfig(); err != nil {
    			log.Fatalf("Error reading config file, %s", err)
    		}

    		appConfig = &Config{}
    		if err := v.Unmarshal(appConfig); err != nil {
    			log.Fatalf("Unable to decode into struct, %s", err)
    		}
    		log.Println("Configuration loaded successfully.")
    	})
    	return appConfig
    }
    ```
*   **`configs/config.yaml` 示例**：
    ```yaml
    server:
      port: ":8080"
database:
  host: "localhost"
  port: "5432"
  user: "user"
  password: "password"
  dbname: "clipboard_sync"
  sslmode: "disable"
    ```

### 3.2 `internal/models/`

*   **作用**：定义了应用程序的数据模型，这些模型通常直接映射到数据库表结构。使用了GORM的`gorm`标签来指定字段与数据库列的映射关系。
*   **`internal/models/user.go` 示例**：
    ```go
    package models

    type User struct {
    	ID       uint   `gorm:"primaryKey" json:"id"`
    	Email    string `gorm:"unique;not null" json:"email"`
    	Password string `gorm:"not null" json:"-"` // Store hashed password
    }

    func (User) TableName() string {
    	return "users"
    }
    ```
*   **`internal/models/clipboard_entry.go` 示例**：
    ```go
    package models

    import (
    	"time"

    	"gorm.io/gorm"
    )

    type ClipboardEntry struct {
    	ID        uint           `gorm:"primaryKey" json:"id"`
    	UserID    uint           `gorm:"not null" json:"user_id"`
    	User      User           `gorm:"foreignKey:UserID" json:"-"`
    	ContentType string       `gorm:"type:varchar(50);not null" json:"content_type"`
    	Content   string         `gorm:"type:text;not null" json:"content"`
    	SourceDevice string      `gorm:"type:varchar(255)" json:"source_device"`
    	IsShared  bool           `gorm:"default:false" json:"is_shared"`
    	TeamID    *uint          `json:"team_id,omitempty"`
    	Team      *Team          `gorm:"foreignKey:TeamID" json:"-"`
    	CreatedAt time.Time      `gorm:"autoCreateTime" json:"created_at"`
    	DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
    }

    func (ClipboardEntry) TableName() string {
    	return "clipboard_entries"
    }
    ```
*   **`internal/models/team.go` 示例** (为未来团队协作功能预留)：
    ```go
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
    	Role      string         `gorm:"type:varchar(50);not null;default:\'member\''" json:"role"`
    	JoinedAt  time.Time      `gorm:"autoCreateTime" json:"joined_at"`
    	DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
    }

    func (Team) TableName() string {
    	return "teams"
    }

    func (TeamMember) TableName() string {
    	return "team_members"
    }
    ```

### 3.3 `internal/database/db.go`

*   **作用**：封装了数据库的初始化和连接管理。使用GORM作为ORM框架，连接PostgreSQL数据库，并进行模型的自动迁移。
*   **示例**：
    ```go
    package database

    import (
    	"fmt"
    	"log"
    	"sync"

    	"clipboard-sync-backend/configs"
    	"clipboard-sync-backend/internal/models"

    	gorm.io/driver/postgres"
    	gorm.io/gorm"
    	gorm.io/gorm/logger"
    )

    var (
    	dbInstance *gorm.DB
    	once sync.Once
    )

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
    			Logger: logger.Default.LogMode(logger.Info),
    		})
    		if err != nil {
    			log.Fatalf("Failed to connect to database: %v", err)
    		}

    		log.Println("Database connection established.")

    		err = dbInstance.AutoMigrate(&models.User{}, &models.ClipboardEntry{}, &models.Team{}, &models.TeamMember{})
    		if err != nil {
    			log.Fatalf("Failed to auto-migrate database: %v", err)
    		}
    		log.Println("Database auto-migration completed.")
    	})
    	return dbInstance
    }

    func GetDB() *gorm.DB {
    	if dbInstance == nil {
    		log.Fatal("Database not initialized. Call InitDB first.")
    	}
    	return dbInstance
    }
    ```

### 3.4 `internal/repository/`

*   **作用**：数据访问层（DAL），定义了与数据库交互的接口和实现。每个Repository负责一个或一组模型的数据操作，将业务逻辑与数据存储细节解耦。
*   **`internal/repository/user_repo.go` 示例**：
    ```go
    package repository

    import (
    	"clipboard-sync-backend/internal/models"

    	gorm.io/gorm"
    )

    type UserRepository interface {
    	CreateUser(user *models.User) error
    	GetUserByEmail(email string) (*models.User, error)
    	GetUserByID(id uint) (*models.User, error)
    }

    type userRepository struct {
    	db *gorm.DB
    }

    func NewUserRepository(db *gorm.DB) UserRepository {
    	return &userRepository{db: db}
    }

    func (r *userRepository) CreateUser(user *models.User) error {
    	return r.db.Create(user).Error
    }

    func (r *userRepository) GetUserByEmail(email string) (*models.User, error) {
    	var user models.User
    	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
    		return nil, err
    	}
    	return &user, nil
    }

    func (r *userRepository) GetUserByID(id uint) (*models.User, error) {
    	var user models.User
    	if err := r.db.First(&user, id).Error; err != nil {
    		return nil, err
    	}
    	return &user, nil
    }
    ```
*   **`internal/repository/clipboard_repo.go` 示例**：
    ```go
    package repository

    import (
    	"clipboard-sync-backend/internal/models"

    	gorm.io/gorm"
    )

    type ClipboardRepository interface {
    	CreateEntry(entry *models.ClipboardEntry) error
    	GetEntriesByUserID(userID uint, limit, offset int) ([]models.ClipboardEntry, error)
    }

    type clipboardRepository struct {
    	db *gorm.DB
    }

    func NewClipboardRepository(db *gorm.DB) ClipboardRepository {
    	return &clipboardRepository{db: db}
    }

    func (r *clipboardRepository) CreateEntry(entry *models.ClipboardEntry) error {
    	return r.db.Create(entry).Error
    }

    func (r *clipboardRepository) GetEntriesByUserID(userID uint, limit, offset int) ([]models.ClipboardEntry, error) {
    	var entries []models.ClipboardEntry
    	if err := r.db.Where("user_id = ? AND is_shared = ?", userID, false).Order("created_at DESC").Limit(limit).Offset(offset).Find(&entries).Error; err != nil {
    		return nil, err
    	}
    	return entries, nil
    }
    ```

### 3.5 `internal/service/`

*   **作用**：业务逻辑层（BLL），包含了应用程序的核心业务逻辑。Service层会协调Repository层和其他服务来完成复杂的业务流程。
*   **`internal/service/user_service.go` 示例**：
    ```go
    package service

    import (
    	"errors"
    	"fmt"
    	"log"

    	"clipboard-sync-backend/internal/models"
    	"clipboard-sync-backend/internal/repository"

    	"golang.org/x/crypto/bcrypt"
    	gorm.io/gorm"
    )

    type UserService interface {
    	RegisterUser(email, password string) (*models.User, error)
    	LoginUser(email, password string) (*models.User, error)
    }

    type userService struct {
    	userRepo repository.UserRepository
    }

    func NewUserService(userRepo repository.UserRepository) UserService {
    	return &userService{userRepo: userRepo}
    }

    func (s *userService) RegisterUser(email, password string) (*models.User, error) {
    	_, err := s.userRepo.GetUserByEmail(email)
    	if err == nil {
    		return nil, errors.New("user with this email already exists")
    	}
    	if !errors.Is(err, gorm.ErrRecordNotFound) {
    		return nil, fmt.Errorf("error checking existing user: %w", err)
    	}

    	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    	if err != nil {
    		return nil, fmt.Errorf("failed to hash password: %w", err)
    	}

    	user := &models.User{
    		Email:    email,
    		Password: string(hashedPassword),
    	}

    	if err := s.userRepo.CreateUser(user); err != nil {
    		return nil, fmt.Errorf("failed to create user: %w", err)
    	}

    	log.Printf("User registered: %s", user.Email)
    	return user, nil
    }

    func (s *userService) LoginUser(email, password string) (*models.User, error) {
    	user, err := s.userRepo.GetUserByEmail(email)
    	if err != nil {
    		if errors.Is(err, gorm.ErrRecordNotFound) {
    			return nil, errors.New("invalid credentials")
    		}
    		return nil, fmt.Errorf("error retrieving user: %w", err)
    	}

    	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
    		return nil, errors.New("invalid credentials")
    	}

    	log.Printf("User logged in: %s", user.Email)
    	return user, nil
    }
    ```
*   **`internal/service/clipboard_service.go` 示例**：
    ```go
    package service

    import (
    	"fmt"
    	"log"

    	"clipboard-sync-backend/internal/models"
    	"clipboard-sync-backend/internal/repository"
    )

    type ClipboardService interface {
    	CreateClipboardEntry(userID uint, contentType, content, sourceDevice string) (*models.ClipboardEntry, error)
    	GetUserClipboardHistory(userID uint, limit, offset int) ([]models.ClipboardEntry, error)
    }

    type clipboardService struct {
    	clipboardRepo repository.ClipboardRepository
    }

    func NewClipboardService(clipboardRepo repository.ClipboardRepository) ClipboardService {
    	return &clipboardService{clipboardRepo: clipboardRepo}
    }

    func (s *clipboardService) CreateClipboardEntry(userID uint, contentType, content, sourceDevice string) (*models.ClipboardEntry, error) {
    	entry := &models.ClipboardEntry{
    		UserID:       userID,
    		ContentType:  contentType,
    		Content:      content,
    		SourceDevice: sourceDevice,
    		IsShared:     false,
    	}

    	if err := s.clipboardRepo.CreateEntry(entry); err != nil {
    		return nil, fmt.Errorf("failed to create clipboard entry: %w", err)
    	}

    	log.Printf("Clipboard entry created for user %d, type: %s", userID, contentType)
    	return entry, nil
    }

    func (s *clipboardService) GetUserClipboardHistory(userID uint, limit, offset int) ([]models.ClipboardEntry, error) {
    	if limit <= 0 || limit > 100 {
    		limit = 20
    	}
    	if offset < 0 {
    		offset = 0
    	}

    	entries, err := s.clipboardRepo.GetEntriesByUserID(userID, limit, offset)
    	if err != nil {
    		return nil, fmt.Errorf("failed to get user clipboard history: %w", err)
    	}

    	return entries, nil
    }
    ```

### 3.6 `internal/auth/`

*   **作用**：处理用户认证和授权。`jwt.go`负责JWT的生成和解析，`middleware.go`则提供了Gin框架的认证中间件。
*   **`internal/auth/jwt.go` 示例**：
    ```go
    package auth

    import (
    	"errors"
    	"time"

    	"github.com/golang-jwt/jwt/v5"
    )

    type Claims struct {
    	UserID uint `json:"user_id"`
    	jwt.RegisteredClaims
    }

    var jwtSecret = []byte("your_super_secret_jwt_key") // TODO: Load from config

    func GenerateToken(userID uint) (string, error) {
    	expirationTime := time.Now().Add(24 * time.Hour)
    	claims := &Claims{
    		UserID: userID,
    		RegisteredClaims: jwt.RegisteredClaims{
    			ExpiresAt: jwt.NewNumericDate(expirationTime),
    			IssuedAt:  jwt.NewNumericDate(time.Now()),
    		},
    	}

    	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    	tokenString, err := token.SignedString(jwtSecret)
    	if err != nil {
    		return "", errors.New("failed to sign token")
    	}
    	return tokenString, nil
    }

    func ParseToken(tokenString string) (*Claims, error) {
    	claims := &Claims{}
    	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
    		return jwtSecret, nil
    	})

    	if err != nil {
    		return nil, err
    	}

    	if !token.Valid {
    		return nil, errors.New("invalid token")
    	}

    	return claims, nil
    }
    ```
*   **`internal/auth/middleware.go` 示例**：
    ```go
    package auth

    import (
    	"net/http"
    	"strings"

    	"github.com/gin-gonic/gin"
    )

    func AuthMiddleware() gin.HandlerFunc {
    	return func(c *gin.Context) {
    		authHeader := c.GetHeader("Authorization")
    		if authHeader == "" {
    			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
    			c.Abort()
    			return
    		}

    		parts := strings.Split(authHeader, " ")
    		if len(parts) != 2 || parts[0] != "Bearer" {
    			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid Authorization header format"})
    			c.Abort()
    			return
    		}

    		tokenString := parts[1]
    		claims, err := ParseToken(tokenString)
    		if err != nil {
    			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
    			c.Abort()
    			return
    		}

    		c.Set("userID", claims.UserID)
    		c.Next()
    	}
    }
    ```

### 3.7 `internal/api/`

*   **作用**：Gin路由的处理函数（Handlers）。它们负责接收HTTP请求、解析请求参数、调用Service层处理业务逻辑，并返回HTTP响应。
*   **`internal/api/user.go` 示例**：
    ```go
    package api

    import (
    	"net/http"

    	"clipboard-sync-backend/internal/auth"
    	"clipboard-sync-backend/internal/service"

    	"github.com/gin-gonic/gin"
    )

    type UserHandler struct {
    	userService service.UserService
    }

    func NewUserHandler(userService service.UserService) *UserHandler {
    	return &UserHandler{userService: userService}
    }

    type RegisterRequest struct {
    	Email    string `json:"email" binding:"required,email"`
    	Password string `json:"password" binding:"required,min=6"`
    }

    func (h *UserHandler) Register(c *gin.Context) {
    	var req RegisterRequest
    	if err := c.ShouldBindJSON(&req); err != nil {
    		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
    		return
    	}

    	user, err := h.userService.RegisterUser(req.Email, req.Password)
    	if err != nil {
    		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
    		return
    	}

    	c.JSON(http.StatusCreated, gin.H{"message": "User registered successfully", "user_id": user.ID, "email": user.Email})
    }

    type LoginRequest struct {
    	Email    string `json:"email" binding:"required,email"`
    	Password string `json:"password" binding:"required"`
    }

    func (h *UserHandler) Login(c *gin.Context) {
    	var req LoginRequest
    	if err := c.ShouldBindJSON(&req); err != nil {
    		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
    		return
    	}

    	user, err := h.userService.LoginUser(req.Email, req.Password)
    	if err != nil {
    		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
    		return
    	}

    	token, err := auth.GenerateToken(user.ID)
    	if err != nil {
    		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
    		return
    	}

    	c.JSON(http.StatusOK, gin.H{"message": "Login successful", "token": token, "user_id": user.ID})
    }
    ```
*   **`internal/api/clipboard.go` 示例**：
    ```go
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
    ```

### 3.8 `internal/websocket/`

*   **作用**：处理WebSocket连接的建立、管理和消息的发送与接收。`manager.go`负责维护所有活跃的WebSocket连接，并提供向特定用户广播消息的能力。`handler.go`则处理WebSocket升级请求和消息的读写。
*   **`internal/websocket/manager.go` 示例**：
    ```go
    package websocket

    import (
    	"log"
    	"sync"

    	"github.com/gorilla/websocket"
    )

    type Client struct {
    	UserID uint
    	Conn   *websocket.Conn
    	Send   chan []byte
    }

    type Manager struct {
    	clients    map[uint]map[*Client]bool
    	broadcast  chan []byte
    	register   chan *Client
    	unregister chan *Client
    	mu         sync.RWMutex
    }

    func NewManager() *Manager {
    	return &Manager{
    		clients:    make(map[uint]map[*Client]bool),
    		broadcast:  make(chan []byte),
    		register:   make(chan *Client),
    		unregister: make(chan *Client),
    	}
    }

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

    func (m *Manager) RegisterClient(client *Client) {
    	m.register <- client
    }

    func (m *Manager) UnregisterClient(client *Client) {
    	m.unregister <- client
    }

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
    ```
*   **`internal/websocket/handler.go` 示例**：
    ```go
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
    		return true
    	},
    }

    type WsHandler struct {
    	manager          *Manager
    	clipboardService service.ClipboardService
    }

    func NewWsHandler(manager *Manager, clipboardService service.ClipboardService) *WsHandler {
    	return &WsHandler{manager: manager, clipboardService: clipboardService}
    }

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

    	go h.writePump(client)
    	go h.readPump(client)
    }

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

    		jsonEntry, err := json.Marshal(entry)
    		if err != nil {
    			log.Printf("Error marshalling entry for broadcast: %v", err)
    			continue
    		}
    		h.manager.SendToUser(client.UserID, jsonEntry)
    	}
    }

    func (h *WsHandler) writePump(client *Client) {
    	defer func() {
    		client.Conn.Close()
    	}()
    	for {
    		select {
    			case message, ok := <-client.Send:
    				if !ok {
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
    ```

### 3.9 `cmd/server/main.go`

*   **作用**：应用程序的入口点。它负责加载配置、初始化数据库、创建所有Repository、Service、Handler实例，设置Gin路由，并启动HTTP服务器和WebSocket管理器。
*   **示例**：
    ```go
    package main

    import (
    	"fmt"
    	"log"
    	"net/http"

    	"clipboard-sync-backend/configs"
    	"clipboard-sync-backend/internal/api"
    	"clipboard-sync-backend/internal/auth"
    	"clipboard-sync-backend/internal/database"
    	"clipboard-sync-backend/internal/repository"
    	"clipboard-sync-backend/internal/service"
    	"clipboard-sync-backend/internal/websocket"

    	"github.com/gin-gonic/gin"
    )

    func main() {
    	cfg := configs.LoadConfig()

    	db := database.InitDB(cfg)

    	userRepo := repository.NewUserRepository(db)
    	clipboardRepo := repository.NewClipboardRepository(db)

    	userService := service.NewUserService(userRepo)
    	clipboardService := service.NewClipboardService(clipboardRepo)

    	userHandler := api.NewUserHandler(userService)
    	clipboardHandler := api.NewClipboardHandler(clipboardService)

    	wsManager := websocket.NewManager()
    	go wsManager.Run()
    	wsHandler := websocket.NewWsHandler(wsManager, clipboardService)

    	router := gin.Default()

    	publicRoutes := router.Group("/api/v1")
    	{
    		publicRoutes.POST("/register", userHandler.Register)
    		publicRoutes.POST("/login", userHandler.Login)
    	}

    	authRoutes := router.Group("/api/v1")
    	authRoutes.Use(auth.AuthMiddleware())
    	{
    		authRoutes.POST("/clipboard", clipboardHandler.CreateClipboardEntry)
    		authRoutes.GET("/clipboard/history", clipboardHandler.GetClipboardHistory)
    		authRoutes.GET("/ws", wsHandler.ServeWs)
    	}

    	fmt.Printf("Server is running on %s\n", cfg.Server.Port)
    	log.Fatal(router.Run(cfg.Server.Port))
    }
    ```

## 4. 如何运行项目

1.  **安装Go语言环境**：确保您的系统安装了Go 1.21或更高版本。
2.  **安装PostgreSQL数据库**：并创建一个名为`clipboard_sync`的数据库，以及一个具有相应权限的用户（根据`configs/config.yaml`中的配置）。
3.  **克隆项目**：将项目克隆到本地。
4.  **进入项目根目录**：`cd clipboard-sync-backend`
5.  **下载依赖**：`go mod tidy`
6.  **运行项目**：`go run cmd/server/main.go`

项目启动后，您可以通过API工具（如Postman、Insomnia）或前端应用来测试接口。

## 5. 第一阶段需求实现概览

*   **用户管理**：
    *   `POST /api/v1/register`：用户注册。
    *   `POST /api/v1/login`：用户登录，返回JWT Token。
    *   `internal/auth/middleware.go`：JWT认证中间件，保护需要认证的API。
*   **核心文本同步**：
    *   `POST /api/v1/clipboard`：通过HTTP API上传剪贴板内容（可用于非实时场景或作为WebSocket的备用）。
    *   `GET /api/v1/ws`：WebSocket连接端点，用于实时双向同步。前端通过WebSocket发送复制内容，后端通过WebSocket推送新内容到其他设备。
*   **基本历史记录**：
    *   `GET /api/v1/clipboard/history`：获取用户剪贴板历史记录。

## 6. 为后续需求预留的空间

*   **图片同步**：`internal/models/clipboard_entry.go`中的`ContentType`字段已预留，`internal/service/clipboard_service.go`和`internal/websocket/handler.go`可以扩展处理Base64编码的图片内容。
*   **设备管理**：可以在`internal/models/`中添加`Device`模型，并在`internal/repository/`和`internal/service/`中实现相关逻辑，`internal/api/`中添加设备管理API。
*   **团队协作剪贴板**：`internal/models/team.go`和`internal/models/team_member.go`已定义，可以在`internal/repository/`、`internal/service/`和`internal/api/`中逐步实现团队创建、成员管理、共享剪贴板等功能。WebSocket管理器`internal/websocket/manager.go`中的`SendToUser`方法可以扩展为`SendToTeam`。
*   **安全与隐私**：`internal/auth/jwt.go`中的`jwtSecret`需要从配置文件加载。可以在`internal/service/clipboard_service.go`中添加加密/解密逻辑，并在`internal/auth/`中实现端到端加密的密钥管理。

这个项目框架为您提供了一个坚实的基础，您可以根据需求文档逐步填充和完善各个模块，实现更复杂的功能。

