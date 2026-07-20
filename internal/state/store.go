package state

import (
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

type Event struct {
	Session string `json:"session"`
	Agent   string `json:"agent"`
	State   string `json:"state"`
	Title   string `json:"title"`
	Detail  string `json:"detail"`
	Tmux    string `json:"tmux"`
}

type Session struct {
	Event
	UpdatedAt time.Time `json:"updated_at"`
}

type Store struct {
	mu       sync.Mutex
	Sessions map[string]Session `json:"sessions"`
}

func New() *Store { return &Store{Sessions: map[string]Session{}} }

func (s *Store) Apply(e Event) error {
	if e.Session == "" || e.Agent == "" {
		return errors.New("session and agent are required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if e.State == "ended" {
		delete(s.Sessions, e.Session)
		return nil
	}
	if current, ok := s.Sessions[e.Session]; ok {
		if e.Title == "" {
			e.Title = current.Title
		}
		if e.Detail == "" {
			e.Detail = current.Detail
		}
		if e.Tmux == "" {
			e.Tmux = current.Tmux
		}
	}
	s.Sessions[e.Session] = Session{Event: e, UpdatedAt: time.Now().UTC()}
	return nil
}

func (s *Store) List() []Session {
	s.mu.Lock()
	defer s.mu.Unlock()
	items := make([]Session, 0, len(s.Sessions))
	for _, v := range s.Sessions {
		items = append(items, v)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].UpdatedAt.After(items[j].UpdatedAt) })
	return items
}

func (s *Store) Save(path string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	b, err := jsonMarshal(s)
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0600)
}

func Load(path string) (*Store, error) {
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return New(), nil
	}
	if err != nil {
		return nil, err
	}
	s := New()
	if err := jsonUnmarshal(b, s); err != nil {
		return nil, err
	}
	if s.Sessions == nil {
		s.Sessions = map[string]Session{}
	}
	for key, session := range s.Sessions {
		if isLifecycleName(session.Title) {
			session.Title = ""
			s.Sessions[key] = session
		}
	}
	return s, nil
}

func isLifecycleName(value string) bool {
	switch value {
	case "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Notification", "Stop", "SessionEnd":
		return true
	default:
		return false
	}
}
