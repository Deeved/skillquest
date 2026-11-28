// Comando reviewer é o esqueleto do revisor. Com AGENT=fake (o padrão do ambiente),
// não chama a API do Claude nem executa código de participante.
package main

import (
	"fmt"
	"os"

	"skillquest/reviewer/internal/verdict"
)

func main() {
	if agent := os.Getenv("AGENT"); agent != "" && agent != "fake" {
		fmt.Fprintf(os.Stderr, "AGENT=%q não é suportado neste esqueleto; use AGENT=fake\n", agent)
		os.Exit(2)
	}
	label, err := verdict.Label("human_review")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println("Revisor falso (AGENT=fake). Exemplo de resultado:", label)
}
