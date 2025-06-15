package cmd

import (
	"testing"
)

func TestIsValidMode(t *testing.T) {
	tests := []struct {
		name     string
		mode     string
		expected bool
	}{
		{
			name:     "valid READWRITE mode",
			mode:     "READWRITE",
			expected: true,
		},
		{
			name:     "valid READONLY mode",
			mode:     "READONLY",
			expected: true,
		},
		{
			name:     "valid IMPORT mode",
			mode:     "IMPORT",
			expected: true,
		},
		{
			name:     "invalid lowercase mode",
			mode:     "readwrite",
			expected: false,
		},
		{
			name:     "invalid mixed case mode",
			mode:     "ReadWrite",
			expected: false,
		},
		{
			name:     "invalid mode",
			mode:     "INVALID",
			expected: false,
		},
		{
			name:     "empty mode",
			mode:     "",
			expected: false,
		},
		{
			name:     "random string",
			mode:     "RANDOM_MODE",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isValidMode(tt.mode)
			if result != tt.expected {
				t.Errorf("isValidMode(%s) = %v, expected %v", tt.mode, result, tt.expected)
			}
		})
	}
}
