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

// createCmd represents the create command
var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create resources in Schema Registry",
	Long: `Create various resources in the Schema Registry including schemas.

Examples:
  ksr-cli create schema my-subject --file schema.avsc
  ksr-cli create schema my-subject --schema '{"type":"record","name":"User","fields":[{"name":"id","type":"int"}]}'
  ksr-cli create schema my-subject --file schema.json --type JSON`,
}

var createSchemaCmd = &cobra.Command{
	Use:   "schema SUBJECT",
	Short: "Create/register a new schema",
	Long: `Register a new schema version for a subject.

The schema can be provided via:
  - File using --file flag
  - Inline using --schema flag
  - Standard input (if neither flag is provided)

Examples:
  ksr-cli create schema my-subject --file schema.avsc
  ksr-cli create schema my-subject --schema '{"type":"string"}'
  cat schema.avsc | ksr-cli create schema my-subject`,
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

		// Register schema
		effectiveContext := config.GetEffectiveContext(context)
		result, err := c.RegisterSchema(subject, schemaReq, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to register schema: %w", err)
		}

		// Get the actual output format from the command flag
		actualOutputFormat, _ := cmd.Flags().GetString("output")

		// Only print user-friendly messages when output format is table
		// For structured formats (json/yaml), send messages to stderr to avoid breaking parsing
		if actualOutputFormat == "table" {
			fmt.Printf("Schema registered successfully with ID: %d\n", result.ID)
		} else {
			// For structured output, send user messages to stderr
			fmt.Fprintf(os.Stderr, "Schema registered successfully with ID: %d\n", result.ID)
		}

		return output.Print(result, actualOutputFormat)
	},
}

func init() {
	rootCmd.AddCommand(createCmd)
	createCmd.AddCommand(createSchemaCmd)

	// Flags for schema creation
	createSchemaCmd.Flags().StringVarP(&schemaFile, "file", "f", "", "Schema file path")
	createSchemaCmd.Flags().StringVar(&schemaString, "schema", "", "Schema content as string")
	createSchemaCmd.Flags().StringVarP(&schemaType, "type", "t", "AVRO", "Schema type (AVRO, JSON, PROTOBUF)")
	createSchemaCmd.Flags().StringVar(&context, "context", "", "Schema Registry context")
	createSchemaCmd.Flags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
