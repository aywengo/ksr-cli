package cmd

import (
	"fmt"

	"github.com/aywengo/ksr-cli/internal/client"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
)

var (
	version     string
	context     string
	allVersions bool
)

var outputFormat string

// getCmd represents the get command
var getCmd = &cobra.Command{
	Use:   "get",
	Short: "Get resources from Schema Registry",
	Long: `Get various resources from the Schema Registry including schemas, subjects, versions, and configurations.

Examples:
  ksr-cli get schemas
  ksr-cli get schemas my-subject
  ksr-cli get schemas my-subject --version 2
  ksr-cli get subjects
  ksr-cli get versions my-subject
  ksr-cli get config`,
}

var getSchemasCmd = &cobra.Command{
	Use:   "schemas [SUBJECT]",
	Short: "Get schemas",
	Long: `Get all schemas or a specific schema by subject name.

Examples:
  ksr-cli get schemas                    # List all subjects
  ksr-cli get schemas my-subject         # Get latest schema for subject
  ksr-cli get schemas my-subject -v 2    # Get specific version
  ksr-cli get schemas my-subject --all   # Get all versions`,
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		if len(args) == 0 {
			// List all subjects
			subjects, err := c.GetSubjects(context)
			if err != nil {
				return fmt.Errorf("failed to get subjects: %w", err)
			}
			return output.Print(subjects, outputFormat)
		}

		subject := args[0]

		if allVersions {
			// Get all versions for subject
			versions, err := c.GetSubjectVersions(subject, context)
			if err != nil {
				return fmt.Errorf("failed to get versions for subject %s: %w", subject, err)
			}

			var schemas []interface{}
			for _, v := range versions {
				schema, err := c.GetSchema(subject, fmt.Sprintf("%d", v), context)
				if err != nil {
					return fmt.Errorf("failed to get schema version %d: %w", v, err)
				}
				schemas = append(schemas, schema)
			}
			return output.Print(schemas, outputFormat)
		}

		// Get specific version or latest
		ver := version
		if ver == "" {
			ver = "latest"
		}

		schema, err := c.GetSchema(subject, ver, context)
		if err != nil {
			return fmt.Errorf("failed to get schema: %w", err)
		}

		return output.Print(schema, outputFormat)
	},
}

var getSubjectsCmd = &cobra.Command{
	Use:   "subjects",
	Short: "Get all subjects",
	Long:  `Get a list of all subjects in the Schema Registry.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		subjects, err := c.GetSubjects(context)
		if err != nil {
			return fmt.Errorf("failed to get subjects: %w", err)
		}

		return output.Print(subjects, outputFormat)
	},
}

var getVersionsCmd = &cobra.Command{
	Use:   "versions SUBJECT",
	Short: "Get versions for a subject",
	Long:  `Get all available versions for a specific subject.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		subject := args[0]
		versions, err := c.GetSubjectVersions(subject, context)
		if err != nil {
			return fmt.Errorf("failed to get versions for subject %s: %w", subject, err)
		}

		return output.Print(versions, outputFormat)
	},
}

var getConfigCmd = &cobra.Command{
	Use:   "config [SUBJECT]",
	Short: "Get configuration",
	Long: `Get global configuration or configuration for a specific subject.

Examples:
  ksr-cli get config           # Get global configuration
  ksr-cli get config my-subject # Get subject-specific configuration`,
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		if len(args) == 0 {
			// Get global config
			config, err := c.GetGlobalConfig(context)
			if err != nil {
				return fmt.Errorf("failed to get global config: %w", err)
			}
			return output.Print(config, outputFormat)
		}

		// Get subject config
		subject := args[0]
		config, err := c.GetSubjectConfig(subject, context)
		if err != nil {
			return fmt.Errorf("failed to get config for subject %s: %w", subject, err)
		}

		return output.Print(config, outputFormat)
	},
}

func init() {
	rootCmd.AddCommand(getCmd)

	// Add subcommands
	getCmd.AddCommand(getSchemasCmd)
	getCmd.AddCommand(getSubjectsCmd)
	getCmd.AddCommand(getVersionsCmd)
	getCmd.AddCommand(getConfigCmd)

	// Flags for schemas command
	getSchemasCmd.Flags().StringVarP(&version, "version", "V", "", "Schema version")
	getSchemasCmd.Flags().BoolVar(&allVersions, "all", false, "Get all versions")

	// Global flags for all get commands
	getCmd.PersistentFlags().StringVar(&context, "context", "", "Schema Registry context")
	getCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
