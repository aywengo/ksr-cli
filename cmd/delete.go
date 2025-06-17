package cmd

import (
	"fmt"
	"strconv"

	"github.com/aywengo/ksr-cli/internal/config"
	"github.com/spf13/cobra"
)

var (
	permanent bool
)

var deleteCmd = &cobra.Command{
	Use:   "delete",
	Short: "Delete resources from the Schema Registry",
	Long:  `Delete subjects, versions, or other resources from the Schema Registry.`,
}

var deleteSubjectCmd = &cobra.Command{
	Use:   "subject SUBJECT",
	Short: "Delete a subject",
	Long:  `Delete a subject and all its versions from the Schema Registry.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		subject := args[0]
		effectiveContext := config.GetEffectiveContext(context)

		versions, err := c.DeleteSubject(subject, effectiveContext, permanent)
		if err != nil {
			return fmt.Errorf("failed to delete subject: %w", err)
		}

		if len(versions) > 0 {
			fmt.Printf("Deleted subject %s (versions: %v)\n", subject, versions)
		} else {
			fmt.Printf("Deleted subject %s\n", subject)
		}

		return nil
	},
}

var deleteVersionCmd = &cobra.Command{
	Use:   "version SUBJECT",
	Short: "Delete a specific version of a subject",
	Long:  `Delete a specific version of a subject from the Schema Registry.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		c, err := createClientWithFlags()
		if err != nil {
			return fmt.Errorf("failed to create client: %w", err)
		}

		subject := args[0]
		versionNum, err := strconv.Atoi(version)
		if err != nil {
			return fmt.Errorf("invalid version number: %w", err)
		}

		effectiveContext := config.GetEffectiveContext(context)

		err = c.DeleteSubjectVersion(subject, versionNum, effectiveContext)
		if err != nil {
			return fmt.Errorf("failed to delete version: %w", err)
		}

		fmt.Printf("Deleted version %d of subject %s\n", versionNum, subject)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(deleteCmd)
	deleteCmd.AddCommand(deleteSubjectCmd)
	deleteCmd.AddCommand(deleteVersionCmd)

	// Global flags for all delete commands
	deleteCmd.PersistentFlags().StringVar(&context, "context", "", "Schema Registry context")
	deleteCmd.PersistentFlags().StringVar(&version, "version", "", "Version number to delete")
	deleteCmd.PersistentFlags().BoolVar(&permanent, "permanent", false, "Permanently delete the subject")
} 