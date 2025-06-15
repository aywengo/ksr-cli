package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/aywengo/ksr-cli/internal/client"
	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
)

var (
	exportFile        string
	exportAllVersions bool
	exportDirectory   string
	includeConfig     bool
)

// ExportData represents the structure for exported data
type ExportData struct {
	Metadata ExportMetadata    `json:"metadata"`
	Subjects []ExportedSubject `json:"subjects"`
	Config   *client.Config    `json:"config,omitempty"`
}

type ExportMetadata struct {
	ExportedAt string `json:"exported_at"`
	Context    string `json:"context,omitempty"`
	Registry   string `json:"registry_url,omitempty"`
	Version    string `json:"cli_version"`
}

type ExportedSubject struct {
	Name     string           `json:"name"`
	Versions []ExportedSchema `json:"versions"`
	Config   *client.Config   `json:"config,omitempty"`
}

type ExportedSchema struct {
	ID         int                `json:"id"`
	Version    int                `json:"version"`
	Schema     json.RawMessage    `json:"schema"`
	SchemaType string             `json:"schema_type,omitempty"`
	References []client.Reference `json:"references,omitempty"`
}

// exportCmd represents the export command
var exportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export schemas and subjects from Schema Registry",
	Long: `Export schemas and subjects from the Schema Registry to files.

Examples:
  ksr-cli export subjects                          # Export all subjects to stdout
  ksr-cli export subjects -f subjects.json        # Export all subjects to file
  ksr-cli export subjects --all-versions          # Export all versions of all subjects
  ksr-cli export subject my-subject               # Export specific subject
  ksr-cli export subject my-subject --all-versions # Export all versions of subject
  ksr-cli export subjects --directory ./exports   # Export each subject to separate files`,
}

var exportSubjectsCmd = &cobra.Command{
	Use:   "subjects",
	Short: "Export all subjects",
	Long: `Export all subjects from the Schema Registry.

This command exports all subjects and their schemas. By default, only the latest version
of each schema is exported. Use --all-versions to export all versions.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)

		// Get all subjects
		subjects, err := c.GetSubjects(effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to get subjects: %w", err)
		}

		// Export to directory if specified
		if exportDirectory != "" {
			return exportSubjectsToDirectory(c, subjects, effectiveContext)
		}

		// Export all subjects to single file/stdout
		exportData, err := buildExportData(c, subjects, effectiveContext)
		if err != nil {
			return err
		}

		return writeExportData(exportData)
	},
}

var exportSubjectCmd = &cobra.Command{
	Use:   "subject SUBJECT_NAME",
	Short: "Export a specific subject",
	Long: `Export a specific subject and its schemas.

By default, only the latest version is exported. Use --all-versions to export all versions.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		subject := args[0]
		effectiveContext := config.GetEffectiveContext(context)

		// Export single subject
		exportData, err := buildExportData(c, []string{subject}, effectiveContext)
		if err != nil {
			return err
		}

		return writeExportData(exportData)
	},
}

func buildExportData(c *client.Client, subjects []string, effectiveContext string) (*ExportData, error) {
	exportData := &ExportData{
		Metadata: ExportMetadata{
			ExportedAt: time.Now().Format(time.RFC3339),
			Context:    effectiveContext,
			Version:    Version,
		},
		Subjects: make([]ExportedSubject, 0, len(subjects)),
	}

	// Get global config if requested
	if includeConfig {
		globalConfig, err := c.GetGlobalConfig(effectiveContext)
		if err == nil {
			exportData.Config = globalConfig
		}
	}

	// Process each subject
	for _, subject := range subjects {
		exportedSubject, err := exportSubject(c, subject, effectiveContext)
		if err != nil {
			return nil, fmt.Errorf("failed to export subject %s: %w", subject, err)
		}
		exportData.Subjects = append(exportData.Subjects, *exportedSubject)
	}

	return exportData, nil
}

