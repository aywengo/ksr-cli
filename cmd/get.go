package cmd

import (
	"fmt"

	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
)

var (
	allVersions bool
)

// getCmd represents the get command
var getCmd = &cobra.Command{
	Use:   "get",
	Short: "Get resources from Schema Registry",
	Long: func() string {
		return fmt.Sprintf(`Get various resources from the Schema Registry including schemas, subjects, versions, and configurations.

Examples:
  %s get schemas
  %s get schemas my-subject
  %s get schemas my-subject --version 2
  %s get subjects
  %s get versions my-subject
  %s get config`, cmdName, cmdName, cmdName, cmdName, cmdName, cmdName)
	}(),
}

var getSchemasCmd = &cobra.Command{
	Use:   "schemas [SUBJECT]",
	Short: "Get schemas",
	Long: func() string {
		return fmt.Sprintf(`Get all schemas or a specific schema by subject name.

Examples:
  %s get schemas                         # List all subjects
  %s get schemas my-subject              # Get latest schema for subject
  %s get schemas my-subject -v 2         # Get specific version
  %s get schemas my-subject --all        # Get all versions
  %s get schemas my-subject --all-versions # Get all versions`, cmdName, cmdName, cmdName, cmdName, cmdName)
	}(),
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)

		if len(args) == 0 {
			// List all subjects
			subjects, err := c.GetSubjects(effectiveContext)
			if err != nil {
				return fmt.Errorf("failed to get subjects: %w", err)
			}
			return output.Print(subjects, outputFormat)
		}

		subject := args[0]

		if allVersions {
			// Get all versions for subject
			versions, err := c.GetSubjectVersions(subject, effectiveContext)
			if err != nil {
				return fmt.Errorf("failed to get versions for subject %s: %w", subject, err)
			}

			var schemas []interface{}
			for _, v := range versions {
				schema, err := c.GetSchema(subject, fmt.Sprintf("%d", v), effectiveContext)
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

		schema, err := c.GetSchema(subject, ver, effectiveContext)
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
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)
		subjects, err := c.GetSubjects(effectiveContext)
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
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		subject := args[0]
		effectiveContext := config.GetEffectiveContext(context)
		versions, err := c.GetSubjectVersions(subject, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to get versions for subject %s: %w", subject, err)
		}

		return output.Print(versions, outputFormat)
	},
}

var getConfigCmd = &cobra.Command{
	Use:   "config [SUBJECT]",
	Short: "Get configuration",
	Long: func() string {
		return fmt.Sprintf(`Get global configuration or configuration for a specific subject.

Examples:
  %s get config           # Get global configuration
  %s get config my-subject # Get subject-specific configuration`, cmdName, cmdName)
	}(),
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)

		if len(args) == 0 {
			// Get global config
			config, err := c.GetGlobalConfig(effectiveContext)
			if err != nil {
				return fmt.Errorf("failed to get global config: %w", err)
			}
			return output.Print(config, outputFormat)
		}

		// Get subject config
		subject := args[0]
		config, err := c.GetSubjectConfig(subject, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to get config for subject %s: %w", subject, err)
		}

		return output.Print(config, outputFormat)
	},
}

var getModeCmd = &cobra.Command{
	Use:   "mode [SUBJECT]",
	Short: "Get mode configuration",
	Long: func() string {
		return fmt.Sprintf(`Get global mode or mode for a specific subject.

The mode controls the behavior of the Schema Registry:
- READWRITE: Normal operation (default)
- READONLY: Only read operations are allowed
- IMPORT: Schema Registry is in import mode

Examples:
  %s get mode           # Get global mode
  %s get mode my-subject # Get subject-specific mode`, cmdName, cmdName)
	}(),
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)

		if len(args) == 0 {
			// Get global mode
			mode, err := c.GetGlobalMode(effectiveContext)
			if err != nil {
				return fmt.Errorf("failed to get global mode: %w", err)
			}
			return output.Print(mode, outputFormat)
		}

		// Get subject mode
		subject := args[0]
		mode, err := c.GetSubjectMode(subject, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to get mode for subject %s: %w", subject, err)
		}

		return output.Print(mode, outputFormat)
	},
}

func init() {
	rootCmd.AddCommand(getCmd)

	// Add subcommands
	getCmd.AddCommand(getSchemasCmd)
	getCmd.AddCommand(getSubjectsCmd)
	getCmd.AddCommand(getVersionsCmd)
	getCmd.AddCommand(getConfigCmd)
	getCmd.AddCommand(getModeCmd)

	// Flags for schemas command
	getSchemasCmd.Flags().StringVarP(&version, "version", "V", "", "Schema version")
	getSchemasCmd.Flags().BoolVar(&allVersions, "all", false, "Get all versions")
	getSchemasCmd.Flags().BoolVar(&allVersions, "all-versions", false, "Get all versions (alias for --all)")

	// Global flags for all get commands
	getCmd.PersistentFlags().StringVar(&context, "context", "", "Schema Registry context")
	getCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
