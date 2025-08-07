package service

import (
	"errors"
	"fmt"
	"log"

	"clipboard-sync-backend/internal/models"
	"clipboard-sync-backend/internal/repository"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// UserService defines the interface for user-related business logic
type UserService interface {
	RegisterUser(email, password string) (*models.User, error)
	LoginUser(email, password string) (*models.User, error)
	// Add more user-related service methods as needed
}

type userService struct {
	userRepo repository.UserRepository
}

// NewUserService creates a new UserService
func NewUserService(userRepo repository.UserRepository) UserService {
	return &userService{userRepo: userRepo}
}

// RegisterUser handles user registration
func (s *userService) RegisterUser(email, password string) (*models.User, error) {
	// Check if user already exists
	_, err := s.userRepo.GetUserByEmail(email)
	if err == nil {
		return nil, errors.New("user with this email already exists")
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("error checking existing user: %w", err)
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	user := &models.User{
		Email:    email,
		Password: string(hashedPassword),
	}

	// Create user in database
	if err := s.userRepo.CreateUser(user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	log.Printf("User registered: %s", user.Email)
	return user, nil
}

// LoginUser handles user login
func (s *userService) LoginUser(email, password string) (*models.User, error) {
	user, err := s.userRepo.GetUserByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("invalid credentials")
		}
		return nil, fmt.Errorf("error retrieving user: %w", err)
	}

	// Compare hashed password
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		return nil, errors.New("invalid credentials")
	}

	log.Printf("User logged in: %s", user.Email)
	return user, nil
}
