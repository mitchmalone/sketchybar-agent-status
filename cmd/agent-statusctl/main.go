package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"path/filepath"

	"github.com/mitchmalone/sketchybar-agent-status/internal/state"
)

func main() {
	if len(os.Args) < 2 {
		fatal("expected emit or state")
	}
	dir := defaultDir()
	switch os.Args[1] {
	case "emit":
		fs := flag.NewFlagSet("emit", flag.ExitOnError)
		socket := fs.String("socket", filepath.Join(dir, "events.sock"), "socket")
		agent := fs.String("agent", "claude", "agent")
		session := fs.String("session", "", "stable session id")
		status := fs.String("state", "working", "state")
		title := fs.String("title", "", "title")
		detail := fs.String("detail", "", "detail")
		tmux := fs.String("tmux", "", "tmux target")
		_ = fs.Parse(os.Args[2:])
		if *session == "" {
			fatal("--session is required")
		}
		b, _ := json.Marshal(state.Event{Session: *session, Agent: *agent, State: *status, Title: *title, Detail: *detail, Tmux: *tmux})
		c, err := net.Dial("unix", *socket)
		if err != nil {
			fatal(err)
		}
		defer c.Close()
		_, _ = c.Write(append(b, '\n'))
	case "state":
		b, err := os.ReadFile(filepath.Join(dir, "state.json"))
		if err != nil {
			fatal(err)
		}
		fmt.Println(string(b))
	default:
		fatal("expected emit or state")
	}
}
func defaultDir() string {
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return filepath.Join(d, "sketchybar-agent-status")
	}
	h, _ := os.UserHomeDir()
	return filepath.Join(h, ".local", "state", "sketchybar-agent-status")
}
func fatal(s any) { fmt.Fprintln(os.Stderr, "agent-statusctl:", s); os.Exit(1) }
