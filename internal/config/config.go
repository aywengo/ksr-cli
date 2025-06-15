package config

import (
	"log"

	"github.com/spf13/viper"
)

// Configuration keys
const (
	KeyRegistryURL = "registry-url"
	KeyUsername    = "username"
	KeyPassword    = "password"
	KeyAPIKey      = "api-key"
	KeyOutput      = "output"
	KeyVerbose     = "verbose"
	KeyTimeout     = "timeout"
	KeyInsecure    = "insecure"
	KeyContext     = "context"
)

// SetDefaults sets default configuration values
func SetDefaults() {
	viper.SetDefault(KeyRegistryURL, "http://localhost:8081")
	viper.SetDefault(KeyOutput, "table")
	viper.SetDefault(KeyVerbose, false)
	viper.SetDefault(KeyTimeout, "30s")
	viper.SetDefault(KeyInsecure, false)
}

// Config represents the CLI configuration
type Config struct {
	RegistryURL string `mapstructure:"registry-url" yaml:"registry-url"`
	Username    string `mapstructure:"username" yaml:"username"`
	Password    string `mapstructure:"password" yaml:"password"`
	APIKey      string `mapstructure:"api-key" yaml:"api-key"`
	Output      string `mapstructure:"output" yaml:"output"`
	Verbose     bool   `mapstructure:"verbose" yaml:"verbose"`
	Timeout     string `mapstructure:"timeout" yaml:"timeout"`
	Insecure    bool   `mapstructure:"insecure" yaml:"insecure"`
	Context     string `mapstructure:"context" yaml:"context"`
}

// GetConfig returns the current configuration
func GetConfig() *Config {
	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		log.Printf("failed to unmarshal config: %v", err)
		return &Config{}
	}
	return &cfg
}

// SaveConfig saves the configuration to file
func SaveConfig() error {
	return viper.WriteConfig()
}

// SaveConfigAs saves the configuration to a specific file
func SaveConfigAs(filename string) error {
	return viper.WriteConfigAs(filename)
}

// SetValue sets a configuration value
func SetValue(key, value string) {
	viper.Set(key, value)
}

// GetValue gets a configuration value
func GetValue(key string) interface{} {
	return viper.Get(key)
}

// GetString gets a string configuration value
func GetString(key string) string {
	return viper.GetString(key)
}

// GetBool gets a boolean configuration value
func GetBool(key string) bool {
	return viper.GetBool(key)
}

// GetInt gets an integer configuration value
func GetInt(key string) int {
	return viper.GetInt(key)
}

// IsSet checks if a configuration key is set
func IsSet(key string) bool {
	return viper.IsSet(key)
}

// AllSettings returns all configuration settings
func AllSettings() map[string]interface{} {
	return viper.AllSettings()
}
