package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/quic-go/quic-go"
	"github.com/quic-go/quic-go/http3"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

const (
	h2cAddress = "127.0.0.1:18080"
	h3Address  = "127.0.0.1:18443"
)

func writeReadyLine(w io.Writer, text string) {
	_, _ = fmt.Fprintln(w, text)
	if f, ok := w.(*os.File); ok {
		_ = f.Sync()
	}
}

type packetLogger struct {
	net.PacketConn
	name string
}

func packetSummary(p []byte) string {
	if len(p) == 0 {
		return "empty"
	}
	if p[0]&0x80 == 0 {
		return fmt.Sprintf("short first=%02x len=%d", p[0], len(p))
	}
	if len(p) < 6 {
		return fmt.Sprintf("short-long first=%02x len=%d", p[0], len(p))
	}
	packetType := (p[0] >> 4) & 0x3
	version := uint32(p[1])<<24 | uint32(p[2])<<16 | uint32(p[3])<<8 | uint32(p[4])
	return fmt.Sprintf("long first=%02x type=%d version=%08x dcid_len=%d len=%d", p[0], packetType, version, int(p[5]), len(p))
}

// packetTraceEnabled mirrors REQBEST_INTEROP_TRACE: when set the server logs a
// one-line summary of every QUIC datagram, which is invaluable when debugging a
// handshake failure but far too noisy for a normal interop run.
var packetTraceEnabled = os.Getenv("REQBEST_INTEROP_TRACE") == "1"

func (c packetLogger) ReadFrom(p []byte) (int, net.Addr, error) {
	n, addr, err := c.PacketConn.ReadFrom(p)
	if packetTraceEnabled && n > 0 {
		log.Printf("%s read %d bytes from %v err=%v packet=%s", c.name, n, addr, err, packetSummary(p[:n]))
	}
	return n, addr, err
}

func (c packetLogger) WriteTo(p []byte, addr net.Addr) (int, error) {
	n, err := c.PacketConn.WriteTo(p, addr)
	if packetTraceEnabled && n > 0 {
		log.Printf("%s wrote %d bytes to %v err=%v packet=%s", c.name, n, addr, err, packetSummary(p[:n]))
	}
	return n, err
}

func interopHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("X-Reqbest-Interop", "golang")
	w.Header().Set("X-Reqbest-Proto", r.Proto)

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	switch r.URL.Path {
	case "/get":
		_, _ = fmt.Fprintf(w, "proto=%s method=%s path=%s", r.Proto, r.Method, r.URL.RequestURI())
	case "/post":
		_, _ = fmt.Fprintf(w, "proto=%s method=%s path=%s body=%s", r.Proto, r.Method, r.URL.RequestURI(), body)
	default:
		http.NotFound(w, r)
	}
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)
	certDir := os.Getenv("REQBEST_INTEROP_CERT_DIR")
	if certDir == "" {
		certDir = "tests/interop/certs"
	}
	certFile := filepath.Join(certDir, "localhost.crt")
	keyFile := filepath.Join(certDir, "localhost.key")
	certificate, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		log.Fatalf("load TLS certificate: %v", err)
	}

	h2cServer := &http2.Server{}
	h2cListener, err := net.Listen("tcp", h2cAddress)
	if err != nil {
		log.Fatalf("listen HTTP/2 h2c: %v", err)
	}
	go func() {
		server := &http.Server{
			Handler: h2c.NewHandler(http.HandlerFunc(interopHandler), h2cServer),
		}
		if err := server.Serve(h2cListener); err != nil && err != http.ErrServerClosed {
			log.Fatalf("serve HTTP/2 h2c: %v", err)
		}
	}()
	writeReadyLine(os.Stdout, "H2C_READY "+h2cListener.Addr().String())

	h3Listener, err := net.ListenPacket("udp", h3Address)
	if err != nil {
		log.Fatalf("listen HTTP/3 UDP: %v", err)
	}
	h3Server := &http3.Server{
		Addr:    h3Address,
		Handler: http.HandlerFunc(interopHandler),
		TLSConfig: &tls.Config{
			MinVersion:   tls.VersionTLS13,
			Certificates: []tls.Certificate{certificate},
		},
		QUICConfig: &quic.Config{
			Allow0RTT: false,
			// reqbest is currently a small, single-request QUIC implementation. Keep
			// the reference server tolerant enough to exercise interop without
			// dropping the connection for missing optional client frames.
			MaxIdleTimeout:  30 * time.Second,
			KeepAlivePeriod: 0,
		},
	}
	go func() {
		if err := h3Server.Serve(packetLogger{PacketConn: h3Listener, name: "h3"}); err != nil && err != http.ErrServerClosed {
			log.Fatalf("serve HTTP/3: %v", err)
		}
	}()
	writeReadyLine(os.Stdout, "H3_READY "+h3Listener.LocalAddr().String()+" cert="+certFile+" key="+keyFile)

	select {}
}
