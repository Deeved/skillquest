// Pacote verdict traduz o resultado de uma revisão para o texto mostrado às pessoas.
// É só um exemplo do esqueleto: os identificadores (approved, changes_requested,
// human_review) são provisórios e não são o contrato definitivo.
// Não há chamada a nenhum serviço externo.
package verdict

import "fmt"

// Label devolve o texto, em português, de um resultado de revisão.
func Label(result string) (string, error) {
	switch result {
	case "approved":
		return "Aprovado", nil
	case "changes_requested":
		return "Ajustar", nil
	case "human_review":
		return "Revisão humana", nil
	default:
		return "", fmt.Errorf("resultado de revisão desconhecido: %q", result)
	}
}
