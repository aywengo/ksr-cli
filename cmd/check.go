package cmd

import (
	"encoding/json"
	"fmt"

	"github.com/aywengo/ksr-cli/internal/client"
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
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		// Prepare schema request
		schemaReq := &client.SchemaRequest{
			Schema:     schemaContent,
			SchemaType: schemaType,
		}

		// Check compatibility
		result, err := c.CheckCompatibility(subject, schemaReq, context)
		if err != nil {
			return fmt.Errorf("failed to check compatibility: %w", err)
		}

		// Print user-friendly message
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

		return output.Print(result, outputFormat)
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
	checkCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
