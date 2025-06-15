package output

import (
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"strconv"
	"strings"

	"github.com/jedib0t/go-pretty/v6/table"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
	"gopkg.in/yaml.v3"
)

// Print outputs data in the specified format
func Print(data interface{}, format string) error {
	switch strings.ToLower(format) {
	case "json":
		return printJSON(data)
	case "yaml", "yml":
		return printYAML(data)
	case "table":
		return printTable(data)
	default:
		return fmt.Errorf("unsupported output format: %s", format)
	}
}

// printJSON outputs data as JSON
func printJSON(data interface{}) error {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(data)
}

// printYAML outputs data as YAML
func printYAML(data interface{}) error {
	encoder := yaml.NewEncoder(os.Stdout)
	defer encoder.Close()
	return encoder.Encode(data)
}

// printTable outputs data as a formatted table
func printTable(data interface{}) error {
	t := table.NewWriter()
	t.SetOutputMirror(os.Stdout)

	// Handle different data types
	switch v := data.(type) {
	case []string:
		return printStringSliceTable(v)
	case []int:
		return printIntSliceTable(v)
	case []interface{}:
		return printInterfaceSliceTable(v, t)
	default:
		return printGenericTable(data, t)
	}
}

// printStringSliceTable prints a slice of strings as a table
func printStringSliceTable(data []string) error {
	t := table.NewWriter()
	t.SetOutputMirror(os.Stdout)
	t.AppendHeader(table.Row{"Subjects"})

	for _, item := range data {
		t.AppendRow(table.Row{item})
	}

	t.Render()
	return nil
}

// printIntSliceTable prints a slice of integers as a table
func printIntSliceTable(data []int) error {
	t := table.NewWriter()
	t.SetOutputMirror(os.Stdout)
	t.AppendHeader(table.Row{"Versions"})

	for _, item := range data {
		t.AppendRow(table.Row{strconv.Itoa(item)})
	}

	t.Render()
	return nil
}

// printInterfaceSliceTable prints a slice of interfaces as a table
func printInterfaceSliceTable(data []interface{}, t table.Writer) error {
	if len(data) == 0 {
		fmt.Println("No data to display")
		return nil
	}

	// Use the first item to determine the structure
	first := data[0]
	headers := getHeaders(first)
	t.AppendHeader(headers)

	for _, item := range data {
		row := getRow(item, headers)
		t.AppendRow(row)
	}

	t.Render()
	return nil
}

// printGenericTable prints any data structure as a table
func printGenericTable(data interface{}, t table.Writer) error {
	headers := getHeaders(data)
	t.AppendHeader(headers)

	row := getRow(data, headers)
	t.AppendRow(row)

	t.Render()
	return nil
}

// getHeaders extracts headers from a data structure
func getHeaders(data interface{}) table.Row {
	if data == nil {
		return table.Row{"Value"}
	}

	val := reflect.ValueOf(data)
	typ := reflect.TypeOf(data)

	// Handle pointers
	if val.Kind() == reflect.Ptr {
		if val.IsNil() {
			return table.Row{"Value"}
		}
		val = val.Elem()
		typ = typ.Elem()
	}

	switch val.Kind() {
	case reflect.Struct:
		var headers table.Row
		for i := 0; i < val.NumField(); i++ {
			field := typ.Field(i)
			if field.IsExported() {
				// Use JSON tag if available, otherwise use field name
				name := field.Name
				if jsonTag := field.Tag.Get("json"); jsonTag != "" && jsonTag != "-" {
					if commaIdx := strings.Index(jsonTag, ","); commaIdx != -1 {
						name = jsonTag[:commaIdx]
					} else {
						name = jsonTag
					}
				}
				headers = append(headers, cases.Title(language.Und).String(name))
			}
		}
		return headers
	case reflect.Map:
		var headers table.Row
		for _, key := range val.MapKeys() {
			headers = append(headers, fmt.Sprintf("%v", key.Interface()))
		}
		return headers
	default:
		return table.Row{"Value"}
	}
}

// getRow extracts a row of data from a structure
func getRow(data interface{}, headers table.Row) table.Row {
	if data == nil {
		return table.Row{"<nil>"}
	}

	val := reflect.ValueOf(data)

	// Handle pointers
	if val.Kind() == reflect.Ptr {
		if val.IsNil() {
			return table.Row{"<nil>"}
		}
		val = val.Elem()
	}

	switch val.Kind() {
	case reflect.Struct:
		var row table.Row
		for i := 0; i < val.NumField(); i++ {
			field := val.Field(i)
			if val.Type().Field(i).IsExported() {
				row = append(row, formatValue(field.Interface()))
			}
		}
		return row
	case reflect.Map:
		var row table.Row
		for _, key := range val.MapKeys() {
			value := val.MapIndex(key)
			row = append(row, formatValue(value.Interface()))
		}
		return row
	default:
		return table.Row{formatValue(data)}
	}
}

// formatValue formats a value for display in a table
func formatValue(value interface{}) string {
	if value == nil {
		return "<nil>"
	}

	switch v := value.(type) {
	case string:
		if len(v) > 50 {
			return v[:47] + "..."
		}
		return v
	case []byte:
		return string(v)
	case json.RawMessage:
		// Pretty print JSON if it's valid
		var parsed interface{}
		if err := json.Unmarshal(v, &parsed); err == nil {
			if formatted, err := json.MarshalIndent(parsed, "", "  "); err == nil {
				s := string(formatted)
				if len(s) > 100 {
					return s[:97] + "..."
				}
				return s
			}
		}
		return string(v)
	default:
		str := fmt.Sprintf("%v", value)
		if len(str) > 50 {
			return str[:47] + "..."
		}
		return str
	}
}
