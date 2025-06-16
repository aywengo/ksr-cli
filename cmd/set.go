package cmd

import (
	"fmt"
	"strings"

	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/aywengo/ksr-cli/internal/output"
	"github.com/spf13/cobra"
)

// setCmd represents the set command
var setCmd = &cobra.Command{
	Use:   "set",
	Short: "Set Schema Registry resources",
	Long: `Set various Schema Registry resources including modes and configurations.

Examples:
  ksr-cli set mode READWRITE
  ksr-cli set mode my-subject READONLY`,
}

var setModeCmd = &cobra.Command{
	Use:   "mode [SUBJECT] MODE",
	Short: "Set mode configuration",
	Long: `Set global mode or mode for a specific subject.

The mode controls the behavior of the Schema Registry:
- READWRITE: Normal operation (default)
- READONLY: Only read operations are allowed
- IMPORT: Schema Registry is in import mode

Examples:
  ksr-cli set mode READWRITE         # Set global mode
  ksr-cli set mode my-subject READONLY # Set subject-specific mode`,
	Args: cobra.RangeArgs(1, 2),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)

		if len(args) == 1 {
			// Set global mode
			originalMode := args[0]
			mode := strings.ToUpper(originalMode)
			if !isValidMode(mode) {
				return fmt.Errorf("invalid mode: %s. Valid modes are: READWRITE, READONLY, IMPORT", originalMode)
			}
			// Check for case sensitivity - modes must be uppercase
			if originalMode != mode {
				return fmt.Errorf("invalid mode: %s. Mode must be uppercase. Valid modes are: READWRITE, READONLY, IMPORT", originalMode)
			}

			result, err := c.SetGlobalMode(mode, effectiveContext)
			if err != nil {
				return fmt.Errorf("failed to set global mode: %w", err)
			}
			return output.Print(result, outputFormat)
		}

		// Set subject mode
		subject := args[0]
		originalMode := args[1]
		mode := strings.ToUpper(originalMode)
		if !isValidMode(mode) {
			return fmt.Errorf("invalid mode: %s. Valid modes are: READWRITE, READONLY, IMPORT", originalMode)
		}
		// Check for case sensitivity - modes must be uppercase
		if originalMode != mode {
			return fmt.Errorf("invalid mode: %s. Mode must be uppercase. Valid modes are: READWRITE, READONLY, IMPORT", originalMode)
		}

		result, err := c.SetSubjectMode(subject, mode, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to set mode for subject %s: %w", subject, err)
		}

		return output.Print(result, outputFormat)
	},
}

// isValidMode checks if the provided mode is valid
func isValidMode(mode string) bool {
	validModes := []string{"READWRITE", "READONLY", "IMPORT"}
	for _, validMode := range validModes {
		if mode == validMode {
			return true
		}
	}
	return false
}

func init() {
	rootCmd.AddCommand(setCmd)

	// Add subcommands
	setCmd.AddCommand(setModeCmd)

	// Global flags for all set commands
	setCmd.PersistentFlags().StringVar(&context, "context", "", "Schema Registry context")
	setCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "table", "Output format (table, json, yaml)")
}
