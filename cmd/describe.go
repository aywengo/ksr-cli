package cmd

import (
	"encoding/json"
	"fmt"

	"github.com/aywengo/ksr-cli/internal/client"
	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
)

// describeCmd represents the describe command
var describeCmd = &cobra.Command{
	Use:   "describe [SUBJECT]",
	Short: "Describe Schema Registry, contexts, or subjects",
	Long: func() string {
		return fmt.Sprintf(`Describe various resources in the Schema Registry with comprehensive information.

Without arguments, describes the Schema Registry instance itself.
With --context flag, describes the specified context.
With a subject name, describes the specific subject.

Examples:
  %s describe                           # Describe Schema Registry instance
  %s describe --context production      # Describe production context
  %s describe my-subject                # Describe a specific subject
  %s describe user-value --context dev  # Describe subject in dev context`, cmdName, cmdName, cmdName, cmdName)
	}(),
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		// If subject is provided, describe subject
		if len(args) > 0 {
			return describeSubject(c, args[0], cmd)
		}

		// If context flag is provided, describe context
		if context != "" {
			return describeContext(c, context, cmd)
		}

		// Otherwise, describe the registry itself
		return describeRegistry(c, cmd)
	},
}

// describeRegistry describes the Schema Registry instance
func describeRegistry(c *client.Client, cmd *cobra.Command) error {
	effectiveContext := config.GetEffectiveContext("")
	registryURL := getEffectiveRegistryURL()

	description := &client.RegistryDescription{
		URL: registryURL,
	}

	// Check if registry is accessible
	if err := c.Ping(); err != nil {
		description.IsAccessible = false
		// Still try to output what we can
		return output.Print(description, outputFormat)
	}
	description.IsAccessible = true

	// Get registry info
	if info, err := c.GetRegistryInfo(); err == nil {
		description.Info = info
	}

	// Get subjects count
	if subjects, err := c.GetSubjects(effectiveContext); err == nil {
		description.SubjectCount = len(subjects)
	}

	// Get contexts
	if contexts, err := c.GetContexts(); err == nil {
		description.Contexts = contexts
	}

	// Get global config
	if globalConfig, err := c.GetGlobalConfig(effectiveContext); err == nil {
		description.GlobalConfig = globalConfig
	}

	// Get global mode
	if globalMode, err := c.GetGlobalMode(effectiveContext); err == nil {
		description.GlobalMode = globalMode
	}

	return output.Print(description, outputFormat)
}

// describeContext describes a specific context
func describeContext(c *client.Client, contextName string, cmd *cobra.Command) error {
	description := &client.ContextDescription{
		Name: contextName,
	}

	// Get subjects in this context
	subjects, err := c.GetSubjects(contextName)
	if err != nil {
		return fmt.Errorf("failed to get subjects for context %s: %w", contextName, err)
	}

	description.SubjectCount = len(subjects)
	description.Subjects = subjects

	// Get context config
	if config, err := c.GetGlobalConfig(contextName); err == nil {
		description.Config = config
	}

	// Get context mode
	if mode, err := c.GetGlobalMode(contextName); err == nil {
		description.Mode = mode
	}

	return output.Print(description, outputFormat)
}

// describeSubject describes a specific subject
func describeSubject(c *client.Client, subject string, cmd *cobra.Command) error {
	effectiveContext := config.GetEffectiveContext(context)

	description := &client.SubjectDescription{
		Name: subject,
	}

	// Get subject versions
	versions, err := c.GetSubjectVersions(subject, effectiveContext)
	if err != nil {
		return fmt.Errorf("failed to get versions for subject %s: %w", subject, err)
	}
	description.Versions = versions

	if len(versions) > 0 {
		// Get latest version
		latestVersion := versions[len(versions)-1]
		description.LatestVersion = latestVersion

		// Get latest schema
		if schema, err := c.GetSchema(subject, "latest", effectiveContext); err == nil {
			description.LatestSchema = schema
			description.SchemaType = schema.Type

			// Analyze schema fields
			if fieldInfo := analyzeSchemaFields(schema); fieldInfo != nil {
				description.FieldCount = fieldInfo.FieldCount
			}
		}
	}

	// Get subject config
	if config, err := c.GetSubjectConfig(subject, effectiveContext); err == nil {
		description.Config = config
	}

	// Get subject mode
	if mode, err := c.GetSubjectMode(subject, effectiveContext); err == nil {
		description.Mode = mode
	}

	// Generate suggested commands
	description.SuggestedCommands = generateSuggestedCommands(subject, effectiveContext)

	return output.Print(description, outputFormat)
}

// analyzeSchemaFields analyzes schema to extract field information
func analyzeSchemaFields(schema *client.Schema) *client.SchemaFieldInfo {
	if schema == nil || len(schema.Schema) == 0 {
		return nil
	}

	// Try to parse the schema JSON to count fields
	var schemaObj map[string]interface{}
	if err := json.Unmarshal(schema.Schema, &schemaObj); err != nil {
		return nil
	}

	fieldInfo := &client.SchemaFieldInfo{}

	// For AVRO schemas
	if fields, ok := schemaObj["fields"].([]interface{}); ok {
		fieldInfo.FieldCount = len(fields)

		// Extract field names
		for _, field := range fields {
			if fieldMap, ok := field.(map[string]interface{}); ok {
				if name, ok := fieldMap["name"].(string); ok {
					fieldInfo.FieldNames = append(fieldInfo.FieldNames, name)
				}
			}
		}
	} else if properties, ok := schemaObj["properties"].(map[string]interface{}); ok {
		// For JSON schemas
		fieldInfo.FieldCount = len(properties)
		for name := range properties {
			fieldInfo.FieldNames = append(fieldInfo.FieldNames, name)
		}
	}

	return fieldInfo
}

// generateSuggestedCommands generates helpful commands for the user
func generateSuggestedCommands(subject, context string) []string {
	commands := []string{}
	contextFlag := ""
	if context != "" {
		contextFlag = fmt.Sprintf(" --context %s", context)
	}

	commands = append(commands,
		fmt.Sprintf("%s get schemas %s%s", cmdName, subject, contextFlag),
		fmt.Sprintf("%s get versions %s%s", cmdName, subject, contextFlag),
		fmt.Sprintf("%s export subject %s%s -f %s.json", cmdName, subject, contextFlag, subject),
		fmt.Sprintf("%s check compatibility %s --file new-schema.avsc%s", cmdName, subject, contextFlag),
		fmt.Sprintf("%s config get --subject %s%s", cmdName, subject, contextFlag),
	)

	return commands
}

func init() {
	rootCmd.AddCommand(describeCmd)

	// Add flags
	describeCmd.Flags().StringVar(&context, "context", "", "Schema Registry context")
	describeCmd.Flags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
