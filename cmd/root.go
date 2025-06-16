package cmd

import (
	"github.com/spf13/cobra"
)

// Version information - will be set during build
var (
	Version   = "dev"
	BuildTime = "unknown"
)

// Global flag variables
var (
	registryURL string
	user        string
	pass        string
	apiKey      string
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "ksr-cli",
	Short: "Kafka Schema Registry CLI",
	Long: `A command-line interface for managing Kafka Schema Registry.

ksr-cli provides a comprehensive set of commands to interact with Confluent Schema Registry,
including schema management, compatibility checking, and configuration operations.

Examples:
  ksr-cli get subjects                           # List all subjects
  ksr-cli get schemas my-subject                 # Get latest schema for subject
  ksr-cli create schema my-subject -f schema.avsc  # Register new schema
  ksr-cli check compatibility my-subject -f new.avsc  # Check compatibility
  ksr-cli config set registry-url http://localhost:8081  # Configure registry URL
  ksr-cli get mode                               # Get global mode
  ksr-cli set mode READONLY                      # Set global mode to read-only

Configuration:
  Use 'ksr-cli config' commands to manage your CLI configuration including
  registry URL, authentication, and default output formats.`,
	Version: Version,
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	// Set version template to include build time
	rootCmd.SetVersionTemplate(`{{printf "%s version %s\n" .Name .Version}}{{printf "Built at: %s\n" "` + BuildTime + `"}}`)

	// Add global flags
	rootCmd.PersistentFlags().Bool("verbose", false, "Enable verbose logging")
	rootCmd.PersistentFlags().Bool("insecure", false, "Skip TLS certificate verification")

	// Add authentication and connection flags
	rootCmd.PersistentFlags().StringVar(&registryURL, "registry-url", "", "Schema Registry instance URL (overrides config)")
	rootCmd.PersistentFlags().StringVar(&user, "user", "", "Username for authentication (overrides config)")
	rootCmd.PersistentFlags().StringVar(&pass, "pass", "", "Password for authentication (overrides config)")
	rootCmd.PersistentFlags().StringVar(&apiKey, "api-key", "", "API key for authentication (overrides config)")
}
