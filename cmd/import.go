package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/aywengo/ksr-cli/internal/client"
	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/spf13/cobra"
)

var (
	importFile      string
	importDirectory string
	dryRun          bool
	skipExisting    bool
	forceImport     bool
	importContext   string
)

// ImportResult represents the result of an import operation
type ImportResult struct {
	Subject  string `json:"subject"`
	Version  int    `json:"version"`
	SchemaID int    `json:"schema_id"`
	Status   string `json:"status"` // "created", "existing", "error", "skipped"
	Error    string `json:"error,omitempty"`
}

// ImportSummary represents the summary of import operation
type ImportSummary struct {
	Total    int            `json:"total"`
	Created  int            `json:"created"`
	Existing int            `json:"existing"`
	Errors   int            `json:"errors"`
	Skipped  int            `json:"skipped"`
	Results  []ImportResult `json:"results"`
}

// importCmd represents the import command
var importCmd = &cobra.Command{
	Use:   "import",
	Short: "Import schemas and subjects into Schema Registry",
	Long: `Import schemas and subjects into the Schema Registry from files.

Examples:
  ksr-cli import subjects -f subjects.json       # Import subjects from file
  ksr-cli import subjects --directory ./exports  # Import all subjects from directory
  ksr-cli import subject -f subject.json        # Import single subject from file
  ksr-cli import subjects -f subjects.json --dry-run    # Preview import without changes
  ksr-cli import subjects -f subjects.json --skip-existing # Skip existing schemas`,
}

var importSubjectsCmd = &cobra.Command{
	Use:   "subjects",
	Short: "Import all subjects",
	Long: `Import all subjects from export file or directory.

This command imports subjects and their schemas. By default, it will attempt to register
all schemas. Use --skip-existing to skip schemas that already exist, or --dry-run to 
preview the changes without applying them.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		if importDirectory != "" {
			return importFromDirectory(c)
		}

		if importFile == "" {
			return fmt.Errorf("either --file or --directory must be specified")
		}

		return importFromFile(c, importFile)
	},
}

var importSubjectCmd = &cobra.Command{
	Use:   "subject",
	Short: "Import a specific subject",
	Long: `Import a specific subject from export file.

This command imports a single subject and its schemas from an export file.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := client.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		if importFile == "" {
			return fmt.Errorf("--file must be specified")
		}

		return importFromFile(c, importFile)
	},
}

func importFromFile(c *client.Client, filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return fmt.Errorf("failed to open import file: %w", err)
	}
	defer file.Close()

	var exportData ExportData
	if err := json.NewDecoder(file).Decode(&exportData); err != nil {
		return fmt.Errorf("failed to decode import file: %w", err)
	}

	return processImport(c, &exportData, filename)
}

func importFromDirectory(c *client.Client) error {
	files, err := filepath.Glob(filepath.Join(importDirectory, "*.json"))
	if err != nil {
		return fmt.Errorf("failed to find import files: %w", err)
	}

	if len(files) == 0 {
		return fmt.Errorf("no JSON files found in directory %s", importDirectory)
	}

	var allResults []ImportResult
	totalSummary := ImportSummary{}

	for _, file := range files {
		fmt.Printf("Processing file: %s\n", file)

		exportData, err := loadExportFile(file)
		if err != nil {
			fmt.Printf("Error loading file %s: %v\n", file, err)
			continue
		}

		summary, err := processImportWithSummary(c, exportData, file)
		if err != nil {
			fmt.Printf("Error importing from file %s: %v\n", file, err)
			continue
		}

		// Aggregate results
		totalSummary.Total += summary.Total
		totalSummary.Created += summary.Created
		totalSummary.Existing += summary.Existing
		totalSummary.Errors += summary.Errors
		totalSummary.Skipped += summary.Skipped
		allResults = append(allResults, summary.Results...)
	}

	totalSummary.Results = allResults
	return printImportSummary(&totalSummary)
}

func loadExportFile(filename string) (*ExportData, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	var exportData ExportData
	if err := json.NewDecoder(file).Decode(&exportData); err != nil {
		return nil, fmt.Errorf("failed to decode file: %w", err)
	}

	return &exportData, nil
}

func processImport(c *client.Client, exportData *ExportData, source string) error {
	summary, err := processImportWithSummary(c, exportData, source)
	if err != nil {
		return err
	}

	return printImportSummary(summary)
}

func processImportWithSummary(c *client.Client, exportData *ExportData, source string) (*ImportSummary, error) {
	effectiveContext := config.GetEffectiveContext(getImportContext(exportData))

	summary := &ImportSummary{
		Results: make([]ImportResult, 0),
	}

	if dryRun {
		fmt.Printf("DRY RUN: Would import %d subjects from %s\n", len(exportData.Subjects), source)
	}

	// Import global config if present and not in dry-run mode
	if exportData.Config != nil && !dryRun {
		if err := importGlobalConfig(c, exportData.Config, effectiveContext); err != nil {
			fmt.Printf("Warning: failed to import global config: %v\n", err)
		}
	}

	// Process each subject
	for _, subject := range exportData.Subjects {
		subjectResults := importSubjectData(c, &subject, effectiveContext)
		summary.Results = append(summary.Results, subjectResults...)
	}

	// Calculate summary statistics
	for _, result := range summary.Results {
		summary.Total++
		switch result.Status {
		case "created":
			summary.Created++
		case "existing":
			summary.Existing++
		case "error":
			summary.Errors++
		case "skipped":
			summary.Skipped++
		}
	}

	return summary, nil
}

