package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const (
	serviceName = "ksh-devops-demo"
	defaultPort = "8080"
)

var (
	version   = "dev"
	commit    = "unknown"
	buildTime = "unknown"
)

type response struct {
	Service   string `json:"service"`
	Status    string `json:"status,omitempty"`
	Version   string `json:"version,omitempty"`
	Commit    string `json:"commit,omitempty"`
	BuildTime string `json:"build_time,omitempty"`
}

func writeJSON(
	w http.ResponseWriter,
	statusCode int,
	payload response,
) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("failed to encode response: %v", err)
	}
}

func rootHandler(
	w http.ResponseWriter,
	r *http.Request,
) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	writeJSON(
		w,
		http.StatusOK,
		response{
			Service: serviceName,
			Status:  "ok",
			Version: version,
			Commit:  commit,
		},
	)
}

func healthHandler(
	w http.ResponseWriter,
	r *http.Request,
) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	writeJSON(
		w,
		http.StatusOK,
		response{
			Service: serviceName,
			Status:  "healthy",
		},
	)
}

func readyHandler(
	w http.ResponseWriter,
	r *http.Request,
) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	writeJSON(
		w,
		http.StatusOK,
		response{
			Service: serviceName,
			Status:  "ready",
		},
	)
}

func versionHandler(
	w http.ResponseWriter,
	r *http.Request,
) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	writeJSON(
		w,
		http.StatusOK,
		response{
			Service:   serviceName,
			Version:   version,
			Commit:    commit,
			BuildTime: buildTime,
		},
	)
}

func newHandler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/", rootHandler)
	mux.HandleFunc("/healthz", healthHandler)
	mux.HandleFunc("/readyz", readyHandler)
	mux.HandleFunc("/version", versionHandler)

	return mux
}

func main() {
	port := os.Getenv("PORT")

	if port == "" {
		port = defaultPort
	}

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           newHandler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf(
			"starting %s version=%s commit=%s port=%s",
			serviceName,
			version,
			commit,
			port,
		)

		err := server.ListenAndServe()

		if err != nil &&
			!errors.Is(err, http.ErrServerClosed) {

			log.Fatalf(
				"server failed: %v",
				err,
			)
		}
	}()

	stop := make(
		chan os.Signal,
		1,
	)

	signal.Notify(
		stop,
		syscall.SIGTERM,
		syscall.SIGINT,
	)

	<-stop

	log.Printf(
		"shutting down %s",
		serviceName,
	)

	ctx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf(
			"graceful shutdown failed: %v",
			err,
		)
	}

	log.Printf(
		"%s stopped",
		serviceName,
	)
}
