package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

func eco(t *testing.T) net.Listener {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			go func() { io.Copy(c, c); c.Close() }()
		}
	}()
	return l
}

func pedir(t *testing.T, servidor, linha string) (net.Conn, *bufio.Reader, int) {
	t.Helper()
	c, err := net.Dial("tcp", servidor)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	fmt.Fprintf(c, "%s HTTP/1.1\r\nHost: teste\r\n\r\n", linha)
	r := bufio.NewReader(c)
	resp, err := http.ReadResponse(r, &http.Request{Method: http.MethodConnect})
	if err != nil {
		t.Fatal(err)
	}
	return c, r, resp.StatusCode
}

func TestProxy(t *testing.T) {
	destino := eco(t)
	var discados []string
	s := httptest.NewServer(&proxy{
		permitidos: lista("api.anthropic.com"),
		conectar: func(e string) (net.Conn, error) {
			discados = append(discados, e)
			return net.Dial("tcp", destino.Addr().String())
		},
	})
	defer s.Close()
	addr := s.Listener.Addr().String()

	recusados := map[string]int{
		"CONNECT exemplo.com:443":                   403,
		"CONNECT api.anthropic.com:22":              403,
		"CONNECT api.anthropic.com.exemplo.com:443": 403,
		"CONNECT x.api.anthropic.com:443":           403,
		"CONNECT 127.0.0.1:443":                     403,
		"GET http://api.anthropic.com/":             405,
	}
	for linha, esperado := range recusados {
		if _, _, status := pedir(t, addr, linha); status != esperado {
			t.Errorf("%s: status %d, esperado %d", linha, status, esperado)
		}
	}
	if len(discados) != 0 {
		t.Fatalf("pedido recusado abriu conexão: %v", discados)
	}

	c, r, status := pedir(t, addr, "CONNECT API.Anthropic.com:443")
	if status != 200 {
		t.Fatalf("permitido: status %d", status)
	}
	fmt.Fprint(c, "ola\n")
	if linha, err := r.ReadString('\n'); err != nil || linha != "ola\n" {
		t.Fatalf("túnel: %q %v", linha, err)
	}
}

func TestSomentePublico(t *testing.T) {
	for _, e := range []string{"127.0.0.1:443", "10.0.0.5:443", "172.18.0.1:443",
		"192.168.1.1:443", "169.254.169.254:443", "0.0.0.0:443", "[::1]:443", "[fd00::1]:443", "[fe80::1]:443"} {
		if somentePublico("tcp", e, nil) == nil {
			t.Errorf("%s deveria ser recusado", e)
		}
	}
	if err := somentePublico("tcp", "1.1.1.1:443", nil); err != nil {
		t.Errorf("endereço público recusado: %v", err)
	}
}

func TestRepasse(t *testing.T) {
	destino := eco(t)
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	go repassar(l, destino.Addr().String())
	c, err := net.Dial("tcp", l.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	fmt.Fprint(c, "ola\n")
	if linha, err := bufio.NewReader(c).ReadString('\n'); err != nil || linha != "ola\n" {
		t.Fatalf("repasse: %q %v", linha, err)
	}
}
