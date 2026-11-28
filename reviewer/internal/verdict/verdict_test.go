package verdict

import "testing"

func TestLabelKnownResults(t *testing.T) {
	cases := map[string]string{
		"approved":          "Aprovado",
		"changes_requested": "Ajustar",
		"human_review":      "Revisão humana",
	}
	for result, want := range cases {
		got, err := Label(result)
		if err != nil || got != want {
			t.Errorf("Label(%q) = %q, %v; esperado %q, nil", result, got, err, want)
		}
	}
}

func TestLabelUnknownResult(t *testing.T) {
	if got, err := Label("talvez"); err == nil {
		t.Fatalf("Label(\"talvez\") = %q, nil; esperado erro", got)
	}
}
