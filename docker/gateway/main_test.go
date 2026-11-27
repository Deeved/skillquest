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

func echo(t *testing.T) net.Listener {
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

func request(t *testing.T, server, line string) (net.Conn, *bufio.Reader, int) {
	t.Helper()
	c, err := net.Dial("tcp", server)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	fmt.Fprintf(c, "%s HTTP/1.1\r\nHost: teste\r\n\r\n", line)
	r := bufio.NewReader(c)
	resp, err := http.ReadResponse(r, &http.Request{Method: http.MethodConnect})
	if err != nil {
		t.Fatal(err)
	}
	return c, r, resp.StatusCode
}

func TestProxy(t *testing.T) {
	upstream := echo(t)
	var dialed []string
	srv := httptest.NewServer(&proxy{
		allowed: parseList("api.anthropic.com"),
		connect: func(a string) (net.Conn, error) {
			dialed = append(dialed, a)
			return net.Dial("tcp", upstream.Addr().String())
		},
	})
	defer srv.Close()
	addr := srv.Listener.Addr().String()

	rejected := map[string]int{
		"CONNECT exemplo.com:443":                   403,
		"CONNECT api.anthropic.com:22":              403,
		"CONNECT api.anthropic.com.exemplo.com:443": 403,
		"CONNECT x.api.anthropic.com:443":           403,
		"CONNECT 127.0.0.1:443":                     403,
		"GET http://api.anthropic.com/":             405,
	}
	for line, want := range rejected {
		if _, _, status := request(t, addr, line); status != want {
			t.Errorf("%s: status %d, esperado %d", line, status, want)
		}
	}
	if len(dialed) != 0 {
		t.Fatalf("pedido recusado abriu conexão: %v", dialed)
	}

	c, r, status := request(t, addr, "CONNECT API.Anthropic.com:443")
	if status != 200 {
		t.Fatalf("permitido: status %d", status)
	}
	fmt.Fprint(c, "ola\n")
	if line, err := r.ReadString('\n'); err != nil || line != "ola\n" {
		t.Fatalf("túnel: %q %v", line, err)
	}
}

func TestPublicOnly(t *testing.T) {
	for _, a := range []string{"127.0.0.1:443", "10.0.0.5:443", "172.18.0.1:443",
		"192.168.1.1:443", "169.254.169.254:443", "0.0.0.0:443", "[::1]:443", "[fd00::1]:443", "[fe80::1]:443"} {
		if publicOnly("tcp", a, nil) == nil {
			t.Errorf("%s deveria ser recusado", a)
		}
	}
	if err := publicOnly("tcp", "1.1.1.1:443", nil); err != nil {
		t.Errorf("endereço público recusado: %v", err)
	}
}

func TestForward(t *testing.T) {
	upstream := echo(t)
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	go forward(l, upstream.Addr().String())
	c, err := net.Dial("tcp", l.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	fmt.Fprint(c, "ola\n")
	if line, err := bufio.NewReader(c).ReadString('\n'); err != nil || line != "ola\n" {
		t.Fatalf("repasse: %q %v", line, err)
	}
}
