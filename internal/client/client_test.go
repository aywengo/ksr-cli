package client

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/spf13/viper"
)

func TestClient_GetGlobalMode(t *testing.T) {
	tests := []struct {
		name           string
		context        string
		responseStatus int
		responseBody   string
		expectedMode   string
		expectError    bool
	}{
		{
			name:           "successful get global mode",
			context:        "",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"READWRITE"}`,
			expectedMode:   "READWRITE",
			expectError:    false,
		},
		{
			name:           "successful get global mode with context",
			context:        "test-context",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"READONLY"}`,
			expectedMode:   "READONLY",
			expectError:    false,
		},
		{
			name:           "error response",
			context:        "",
			responseStatus: http.StatusNotFound,
			responseBody:   `{"error_code":40401,"message":"Subject not found"}`,
			expectedMode:   "",
			expectError:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify the request path and method
				expectedPath := "/mode"
				if tt.context != "" {
					expectedPath += "?context=" + url.QueryEscape(tt.context)
				}
				if r.URL.Path != "/mode" {
					t.Errorf("Expected path /mode, got %s", r.URL.Path)
				}
				if r.Method != http.MethodGet {
					t.Errorf("Expected GET method, got %s", r.Method)
				}
				if tt.context != "" && r.URL.Query().Get("context") != tt.context {
					t.Errorf("Expected context %s, got %s", tt.context, r.URL.Query().Get("context"))
				}

				w.WriteHeader(tt.responseStatus)
				w.Write([]byte(tt.responseBody))
			}))
			defer server.Close()

			// Set up viper for testing
			viper.Set("registry-url", server.URL)

			client, err := NewClient()
			if err != nil {
				t.Fatalf("Failed to create client: %v", err)
			}

			mode, err := client.GetGlobalMode(tt.context)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error, but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if mode.Mode != tt.expectedMode {
				t.Errorf("Expected mode %s, got %s", tt.expectedMode, mode.Mode)
			}
		})
	}
}

func TestClient_SetGlobalMode(t *testing.T) {
	tests := []struct {
		name           string
		mode           string
		context        string
		responseStatus int
		responseBody   string
		expectedMode   string
		expectError    bool
	}{
		{
			name:           "successful set global mode",
			mode:           "READONLY",
			context:        "",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"READONLY"}`,
			expectedMode:   "READONLY",
			expectError:    false,
		},
		{
			name:           "successful set global mode with context",
			mode:           "READWRITE",
			context:        "test-context",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"READWRITE"}`,
			expectedMode:   "READWRITE",
			expectError:    false,
		},
		{
			name:           "error response",
			mode:           "INVALID",
			context:        "",
			responseStatus: http.StatusBadRequest,
			responseBody:   `{"error_code":422,"message":"Invalid mode"}`,
			expectedMode:   "",
			expectError:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify the request path and method
				if r.URL.Path != "/mode" {
					t.Errorf("Expected path /mode, got %s", r.URL.Path)
				}
				if r.Method != http.MethodPut {
					t.Errorf("Expected PUT method, got %s", r.Method)
				}
				if tt.context != "" && r.URL.Query().Get("context") != tt.context {
					t.Errorf("Expected context %s, got %s", tt.context, r.URL.Query().Get("context"))
				}

				// Verify request body
				var requestBody Mode
				if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
					t.Errorf("Failed to decode request body: %v", err)
				}
				if requestBody.Mode != tt.mode {
					t.Errorf("Expected mode in request body %s, got %s", tt.mode, requestBody.Mode)
				}

				w.WriteHeader(tt.responseStatus)
				w.Write([]byte(tt.responseBody))
			}))
			defer server.Close()

			// Set up viper for testing
			viper.Set("registry-url", server.URL)

			client, err := NewClient()
			if err != nil {
				t.Fatalf("Failed to create client: %v", err)
			}

			mode, err := client.SetGlobalMode(tt.mode, tt.context)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error, but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if mode.Mode != tt.expectedMode {
				t.Errorf("Expected mode %s, got %s", tt.expectedMode, mode.Mode)
			}
		})
	}
}

