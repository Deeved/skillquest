// Comando api sobe a API do SkillQuest. O endereço vem de ADDR (padrão ":8080").
package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"skillquest/api/internal/httpapi"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	server := &http.Server{
		Addr:              addr,
		Handler:           httpapi.NewHandler(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("API escutando em %s", addr)
	log.Fatal(server.ListenAndServe())
}
