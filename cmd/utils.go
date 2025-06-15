package cmd

import (
	"fmt"
	"io"
	"os"
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
