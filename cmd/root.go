package cmd

import (
	"fmt"
	"strings"

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

// cmdName holds the detected binary name for dynamic examples
var cmdName = "ksr-cli"

// SetBinaryName sets the command name based on how it was invoked
func SetBinaryName(name string) {
	// If the binary is invoked as "ksr", use that in examples
	// Otherwise default to "ksr-cli"
	if strings.HasSuffix(name, "ksr") && !strings.HasSuffix(name, "ksr-cli") {
		cmdName = "ksr"
	}
}

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   cmdName,
	Short: "Kafka Schema Registry CLI",
	Long: fmt.Sprintf(`A command-line interface for managing Kafka Schema Registry.

%s provides a comprehensive set of commands to interact with Confluent Schema Registry,
including schema management, compatibility checking, and configuration operations.

Examples:
  %s describe                               # Describe Schema Registry instance
  %s describe my-subject                    # Describe a specific subject
  %s get subjects                           # List all subjects
  %s get schemas my-subject                 # Get latest schema for subject
  %s create schema my-subject -f schema.avsc  # Register new schema
  %s check compatibility my-subject -f new.avsc  # Check compatibility
  %s config set registry-url http://localhost:8081  # Configure registry URL
  %s get mode                               # Get global mode
  %s set mode READONLY                      # Set global mode to read-only

Configuration:
  Use 'ksr-cli config' commands to manage your CLI configuration including
  registry URL, authentication, and default output formats.`, cmdName, cmdName, cmdName, cmdName, cmdName, cmdName, cmdName, cmdName, cmdName, cmdName),
	Version: Version,
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() error {
	// Update the Use field with the detected command name
	rootCmd.Use = cmdName
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
