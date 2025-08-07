package configs

import (
	"log"
	"sync"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"` // Add more configs here as needed
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
		v.AddConfigPath("./configs") // Path to look for the config file
		v.SetConfigName("config")    // Name of config file (without extension)
		v.SetConfigType("yaml")      // Type of the config file

		v.AutomaticEnv() // Read environment variables

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