func TestClient_GetSubjectMode(t *testing.T) {
	tests := []struct {
		name           string
		subject        string
		context        string
		responseStatus int
		responseBody   string
		expectedMode   string
		expectError    bool
	}{
		{
			name:           "successful get subject mode",
			subject:        "test-subject",
			context:        "",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"READONLY"}`,
			expectedMode:   "READONLY",
			expectError:    false,
		},
		{
			name:           "successful get subject mode with context",
			subject:        "test-subject",
			context:        "test-context",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"IMPORT"}`,
			expectedMode:   "IMPORT",
			expectError:    false,
		},
		{
			name:           "subject not found",
			subject:        "non-existent-subject",
			context:        "",
			responseStatus: http.StatusNotFound,
			responseBody:   `{"error_code":40401,"message":"Subject not found"}`,
			expectedMode:   "",
			expectError:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify the request path and method
				expectedPath := "/mode/" + url.PathEscape(tt.subject)
				if r.URL.Path != expectedPath {
					t.Errorf("Expected path %s, got %s", expectedPath, r.URL.Path)
				}
				if r.Method != http.MethodGet {
					t.Errorf("Expected GET method, got %s", r.Method)
				}
				if tt.context != "" && r.URL.Query().Get("context") != tt.context {
					t.Errorf("Expected context %s, got %s", tt.context, r.URL.Query().Get("context"))
				}

				w.WriteHeader(tt.responseStatus)
				w.Write([]byte(tt.responseBody))
			}))
			defer server.Close()

			// Set up viper for testing
			viper.Set("registry-url", server.URL)

			client, err := NewClient()
			if err != nil {
				t.Fatalf("Failed to create client: %v", err)
			}

			mode, err := client.GetSubjectMode(tt.subject, tt.context)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error, but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if mode.Mode != tt.expectedMode {
				t.Errorf("Expected mode %s, got %s", tt.expectedMode, mode.Mode)
			}
		})
	}
}

func TestClient_SetSubjectMode(t *testing.T) {
	tests := []struct {
		name           string
		subject        string
		mode           string
		context        string
		responseStatus int
		responseBody   string
		expectedMode   string
		expectError    bool
	}{
		{
			name:           "successful set subject mode",
			subject:        "test-subject",
			mode:           "READONLY",
			context:        "",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"READONLY"}`,
			expectedMode:   "READONLY",
			expectError:    false,
		},
		{
			name:           "successful set subject mode with context",
			subject:        "test-subject",
			mode:           "IMPORT",
			context:        "test-context",
			responseStatus: http.StatusOK,
			responseBody:   `{"mode":"IMPORT"}`,
			expectedMode:   "IMPORT",
			expectError:    false,
		},
		{
			name:           "subject not found",
			subject:        "non-existent-subject",
			mode:           "READONLY",
			context:        "",
			responseStatus: http.StatusNotFound,
			responseBody:   `{"error_code":40401,"message":"Subject not found"}`,
			expectedMode:   "",
			expectError:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify the request path and method
				expectedPath := "/mode/" + url.PathEscape(tt.subject)
				if r.URL.Path != expectedPath {
					t.Errorf("Expected path %s, got %s", expectedPath, r.URL.Path)
				}
				if r.Method != http.MethodPut {
					t.Errorf("Expected PUT method, got %s", r.Method)
				}
				if tt.context != "" && r.URL.Query().Get("context") != tt.context {
					t.Errorf("Expected context %s, got %s", tt.context, r.URL.Query().Get("context"))
				}

				// Verify request body
				var requestBody Mode
				if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
					t.Errorf("Failed to decode request body: %v", err)
				}
				if requestBody.Mode != tt.mode {
					t.Errorf("Expected mode in request body %s, got %s", tt.mode, requestBody.Mode)
				}

				w.WriteHeader(tt.responseStatus)
				w.Write([]byte(tt.responseBody))
			}))
			defer server.Close()

			// Set up viper for testing
			viper.Set("registry-url", server.URL)

			client, err := NewClient()
			if err != nil {
				t.Fatalf("Failed to create client: %v", err)
			}

			mode, err := client.SetSubjectMode(tt.subject, tt.mode, tt.context)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error, but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if mode.Mode != tt.expectedMode {
				t.Errorf("Expected mode %s, got %s", tt.expectedMode, mode.Mode)
			}
		})
	}
}
