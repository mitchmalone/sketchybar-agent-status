package state

import "encoding/json"

func jsonMarshal(v any) ([]byte, error)   { return json.MarshalIndent(v, "", "  ") }
func jsonUnmarshal(b []byte, v any) error { return json.Unmarshal(b, v) }
