package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func executeRequest(
	t *testing.T,
	method string,
	path string,
) *httptest.ResponseRecorder {
	t.Helper()

	request := httptest.NewRequest(
		method,
		path,
		nil,
	)

	responseRecorder := httptest.NewRecorder()

	newHandler().ServeHTTP(
		responseRecorder,
		request,
	)

	return responseRecorder
}

func decodeResponse(
	t *testing.T,
	recorder *httptest.ResponseRecorder,
) response {
	t.Helper()

	var body response

	if err := json.NewDecoder(
		recorder.Body,
	).Decode(&body); err != nil {

		t.Fatalf(
			"failed to decode response: %v",
			err,
		)
	}

	return body
}

func TestRootHandler(t *testing.T) {
	recorder := executeRequest(
		t,
		http.MethodGet,
		"/",
	)

	if recorder.Code != http.StatusOK {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusOK,
			recorder.Code,
		)
	}

	body := decodeResponse(
		t,
		recorder,
	)

	if body.Service != serviceName {
		t.Fatalf(
			"expected service %q, got %q",
			serviceName,
			body.Service,
		)
	}

	if body.Status != "ok" {
		t.Fatalf(
			"expected status %q, got %q",
			"ok",
			body.Status,
		)
	}
}

func TestHealthHandler(t *testing.T) {
	recorder := executeRequest(
		t,
		http.MethodGet,
		"/healthz",
	)

	if recorder.Code != http.StatusOK {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusOK,
			recorder.Code,
		)
	}

	body := decodeResponse(
		t,
		recorder,
	)

	if body.Status != "healthy" {
		t.Fatalf(
			"expected health status %q, got %q",
			"healthy",
			body.Status,
		)
	}
}

func TestReadyHandler(t *testing.T) {
	recorder := executeRequest(
		t,
		http.MethodGet,
		"/readyz",
	)

	if recorder.Code != http.StatusOK {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusOK,
			recorder.Code,
		)
	}

	body := decodeResponse(
		t,
		recorder,
	)

	if body.Status != "ready" {
		t.Fatalf(
			"expected readiness status %q, got %q",
			"ready",
			body.Status,
		)
	}
}

func TestVersionHandler(t *testing.T) {
	originalVersion := version
	originalCommit := commit
	originalBuildTime := buildTime

	t.Cleanup(
		func() {
			version = originalVersion
			commit = originalCommit
			buildTime = originalBuildTime
		},
	)

	version = "v1.0.0"
	commit = "test-commit"
	buildTime = "2026-09-24T00:00:00Z"

	recorder := executeRequest(
		t,
		http.MethodGet,
		"/version",
	)

	if recorder.Code != http.StatusOK {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusOK,
			recorder.Code,
		)
	}

	body := decodeResponse(
		t,
		recorder,
	)

	if body.Version != version {
		t.Fatalf(
			"expected version %q, got %q",
			version,
			body.Version,
		)
	}

	if body.Commit != commit {
		t.Fatalf(
			"expected commit %q, got %q",
			commit,
			body.Commit,
		)
	}

	if body.BuildTime != buildTime {
		t.Fatalf(
			"expected build time %q, got %q",
			buildTime,
			body.BuildTime,
		)
	}
}

func TestUnknownPath(t *testing.T) {
	recorder := executeRequest(
		t,
		http.MethodGet,
		"/does-not-exist",
	)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusNotFound,
			recorder.Code,
		)
	}
}

func TestMethodNotAllowed(t *testing.T) {
	recorder := executeRequest(
		t,
		http.MethodPost,
		"/healthz",
	)

	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusMethodNotAllowed,
			recorder.Code,
		)
	}
}
