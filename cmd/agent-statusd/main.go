package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/mitchmalone/sketchybar-agent-status/internal/state"
)

func main() {
	dir := defaultDir()
	socket := flag.String("socket", filepath.Join(dir, "events.sock"), "Unix socket")
	snapshot := flag.String("state", filepath.Join(dir, "state.json"), "State snapshot")
	flag.Parse()
	s, err := state.Load(*snapshot)
	if err != nil {
		fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(*socket), 0755); err != nil {
		fatal(err)
	}
	_ = os.Remove(*socket)
	l, err := net.Listen("unix", *socket)
	if err != nil {
		fatal(err)
	}
	defer l.Close()
	if err := os.Chmod(*socket, 0600); err != nil {
		fatal(err)
	}
	for {
		c, err := l.Accept()
		if err != nil {
			continue
		}
		go handle(c, s, *snapshot)
	}
}

func handle(c net.Conn, s *state.Store, snapshot string) {
	defer c.Close()
	scanner := bufio.NewScanner(c)
	for scanner.Scan() {
		var e state.Event
		if err := json.Unmarshal(scanner.Bytes(), &e); err != nil {
			continue
		}
		if err := s.Apply(e); err == nil {
			_ = s.Save(snapshot)
			_ = exec.Command("sketchybar", "--trigger", "agent_status_change").Run()
		}
	}
}
func defaultDir() string {
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return filepath.Join(d, "sketchybar-agent-status")
	}
	h, _ := os.UserHomeDir()
	return filepath.Join(h, ".local", "state", "sketchybar-agent-status")
}
func fatal(err error) {
	fmt.Fprintln(os.Stderr, "agent-statusd:", strings.TrimSpace(err.Error()))
	os.Exit(1)
}
