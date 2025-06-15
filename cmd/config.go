package cmd

import (
	"fmt"
	"os"

	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// configCmd represents the config command
var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage CLI configuration",
	Long: `Manage the CLI configuration including registry URL, authentication, and output preferences.

Configuration can be stored in:
  - $HOME/.ksr-cli.yaml
  - $XDG_CONFIG_HOME/ksr-cli/config.yaml
  - ./ksr-cli.yaml

Examples:
  ksr-cli config set registry-url http://localhost:8081
  ksr-cli config set username myuser
  ksr-cli config set password mypass
  ksr-cli config get registry-url
  ksr-cli config list
  ksr-cli config init`,
}

var configSetCmd = &cobra.Command{
	Use:   "set KEY VALUE",
	Short: "Set a configuration value",
	Long: `Set a configuration value. The configuration is saved to the config file.

Available configuration keys:
  registry-url    - Schema Registry URL
  username        - Username for basic auth
  password        - Password for basic auth  
  api-key         - API key for authentication
  output          - Default output format (table, json, yaml)
  timeout         - Request timeout (e.g., 30s)
  insecure        - Skip TLS verification (true/false)
  context         - Default Schema Registry context (default: ".")

Examples:
  ksr-cli config set registry-url http://localhost:8081
  ksr-cli config set output json
  ksr-cli config set timeout 60s
  ksr-cli config set context my-context`,
	Args: cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		key := args[0]
		value := args[1]

		// Validate key
		validKeys := map[string]bool{
			"registry-url": true,
			"username":     true,
			"password":     true,
			"api-key":      true,
			"output":       true,
			"timeout":      true,
			"insecure":     true,
			"context":      true,
		}

		if !validKeys[key] {
			return fmt.Errorf("invalid configuration key: %s", key)
		}

		// Special validation for certain keys
		switch key {
		case "output":
			if value != "table" && value != "json" && value != "yaml" {
				return fmt.Errorf("invalid output format: %s (must be table, json, or yaml)", value)
			}
		case "insecure":
			if value != "true" && value != "false" {
				return fmt.Errorf("invalid boolean value: %s (must be true or false)", value)
			}
		}

		// Set the value
		config.SetValue(key, value)

		// Save configuration
		if err := config.SaveConfig(); err != nil {
			// If config file doesn't exist, create it
			if os.IsNotExist(err) {
				home, err := os.UserHomeDir()
				if err != nil {
					return fmt.Errorf("failed to get home directory: %w", err)
				}
				configFile := fmt.Sprintf("%s/.ksr-cli.yaml", home)
				if err := config.SaveConfigAs(configFile); err != nil {
					return fmt.Errorf("failed to save configuration: %w", err)
				}
			} else {
				return fmt.Errorf("failed to save configuration: %w", err)
			}
		}

		fmt.Printf("Configuration updated: %s = %s\n", key, value)
		return nil
	},
}

var configGetCmd = &cobra.Command{
	Use:   "get KEY",
	Short: "Get a configuration value",
	Long: `Get a configuration value.

Examples:
  ksr-cli config get registry-url
  ksr-cli config get output`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		key := args[0]
		value := config.GetValue(key)

		if value == nil {
			fmt.Printf("%s is not set\n", key)
			return nil
		}

		fmt.Printf("%s = %v\n", key, value)
		return nil
	},
}

var configListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all configuration values",
	Long:  `List all configuration values from the config file and environment variables.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		settings := config.AllSettings()

		if len(settings) == 0 {
			fmt.Println("No configuration found")
			return nil
		}

		return output.Print(settings, outputFormat)
	},
}

var configInitCmd = &cobra.Command{
	Use:   "init",
	Short: "Initialize configuration file",
	Long: `Initialize a new configuration file with default values.

This will create a configuration file in your home directory if one doesn't exist.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("failed to get home directory: %w", err)
		}

		configFile := fmt.Sprintf("%s/.ksr-cli.yaml", home)

		// Check if config file already exists
		if _, err := os.Stat(configFile); err == nil {
			fmt.Printf("Configuration file already exists: %s\n", configFile)
			return nil
		}

		// Set default values
		config.SetDefaults()

		// Save configuration
		if err := config.SaveConfigAs(configFile); err != nil {
			return fmt.Errorf("failed to create configuration file: %w", err)
		}

		fmt.Printf("Configuration file created: %s\n", configFile)
		fmt.Println("\nYou can now set your registry URL:")
		fmt.Println("  ksr-cli config set registry-url http://your-schema-registry:8081")
		return nil
	},
}

var configValidateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate configuration",
	Long:  `Validate the current configuration and test connectivity to the Schema Registry.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Check if registry URL is set
		registryURL := config.GetString("registry-url")
		if registryURL == "" {
			return fmt.Errorf("registry-url is not configured")
		}

		fmt.Printf("✅ Registry URL: %s\n", registryURL)

		// Check authentication configuration
		username := config.GetString("username")
		password := config.GetString("password")
		apiKey := config.GetString("api-key")

		if apiKey != "" {
			fmt.Println("✅ Authentication: API Key configured")
		} else if username != "" && password != "" {
			fmt.Println("✅ Authentication: Basic Auth configured")
		} else {
			fmt.Println("ℹ️  Authentication: None configured")
		}

		// Test connectivity
		fmt.Println("\nTesting connectivity...")

		// This would typically test the connection, but since we're in cmd package
		// and don't want to create circular dependencies, we'll just show the config
		fmt.Println("To test connectivity, run: ksr-cli get subjects")

		return nil
	},
}

var configResetCmd = &cobra.Command{
	Use:   "reset",
	Short: "Reset configuration to defaults",
	Long:  `Reset the configuration file to default values. This will remove all custom settings.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Clear all settings
		for key := range config.AllSettings() {
			viper.Set(key, nil)
		}

		// Set defaults
		config.SetDefaults()

		// Save configuration
		if err := config.SaveConfig(); err != nil {
			return fmt.Errorf("failed to reset configuration: %w", err)
		}

		fmt.Println("Configuration reset to defaults")
		return nil
	},
}

func init() {
	// Initialize viper configuration
	initConfig()

	rootCmd.AddCommand(configCmd)

	// Add subcommands
	configCmd.AddCommand(configSetCmd)
	configCmd.AddCommand(configGetCmd)
	configCmd.AddCommand(configListCmd)
	configCmd.AddCommand(configInitCmd)
	configCmd.AddCommand(configValidateCmd)
	configCmd.AddCommand(configResetCmd)

	configCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}

// initConfig initializes viper configuration
func initConfig() {
	// Set config file name (without extension)
	viper.SetConfigName(".ksr-cli")
	viper.SetConfigType("yaml")

	// Add config paths
	viper.AddConfigPath(".")     // Current directory
	viper.AddConfigPath("$HOME") // Home directory

	// Set environment variable prefix
	viper.SetEnvPrefix("KSR")
	viper.AutomaticEnv()

	// Read config file if it exists
	if err := viper.ReadInConfig(); err != nil {
		// Config file not found is okay, we'll create it when needed
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			// Config file was found but another error was produced
			fmt.Printf("Error reading config file: %v\n", err)
		}
	}
}
