# ---- Config (override on the command line or via env; nothing is baked in) ----
REGISTRY        ?= ghcr.io
IMAGE_REPO      ?= jlawrence/baton
IMAGE_TAG       ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
IMG             ?= $(REGISTRY)/$(IMAGE_REPO):$(IMAGE_TAG)
PLATFORMS       ?= linux/amd64,linux/arm64
NAMESPACE       ?= baton-system
KUBECTL         ?= kubectl
CONTAINER_TOOL  ?= podman
GO              ?= go
APPLY           ?= false          # dry-run by default; make deploy APPLY=true to commit

ifeq ($(APPLY),true)
  DRYRUN_FLAG :=
else
  DRYRUN_FLAG := --dry-run=server
endif

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

.PHONY: generate
generate: ## controller-gen deepcopy
	controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./api/..."

.PHONY: manifests
manifests: ## controller-gen CRDs + RBAC
	controller-gen crd rbac:roleName=baton-manager paths="./..." output:crd:artifacts:config=config/crd/bases

.PHONY: fmt vet lint test
fmt: ; $(GO) fmt ./...
vet: ; $(GO) vet ./...
lint: ## golangci-lint
	golangci-lint run --timeout=5m
test: ## unit tests with race detector
	$(GO) test ./... -race -coverprofile=cover.out

.PHONY: build
build: ## build the manager binary
	CGO_ENABLED=0 $(GO) build -trimpath -ldflags "-s -w -X main.version=$(IMAGE_TAG)" -o bin/manager ./cmd/manager

.PHONY: run
run: ## run controller locally against current kubecontext (dry-run)
	$(GO) run ./cmd/manager --namespace=$(NAMESPACE) --dry-run=$(if $(filter true,$(APPLY)),false,true)

.PHONY: image
image: ## build multi-arch image
	$(CONTAINER_TOOL) build --platform=$(PLATFORMS) -t $(IMG) .

.PHONY: push
push: ; $(CONTAINER_TOOL) push $(IMG)

.PHONY: sbom sign
sbom: ## generate SPDX SBOM
	syft $(IMG) -o spdx-json=dist/baton-sbom.spdx.json
sign: ## keyless cosign signature
	cosign sign --yes $(IMG)

.PHONY: install uninstall deploy
install: manifests ## install CRDs
	$(KUBECTL) apply -f config/crd/bases $(DRYRUN_FLAG)
uninstall: ; $(KUBECTL) delete -f config/crd/bases --ignore-not-found
deploy: manifests ## deploy controller (APPLY=true to commit)
	$(KUBECTL) apply -k config/default $(DRYRUN_FLAG)

.PHONY: verify
verify: fmt vet lint test ## everything CI runs