func exportSubject(c *client.Client, subject string, effectiveContext string) (*ExportedSubject, error) {
	exportedSubject := &ExportedSubject{
		Name:     subject,
		Versions: make([]ExportedSchema, 0),
	}

	// Get subject config if requested
	if includeConfig {
		subjectConfig, err := c.GetSubjectConfig(subject, effectiveContext)
		if err == nil {
			exportedSubject.Config = subjectConfig
		}
	}

	if exportAllVersions {
		// Get all versions
		versions, err := c.GetSubjectVersions(subject, effectiveContext)
		if err != nil {
			return nil, fmt.Errorf("failed to get versions for subject %s: %w", subject, err)
		}

		// Get each version
		for _, version := range versions {
			schema, err := c.GetSchema(subject, fmt.Sprintf("%d", version), effectiveContext)
			if err != nil {
				return nil, fmt.Errorf("failed to get schema version %d for subject %s: %w", version, subject, err)
			}

			exportedSchema := ExportedSchema{
				ID:         schema.ID,
				Version:    schema.Version,
				Schema:     schema.Schema,
				SchemaType: schema.Type,
				References: schema.References,
			}
			exportedSubject.Versions = append(exportedSubject.Versions, exportedSchema)
		}
	} else {
		// Get only latest version
		schema, err := c.GetSchema(subject, "latest", effectiveContext)
		if err != nil {
			return nil, fmt.Errorf("failed to get latest schema for subject %s: %w", subject, err)
		}

		exportedSchema := ExportedSchema{
			ID:         schema.ID,
			Version:    schema.Version,
			Schema:     schema.Schema,
			SchemaType: schema.Type,
			References: schema.References,
		}
		exportedSubject.Versions = append(exportedSubject.Versions, exportedSchema)
	}

	return exportedSubject, nil
}

func exportSubjectsToDirectory(c *client.Client, subjects []string, effectiveContext string) error {
	// Create directory if it doesn't exist
	if err := os.MkdirAll(exportDirectory, 0755); err != nil {
		return fmt.Errorf("failed to create export directory: %w", err)
	}

	// Export each subject to its own file
	for _, subject := range subjects {
		exportData, err := buildExportData(c, []string{subject}, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to export subject %s: %w", subject, err)
		}

		filename := filepath.Join(exportDirectory, fmt.Sprintf("%s.json", subject))
		file, err := os.Create(filename)
		if err != nil {
			return fmt.Errorf("failed to create file %s: %w", filename, err)
		}

		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(exportData); err != nil {
			file.Close()
			return fmt.Errorf("failed to write to file %s: %w", filename, err)
		}
		file.Close()

		fmt.Printf("Exported subject '%s' to %s\n", subject, filename)
	}

	return nil
}

func writeExportData(exportData *ExportData) error {
	if exportFile != "" {
		file, err := os.Create(exportFile)
		if err != nil {
			return fmt.Errorf("failed to create export file: %w", err)
		}
		defer file.Close()

		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(exportData); err != nil {
			return fmt.Errorf("failed to write export data: %w", err)
		}

		fmt.Printf("Exported data to %s\n", exportFile)
		return nil
	}

	// Output to stdout
	return output.Print(exportData, outputFormat)
}

func init() {
	rootCmd.AddCommand(exportCmd)

	// Add subcommands
	exportCmd.AddCommand(exportSubjectsCmd)
	exportCmd.AddCommand(exportSubjectCmd)

	// Flags for export commands
	exportCmd.PersistentFlags().StringVarP(&exportFile, "file", "f", "", "Output file (default: stdout)")
	exportCmd.PersistentFlags().BoolVar(&exportAllVersions, "all-versions", false, "Export all versions of schemas")
	exportCmd.PersistentFlags().StringVar(&exportDirectory, "directory", "", "Export each subject to separate files in directory")
	exportCmd.PersistentFlags().BoolVar(&includeConfig, "include-config", true, "Include configuration in export")

	// Global flags
	exportCmd.PersistentFlags().StringVar(&context, "context", "", "Schema Registry context")
	exportCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "json", "Output format (json, yaml)")
}
