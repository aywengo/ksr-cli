package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/aywengo/ksr-cli/internal/client"
	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
)

// checkCmd represents the check command
var checkCmd = &cobra.Command{
	Use:   "check",
	Short: "Check schema compatibility and validation",
	Long: `Check various aspects of schemas including compatibility with existing versions
and validation of schema syntax.

Examples:
  ksr-cli check compatibility my-subject --file new-schema.avsc
  ksr-cli check compatibility my-subject --schema '{"type":"string"}'`,
}

var checkCompatibilityCmd = &cobra.Command{
	Use:   "compatibility SUBJECT",
	Short: "Check schema compatibility",
	Long: `Check if a schema is compatible with the latest version of a subject.

The schema can be provided via:
  - File using --file flag
  - Inline using --schema flag
  - Standard input (if neither flag is provided)

Examples:
  ksr-cli check compatibility my-subject --file new-schema.avsc
  ksr-cli check compatibility my-subject --schema '{"type":"string"}'
  ksr-cli check compatibility my-subject --version 2 --file new-schema.avsc
  cat new-schema.avsc | ksr-cli check compatibility my-subject`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		subject := args[0]

		// Get schema content
		schemaContent, err := getSchemaContent()
		if err != nil {
			return fmt.Errorf("failed to get schema content: %w", err)
		}

		// Validate schema content is valid JSON
		var schemaObj interface{}
		if err := json.Unmarshal([]byte(schemaContent), &schemaObj); err != nil {
			return fmt.Errorf("invalid schema JSON: %w", err)
		}

		// Create client
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		// Prepare schema request
		schemaReq := &client.SchemaRequest{
			Schema:     schemaContent,
			SchemaType: schemaType,
		}

		// Check compatibility
		effectiveContext := config.GetEffectiveContext(context)

		// Use version if specified, otherwise check against latest
		var result *client.CompatibilityResponse
		if version != "" {
			result, err = c.CheckCompatibilityWithVersion(subject, version, schemaReq, effectiveContext)
		} else {
			result, err = c.CheckCompatibility(subject, schemaReq, effectiveContext)
		}

		if err != nil {
			return fmt.Errorf("failed to check compatibility: %w", err)
		}

		// Get the actual output format from the command flag
		actualOutputFormat, _ := cmd.Flags().GetString("output")

		// Only print user-friendly messages when output format is table
		// For structured formats (json/yaml), send messages to stderr to avoid breaking parsing
		if actualOutputFormat == "table" {
			if result.IsCompatible {
				fmt.Printf("✅ Schema is compatible with subject '%s'\n", subject)
			} else {
				fmt.Printf("❌ Schema is NOT compatible with subject '%s'\n", subject)
				if len(result.Messages) > 0 {
					fmt.Println("Compatibility issues:")
					for _, msg := range result.Messages {
						fmt.Printf("  • %s\n", msg)
					}
				}
			}
		} else {
			// For structured output, send user messages to stderr
			if result.IsCompatible {
				fmt.Fprintf(os.Stderr, "✅ Schema is compatible with subject '%s'\n", subject)
			} else {
				fmt.Fprintf(os.Stderr, "❌ Schema is NOT compatible with subject '%s'\n", subject)
				if len(result.Messages) > 0 {
					fmt.Fprintln(os.Stderr, "Compatibility issues:")
					for _, msg := range result.Messages {
						fmt.Fprintf(os.Stderr, "  • %s\n", msg)
					}
				}
			}
		}

		return output.Print(result, actualOutputFormat)
	},
}

func init() {
	rootCmd.AddCommand(checkCmd)
	checkCmd.AddCommand(checkCompatibilityCmd)

	// Flags for compatibility check
	checkCompatibilityCmd.Flags().StringVarP(&schemaFile, "file", "f", "", "Schema file path")
	checkCompatibilityCmd.Flags().StringVar(&schemaString, "schema", "", "Schema content as string")
	checkCompatibilityCmd.Flags().StringVarP(&schemaType, "type", "t", "AVRO", "Schema type (AVRO, JSON, PROTOBUF)")
	checkCompatibilityCmd.Flags().StringVar(&context, "context", "", "Schema Registry context")
	checkCompatibilityCmd.Flags().StringVarP(&version, "version", "V", "", "Check compatibility against specific version (default: latest)")
	checkCompatibilityCmd.Flags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
