package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func serve(method, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	NewHandler().ServeHTTP(rec, httptest.NewRequest(method, path, nil))
	return rec
}

func TestRootReturnsOK(t *testing.T) {
	rec := serve(http.MethodGet, "/")
	want := http.StatusOK
	if rec.Code != want {
		t.Fatalf("status = %d, esperado %d", rec.Code, want)
	}
	if got := rec.Body.String(); got != Message {
		t.Fatalf("corpo = %q, esperado %q", got, Message)
	}
}

func TestUnknownPathReturnsNotFound(t *testing.T) {
	if rec := serve(http.MethodGet, "/nao-existe"); rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, esperado %d", rec.Code, http.StatusNotFound)
	}
}

func TestRootRejectsPost(t *testing.T) {
	rec := serve(http.MethodPost, "/")
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, esperado %d", rec.Code, http.StatusMethodNotAllowed)
	}
}
