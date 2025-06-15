package main

import (
	"os"

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

	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
