package main

import (
	"os"
	"path/filepath"

	"github.com/aywengo/ksr-cli/cmd"
)

// Version information - set during build
var (
	Version   = "dev"
	BuildTime = "unknown"
)

func main() {
	// Set version information for the CLI
	cmd.Version = Version
	cmd.BuildTime = BuildTime

	// Detect the binary name to adjust command examples
	binaryName := filepath.Base(os.Args[0])
	cmd.SetBinaryName(binaryName)

	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
