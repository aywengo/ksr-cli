package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/spf13/viper"
)

// Client represents a Schema Registry client
type Client struct {
	baseURL    string
	httpClient *http.Client
	username   string
	password   string
	apiKey     string
}

// NewClient creates a new Schema Registry client
func NewClient() (*Client, error) {
	baseURL := viper.GetString("registry-url")
	if baseURL == "" {
		return nil, fmt.Errorf("registry URL is required")
	}

	client := &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		username: viper.GetString("username"),
		password: viper.GetString("password"),
		apiKey:   viper.GetString("api-key"),
	}

	return client, nil
}

// makeRequest performs an HTTP request to the Schema Registry
func (c *Client) makeRequest(method, path string, body interface{}) (*http.Response, error) {
	var bodyReader io.Reader
	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		bodyReader = bytes.NewReader(jsonBody)
	}

	url := c.baseURL + path
	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	// Authentication
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	} else if c.username != "" && c.password != "" {
		req.SetBasicAuth(c.username, c.password)
	}

	return c.httpClient.Do(req)
}

// GetSubjects returns all subjects
func (c *Client) GetSubjects(context string) ([]string, error) {
	path := "/subjects"
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var subjects []string
	if err := json.NewDecoder(resp.Body).Decode(&subjects); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return subjects, nil
}

// GetSchema returns a schema by subject and version
func (c *Client) GetSchema(subject, version, context string) (*Schema, error) {
	path := fmt.Sprintf("/subjects/%s/versions/%s", url.PathEscape(subject), url.PathEscape(version))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var schema Schema
	if err := json.NewDecoder(resp.Body).Decode(&schema); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &schema, nil
}

// GetSubjectVersions returns all versions for a subject
func (c *Client) GetSubjectVersions(subject, context string) ([]int, error) {
	path := fmt.Sprintf("/subjects/%s/versions", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var versions []int
	if err := json.NewDecoder(resp.Body).Decode(&versions); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return versions, nil
}

// RegisterSchema registers a new schema
func (c *Client) RegisterSchema(subject string, schemaData *SchemaRequest, context string) (*RegisterResponse, error) {
	path := fmt.Sprintf("/subjects/%s/versions", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("POST", path, schemaData)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result RegisterResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// CheckCompatibility checks if a schema is compatible
func (c *Client) CheckCompatibility(subject string, schemaData *SchemaRequest, context string) (*CompatibilityResponse, error) {
	path := fmt.Sprintf("/compatibility/subjects/%s/versions/latest", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("POST", path, schemaData)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result CompatibilityResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// CheckCompatibilityWithVersion checks if a schema is compatible with a specific version
func (c *Client) CheckCompatibilityWithVersion(subject, version string, schemaData *SchemaRequest, context string) (*CompatibilityResponse, error) {
	path := fmt.Sprintf("/compatibility/subjects/%s/versions/%s", url.PathEscape(subject), url.PathEscape(version))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("POST", path, schemaData)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result CompatibilityResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// GetGlobalConfig returns the global configuration
func (c *Client) GetGlobalConfig(context string) (*Config, error) {
	path := "/config"
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var config Config
	if err := json.NewDecoder(resp.Body).Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &config, nil
}

// GetSubjectConfig returns the configuration for a specific subject
func (c *Client) GetSubjectConfig(subject, context string) (*Config, error) {
	path := fmt.Sprintf("/config/%s", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var config Config
	if err := json.NewDecoder(resp.Body).Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &config, nil
}

// SetGlobalConfig sets global configuration
func (c *Client) SetGlobalConfig(config *Config, context string) (*Config, error) {
	path := "/config"
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("PUT", path, config)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result Config
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// SetSubjectConfig sets configuration for a specific subject
func (c *Client) SetSubjectConfig(subject string, config *Config, context string) (*Config, error) {
	path := fmt.Sprintf("/config/%s", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("PUT", path, config)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result Config
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// DeleteSubject deletes a subject
func (c *Client) DeleteSubject(subject, context string, permanent bool) ([]int, error) {
	path := fmt.Sprintf("/subjects/%s", url.PathEscape(subject))
	query := url.Values{}
	if context != "" {
		query.Set("context", context)
	}
	if permanent {
		query.Set("permanent", "true")
	}
	if len(query) > 0 {
		path += "?" + query.Encode()
	}

	resp, err := c.makeRequest("DELETE", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var versions []int
	if err := json.NewDecoder(resp.Body).Decode(&versions); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return versions, nil
}

// GetGlobalMode returns the global mode of the Schema Registry
func (c *Client) GetGlobalMode(context string) (*Mode, error) {
	path := "/mode"
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var mode Mode
	if err := json.NewDecoder(resp.Body).Decode(&mode); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &mode, nil
}

// SetGlobalMode sets the global mode of the Schema Registry
func (c *Client) SetGlobalMode(mode string, context string) (*Mode, error) {
	path := "/mode"
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	modeRequest := Mode{Mode: mode}
	resp, err := c.makeRequest("PUT", path, modeRequest)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result Mode
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// GetSubjectMode returns the mode for a specific subject
func (c *Client) GetSubjectMode(subject, context string) (*Mode, error) {
	path := fmt.Sprintf("/mode/%s", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	resp, err := c.makeRequest("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var mode Mode
	if err := json.NewDecoder(resp.Body).Decode(&mode); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &mode, nil
}

// SetSubjectMode sets the mode for a specific subject
func (c *Client) SetSubjectMode(subject, mode, context string) (*Mode, error) {
	path := fmt.Sprintf("/mode/%s", url.PathEscape(subject))
	if context != "" {
		path += "?context=" + url.QueryEscape(context)
	}

	modeRequest := Mode{Mode: mode}
	resp, err := c.makeRequest("PUT", path, modeRequest)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleError(resp)
	}

	var result Mode
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// handleError processes error responses from the Schema Registry
func (c *Client) handleError(resp *http.Response) error {
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("HTTP %d: failed to read error response", resp.StatusCode)
	}

	var errorResp ErrorResponse
	if err := json.Unmarshal(body, &errorResp); err != nil {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	return fmt.Errorf("HTTP %d: %s (code: %d)", resp.StatusCode, errorResp.Message, errorResp.ErrorCode)
}