func importSubjectData(c *client.Client, subject *ExportedSubject, effectiveContext string) []ImportResult {
	var results []ImportResult

	// Import subject config if present and not in dry-run mode
	if subject.Config != nil && !dryRun {
		if err := importSubjectConfig(c, subject.Name, subject.Config, effectiveContext); err != nil {
			fmt.Printf("Warning: failed to import config for subject %s: %v\n", subject.Name, err)
		}
	}

	// Sort versions to import in order
	for _, schema := range subject.Versions {
		result := importSchema(c, subject.Name, &schema, effectiveContext)
		results = append(results, result)
	}

	return results
}

func importSchema(c *client.Client, subjectName string, schema *ExportedSchema, effectiveContext string) ImportResult {
	result := ImportResult{
		Subject: subjectName,
		Version: schema.Version,
	}

	if dryRun {
		result.Status = "skipped"
		return result
	}

	// Check if schema already exists
	if skipExisting {
		existingSchema, err := c.GetSchema(subjectName, fmt.Sprintf("%d", schema.Version), effectiveContext)
		if err == nil && existingSchema != nil {
			result.Status = "existing"
			result.SchemaID = existingSchema.ID
			return result
		}
	}

	// Prepare schema request
	schemaReq := &client.SchemaRequest{
		Schema:     string(schema.Schema),
		SchemaType: schema.SchemaType,
		References: schema.References,
	}

	// Register schema
	response, err := c.RegisterSchema(subjectName, schemaReq, effectiveContext)
	if err != nil {
		result.Status = "error"
		result.Error = err.Error()
		return result
	}

	result.Status = "created"
	result.SchemaID = response.ID
	return result
}

func importGlobalConfig(c *client.Client, config *client.Config, effectiveContext string) error {
	fmt.Printf("Importing global config...\n")
	_, err := c.SetGlobalConfig(config, effectiveContext)
	if err != nil {
		return fmt.Errorf("failed to set global config: %w", err)
	}
	fmt.Printf("Global config imported successfully\n")
	return nil
}

func importSubjectConfig(c *client.Client, subject string, config *client.Config, effectiveContext string) error {
	fmt.Printf("Importing config for subject %s...\n", subject)
	_, err := c.SetSubjectConfig(subject, config, effectiveContext)
	if err != nil {
		return fmt.Errorf("failed to set config for subject %s: %w", subject, err)
	}
	fmt.Printf("Config for subject %s imported successfully\n", subject)
	return nil
}

func getImportContext(exportData *ExportData) string {
	if importContext != "" {
		return importContext
	}
	if exportData.Metadata.Context != "" {
		return exportData.Metadata.Context
	}
	return context
}

func printImportSummary(summary *ImportSummary) error {
	fmt.Printf("\nImport Summary:\n")
	fmt.Printf("Total: %d\n", summary.Total)
	fmt.Printf("Created: %d\n", summary.Created)
	fmt.Printf("Existing: %d\n", summary.Existing)
	fmt.Printf("Errors: %d\n", summary.Errors)
	fmt.Printf("Skipped: %d\n", summary.Skipped)

	if summary.Errors > 0 {
		fmt.Printf("\nErrors:\n")
		for _, result := range summary.Results {
			if result.Status == "error" {
				fmt.Printf("  %s v%d: %s\n", result.Subject, result.Version, result.Error)
			}
		}
	}

	// Show detailed results if verbose or if there are errors
	if len(summary.Results) <= 20 || summary.Errors > 0 {
		fmt.Printf("\nDetailed Results:\n")
		for _, result := range summary.Results {
			status := strings.ToUpper(result.Status)
			if result.Status == "created" || result.Status == "existing" {
				fmt.Printf("  [%s] %s v%d (ID: %d)\n", status, result.Subject, result.Version, result.SchemaID)
			} else {
				fmt.Printf("  [%s] %s v%d\n", status, result.Subject, result.Version)
			}
		}
	}

	return nil
}

func init() {
	rootCmd.AddCommand(importCmd)

	// Add subcommands
	importCmd.AddCommand(importSubjectsCmd)
	importCmd.AddCommand(importSubjectCmd)

	// Flags for import commands
	importCmd.PersistentFlags().StringVarP(&importFile, "file", "f", "", "Import file")
	importCmd.PersistentFlags().StringVar(&importDirectory, "directory", "", "Import directory containing JSON files")
	importCmd.PersistentFlags().BoolVar(&dryRun, "dry-run", false, "Preview import without making changes")
	importCmd.PersistentFlags().BoolVar(&skipExisting, "skip-existing", false, "Skip existing schemas")
	importCmd.PersistentFlags().BoolVar(&forceImport, "force", false, "Force import even if schema registry is in read-only mode")
	importCmd.PersistentFlags().StringVar(&importContext, "import-context", "", "Override context for import (default: use context from export)")

	// Global flags
	importCmd.PersistentFlags().StringVar(&context, "context", "", "Schema Registry context")
}
