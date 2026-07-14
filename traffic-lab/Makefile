# ---- Config: override via env or command line. ----
REGISTRY       ?= ghcr.io
IMAGE_OWNER    ?= jlawrence
IMAGE_TAG      ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
PLATFORMS      ?= linux/amd64,linux/arm64
NAMESPACE      ?= traffic-lab
CONTAINER_TOOL ?= podman
KUBECTL        ?= kubectl
GO             ?= go
BINARIES       ?= misbehave loadgen
APPLY          ?= false

ifeq ($(APPLY),true)
  DRYRUN_FLAG :=
else
  DRYRUN_FLAG := --dry-run=server
endif

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

.PHONY: fmt vet lint test verify
fmt:  ; $(GO) fmt ./...
vet:  ; $(GO) vet ./...
lint: ; golangci-lint run --timeout=5m
test: ; $(GO) test ./... -race
verify: fmt vet lint test ## everything CI runs

.PHONY: build
build: ## build all binaries
	@for b in $(BINARIES); do \
	  echo ">>> $$b"; \
	  CGO_ENABLED=0 $(GO) build -trimpath -ldflags "-s -w" -o bin/$$b ./cmd/$$b; \
	done

.PHONY: images import
images: ## build container images for every binary
	@for b in $(BINARIES); do \
	  $(CONTAINER_TOOL) build --platform=$(PLATFORMS) \
	    -f build/$$b/Dockerfile \
	    -t $(REGISTRY)/$(IMAGE_OWNER)/$$b:$(IMAGE_TAG) . ; \
	done
import: images ## side-load into RKE2 containerd
	@for b in $(BINARIES); do \
	  $(CONTAINER_TOOL) save --format oci-archive -o /tmp/$$b.tar $(REGISTRY)/$(IMAGE_OWNER)/$$b:$(IMAGE_TAG); \
	  sudo ctr -n k8s.io images import /tmp/$$b.tar; \
	done

.PHONY: deploy matrix clean
deploy: ## deploy harness (APPLY=true to commit)
	$(KUBECTL) apply -n $(NAMESPACE) -f deploy/ $(DRYRUN_FLAG)
matrix: ## run the full scenario matrix (dry-run unless APPLY=true)
	./hack/run-matrix.sh $(if $(filter true,$(APPLY)),--apply,)
clean: ; rm -rf bin/ results/
