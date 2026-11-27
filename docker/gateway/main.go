// Comando gateway é a passagem do ambiente de desenvolvimento: um proxy que só
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
	allowed map[string]bool
	connect func(address string) (net.Conn, error)
}

func parseList(text string) map[string]bool {
	m := map[string]bool{}
	for _, item := range strings.Split(text, ",") {
		if item = strings.ToLower(strings.TrimSpace(item)); item != "" {
			m[item] = true
		}
	}
	return m
}

// publicOnly recusa a conexão quando o nome resolve para um endereço interno.
func publicOnly(_, address string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
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
	host, port, err := net.SplitHostPort(r.Host)
	if err != nil || port != "443" || !p.allowed[strings.ToLower(host)] {
		log.Printf("recusado: %q", r.Host)
		http.Error(w, "endereço não permitido", http.StatusForbidden)
		return
	}
	upstream, err := p.connect(net.JoinHostPort(strings.ToLower(host), port))
	if err != nil {
		log.Printf("falha ao conectar em %q: %v", r.Host, err)
		http.Error(w, "falha ao conectar", http.StatusBadGateway)
		return
	}
	defer upstream.Close()
	hj, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "sem suporte a túnel", http.StatusInternalServerError)
		return
	}
	client, buffer, err := hj.Hijack()
	if err != nil {
		return
	}
	defer client.Close()
	if _, err := io.WriteString(client, "HTTP/1.1 200 Connection Established\r\n\r\n"); err != nil {
		return
	}
	tunnel(client, buffer.Reader, upstream)
}

// tunnel copia os dois sentidos e termina quando um deles acaba.
func tunnel(client net.Conn, source io.Reader, upstream net.Conn) {
	done := make(chan struct{}, 2)
	go func() { io.Copy(upstream, source); done <- struct{}{} }()
	go func() { io.Copy(client, upstream); done <- struct{}{} }()
	<-done
}

func forward(l net.Listener, target string) {
	for {
		c, err := l.Accept()
		if err != nil {
			return
		}
		go func() {
			defer c.Close()
			d, err := net.DialTimeout("tcp", target, 5*time.Second)
			if err != nil {
				return
			}
			defer d.Close()
			tunnel(c, c, d)
		}()
	}
}

func main() {
	// FORWARDS: pares "escuta=alvo" separados por vírgula.
	for _, pair := range strings.Split(os.Getenv("FORWARDS"), ",") {
		listen, target, ok := strings.Cut(strings.TrimSpace(pair), "=")
		if !ok {
			continue
		}
		l, err := net.Listen("tcp", listen)
		if err != nil {
			log.Fatal(err)
		}
		go forward(l, target)
	}
	dialer := &net.Dialer{Timeout: 10 * time.Second, Control: publicOnly}
	server := &http.Server{
		Addr:              ":3128",
		ReadHeaderTimeout: 10 * time.Second,
		Handler: &proxy{
			allowed: parseList(os.Getenv("ALLOWED_HOSTS")),
			connect: func(a string) (net.Conn, error) { return dialer.Dial("tcp", a) },
		},
	}
	log.Fatal(server.ListenAndServe())
}
