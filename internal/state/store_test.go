package state

import "testing"

func TestApplyReplacesAndRemovesSession(t *testing.T) {
	s := New()
	if err := s.Apply(Event{Session: "a", Agent: "claude", State: "working", Title: "one"}); err != nil {
		t.Fatal(err)
	}
	if err := s.Apply(Event{Session: "a", Agent: "claude", State: "attention", Title: "two"}); err != nil {
		t.Fatal(err)
	}
	if got := s.List(); len(got) != 1 || got[0].State != "attention" || got[0].Title != "two" {
		t.Fatalf("unexpected %#v", got)
	}
	if err := s.Apply(Event{Session: "a", Agent: "claude", State: "ended"}); err != nil {
		t.Fatal(err)
	}
	if len(s.List()) != 0 {
		t.Fatal("ended session remained")
	}
}
