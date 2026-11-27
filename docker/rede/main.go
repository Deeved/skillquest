// Comando rede é a passagem do ambiente de desenvolvimento: um proxy que só
// abre túneis HTTPS para endereços permitidos e um repasse das portas locais.
package main

import (
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"syscall"
	"time"
)

type proxy struct {
	permitidos map[string]bool
	conectar   func(endereco string) (net.Conn, error)
}

func lista(texto string) map[string]bool {
	m := map[string]bool{}
	for _, item := range strings.Split(texto, ",") {
		if item = strings.ToLower(strings.TrimSpace(item)); item != "" {
			m[item] = true
		}
	}
	return m
}

// somentePublico recusa a conexão quando o nome resolve para um endereço interno.
func somentePublico(_, endereco string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(endereco)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsGlobalUnicast() || ip.IsPrivate() {
		return errors.New("endereço interno recusado: " + host)
	}
	return nil
}

func (p *proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodConnect {
		http.Error(w, "somente HTTPS", http.StatusMethodNotAllowed)
		return
	}
	host, porta, err := net.SplitHostPort(r.Host)
	if err != nil || porta != "443" || !p.permitidos[strings.ToLower(host)] {
		log.Printf("recusado: %q", r.Host)
		http.Error(w, "endereço não permitido", http.StatusForbidden)
		return
	}
	destino, err := p.conectar(net.JoinHostPort(strings.ToLower(host), porta))
	if err != nil {
		log.Printf("falha ao conectar em %q: %v", r.Host, err)
		http.Error(w, "falha ao conectar", http.StatusBadGateway)
		return
	}
	defer destino.Close()
	hj, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "sem suporte a túnel", http.StatusInternalServerError)
		return
	}
	cliente, buffer, err := hj.Hijack()
	if err != nil {
		return
	}
	defer cliente.Close()
	if _, err := io.WriteString(cliente, "HTTP/1.1 200 Connection Established\r\n\r\n"); err != nil {
		return
	}
	ligar(cliente, buffer.Reader, destino)
}

// ligar copia os dois sentidos e termina quando um deles acaba.
func ligar(cliente net.Conn, origem io.Reader, destino net.Conn) {
	fim := make(chan struct{}, 2)
	go func() { io.Copy(destino, origem); fim <- struct{}{} }()
	go func() { io.Copy(cliente, destino); fim <- struct{}{} }()
	<-fim
}

func repassar(l net.Listener, alvo string) {
	for {
		c, err := l.Accept()
		if err != nil {
			return
		}
		go func() {
			defer c.Close()
			d, err := net.DialTimeout("tcp", alvo, 5*time.Second)
			if err != nil {
				return
			}
			defer d.Close()
			ligar(c, c, d)
		}()
	}
}

func main() {
	// REPASSES: pares "escuta=alvo" separados por vírgula.
	for _, par := range strings.Split(os.Getenv("REPASSES"), ",") {
		escuta, alvo, ok := strings.Cut(strings.TrimSpace(par), "=")
		if !ok {
			continue
		}
		l, err := net.Listen("tcp", escuta)
		if err != nil {
			log.Fatal(err)
		}
		go repassar(l, alvo)
	}
	discador := &net.Dialer{Timeout: 10 * time.Second, Control: somentePublico}
	servidor := &http.Server{
		Addr:              ":3128",
		ReadHeaderTimeout: 10 * time.Second,
		Handler: &proxy{
			permitidos: lista(os.Getenv("PERMITIDOS")),
			conectar:   func(e string) (net.Conn, error) { return discador.Dial("tcp", e) },
		},
	}
	log.Fatal(servidor.ListenAndServe())
}
