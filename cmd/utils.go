package cmd

import (
	"fmt"
	"io"
	"os"

	"github.com/aywengo/ksr-cli/internal/client"
	"github.com/aywengo/ksr-cli/internal/config"
)

var (
	schemaFile   string
	schemaType   string
	schemaString string
	outputFormat string
	context      string
	version      string
)

// getSchemaContent gets schema content from file, inline, or stdin
func getSchemaContent() (string, error) {
	// Priority: inline schema -> file -> stdin
	if schemaString != "" {
		return schemaString, nil
	}

	if schemaFile != "" {
		content, err := os.ReadFile(schemaFile)
		if err != nil {
			return "", fmt.Errorf("failed to read schema file: %w", err)
		}
		return string(content), nil
	}

	// Read from stdin
	stat, err := os.Stdin.Stat()
	if err != nil {
		return "", fmt.Errorf("failed to check stdin: %w", err)
	}

	if (stat.Mode() & os.ModeCharDevice) != 0 {
		return "", fmt.Errorf("no schema provided: use --file, --schema, or pipe schema via stdin")
	}

	content, err := io.ReadAll(os.Stdin)
	if err != nil {
		return "", fmt.Errorf("failed to read from stdin: %w", err)
	}

	return string(content), nil
}

// getEffectiveRegistryURL returns the registry URL to use (flag value or configured default)
func getEffectiveRegistryURL() string {
	if registryURL != "" {
		return registryURL
	}
	return config.GetString(config.KeyRegistryURL)
}

// getEffectiveUsername returns the username to use (flag value or configured default)
func getEffectiveUsername() string {
	if user != "" {
		return user
	}
	return config.GetString(config.KeyUsername)
}

// getEffectivePassword returns the password to use (flag value or configured default)
func getEffectivePassword() string {
	if pass != "" {
		return pass
	}
	return config.GetString(config.KeyPassword)
}

// getEffectiveAPIKey returns the API key to use (flag value or configured default)
func getEffectiveAPIKey() string {
	if apiKey != "" {
		return apiKey
	}
	return config.GetString(config.KeyAPIKey)
}

// createClientWithFlags creates a client using effective configuration values (flags override config)
func createClientWithFlags() (*client.Client, error) {
	registryURL := getEffectiveRegistryURL()
	if registryURL == "" {
		return nil, fmt.Errorf("registry URL is required (use --registry-url flag or configure with 'ksr-cli config set registry-url <url>')")
	}

	return client.NewClientWithConfig(&client.ClientConfig{
		BaseURL:  registryURL,
		Username: getEffectiveUsername(),
		Password: getEffectivePassword(),
		APIKey:   getEffectiveAPIKey(),
		Timeout:  config.GetString(config.KeyTimeout),
		Insecure: config.GetBool(config.KeyInsecure),
	})
}
