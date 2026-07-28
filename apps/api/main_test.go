package main

import "testing"

func TestPositiveEnvironmentInt(t *testing.T) {
	t.Setenv("TEST_POSITIVE_INT", "")
	value, err := positiveEnvironmentInt("TEST_POSITIVE_INT", 20)
	if err != nil || value != 20 {
		t.Fatalf("unexpected default: value=%d err=%v", value, err)
	}

	t.Setenv("TEST_POSITIVE_INT", "12")
	value, err = positiveEnvironmentInt("TEST_POSITIVE_INT", 20)
	if err != nil || value != 12 {
		t.Fatalf("unexpected configured value: value=%d err=%v", value, err)
	}

	t.Setenv("TEST_POSITIVE_INT", "0")
	if _, err = positiveEnvironmentInt("TEST_POSITIVE_INT", 20); err == nil {
		t.Fatal("zero value must be rejected")
	}
}
