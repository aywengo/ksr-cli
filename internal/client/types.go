package client

import "encoding/json"

// Schema represents a schema in the Schema Registry
type Schema struct {
	ID         int             `json:"id"`
	Version    int             `json:"version"`
	Schema     json.RawMessage `json:"schema"`
	Subject    string          `json:"subject"`
	Type       string          `json:"schemaType,omitempty"`
	References []Reference     `json:"references,omitempty"`
}

// Reference represents a schema reference
type Reference struct {
	Name    string `json:"name"`
	Subject string `json:"subject"`
	Version int    `json:"version"`
}

// SchemaRequest represents a schema registration request
type SchemaRequest struct {
	Schema     string      `json:"schema"`
	SchemaType string      `json:"schemaType,omitempty"`
	References []Reference `json:"references,omitempty"`
}

// RegisterResponse represents the response from schema registration
type RegisterResponse struct {
	ID int `json:"id"`
}

// CompatibilityResponse represents the response from compatibility check
type CompatibilityResponse struct {
	IsCompatible bool     `json:"is_compatible"`
	Messages     []string `json:"messages,omitempty"`
}

// Config represents Schema Registry configuration
type Config struct {
	Compatibility               string `json:"compatibility,omitempty"`
	CompatibilityLevel          string `json:"compatibilityLevel,omitempty"`
	Alias                       string `json:"alias,omitempty"`
	Normalize                   bool   `json:"normalize,omitempty"`
	DefaultToGlobalConfig       bool   `json:"defaultToGlobalConfig,omitempty"`
	ValidateFields              bool   `json:"validateFields,omitempty"`
	UseLatestVersion            bool   `json:"useLatestVersion,omitempty"`
	UseSchemasFromLatestSubject bool   `json:"useSchemasFromLatestSubject,omitempty"`
}

// ErrorResponse represents an error response from the Schema Registry
type ErrorResponse struct {
	ErrorCode int    `json:"error_code"`
	Message   string `json:"message"`
}

// Subject represents a subject with metadata
type Subject struct {
	Name     string  `json:"name"`
	Versions []int   `json:"versions,omitempty"`
	Latest   *Schema `json:"latest,omitempty"`
}

// VersionInfo represents version information
type VersionInfo struct {
	Subject string `json:"subject"`
	Version int    `json:"version"`
	ID      int    `json:"id"`
	Schema  string `json:"schema"`
}

// Mode represents the Schema Registry mode
type Mode struct {
	Mode string `json:"mode"`
}

// Context represents a Schema Registry context
type Context struct {
	Name string `json:"name"`
}

// SubjectVersion represents a subject version combination
type SubjectVersion struct {
	Subject string `json:"subject"`
	Version int    `json:"version"`
}

// SchemaRegistryInfo represents information about the Schema Registry instance
type SchemaRegistryInfo struct {
	Version        string `json:"version"`
	Commit         string `json:"commit"`
	KafkaClusterID string `json:"kafka_cluster_id,omitempty"`
}

// SchemaString represents a schema as a string (for parsing)
type SchemaString struct {
	Schema string `json:"schema"`
}

// CompatibilityLevel represents the different compatibility levels
type CompatibilityLevel string

const (
	CompatibilityNone               CompatibilityLevel = "NONE"
	CompatibilityBackward           CompatibilityLevel = "BACKWARD"
	CompatibilityBackwardTransitive CompatibilityLevel = "BACKWARD_TRANSITIVE"
	CompatibilityForward            CompatibilityLevel = "FORWARD"
	CompatibilityForwardTransitive  CompatibilityLevel = "FORWARD_TRANSITIVE"
	CompatibilityFull               CompatibilityLevel = "FULL"
	CompatibilityFullTransitive     CompatibilityLevel = "FULL_TRANSITIVE"
)

// SchemaType represents the different schema types supported
type SchemaType string

const (
	SchemaTypeAvro     SchemaType = "AVRO"
	SchemaTypeJSON     SchemaType = "JSON"
	SchemaTypeProtobuf SchemaType = "PROTOBUF"
)

// RegistryMode represents the different modes the registry can be in
type RegistryMode string

const (
	ModeReadWrite RegistryMode = "READWRITE"
	ModeReadOnly  RegistryMode = "READONLY"
	ModeImport    RegistryMode = "IMPORT"
)
