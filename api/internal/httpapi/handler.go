// Pacote httpapi reúne as rotas HTTP da API. Por enquanto só há a página de exemplo.
package httpapi

import (
	"io"
	"net/http"
)

// Message é o texto devolvido pela rota de exemplo.
const Message = "API do SkillQuest (esqueleto de exemplo)\n"

// NewHandler devolve o roteador da API.
func NewHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", root)
	return mux
}

func root(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = io.WriteString(w, Message)
}
