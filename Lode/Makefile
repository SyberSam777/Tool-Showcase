# ---- Config: override via env or command line. Nothing baked into the binary. ----
REGISTRY       ?= ghcr.io
IMAGE_REPO     ?= jlawrence/lode
IMAGE_TAG      ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
IMG            ?= $(REGISTRY)/$(IMAGE_REPO):$(IMAGE_TAG)
TARGET         ?= x86_64-unknown-linux-musl
PLATFORMS      ?= linux/amd64,linux/arm64
NAMESPACE      ?= observability
CONTAINER_TOOL ?= podman
KUBECTL        ?= kubectl
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

.PHONY: fmt clippy test audit verify
fmt:    ; cargo fmt --all
clippy: ## lint with warnings as errors
	cargo clippy --all-targets --all-features -- -D warnings
test:   ; cargo test --all-features
audit:  ## supply-chain gates
	cargo audit && cargo deny check bans licenses sources
verify: fmt clippy test audit ## everything CI runs

.PHONY: build
build: ## static musl release build
	cargo build --release --target $(TARGET)
	@f=target/$(TARGET)/release/lode; \
	 ldd $$f 2>&1 | grep -q 'not a dynamic executable' \
	   && echo ">>> static OK" \
	   || { echo ">>> ERROR: dynamically linked, scratch image will not run"; exit 1; }

.PHONY: image import push
image: build ## build container image
	$(CONTAINER_TOOL) build --platform=$(PLATFORMS) -t $(IMG) .
import: image ## side-load into RKE2 containerd (no registry)
	$(CONTAINER_TOOL) save --format oci-archive -o /tmp/lode.tar $(IMG)
	sudo ctr -n k8s.io images import /tmp/lode.tar
push: ; $(CONTAINER_TOOL) push $(IMG)

.PHONY: sbom sign
sbom: ; syft $(IMG) -o spdx-json=dist/lode-sbom.spdx.json
sign: ; cosign sign --yes $(IMG)

.PHONY: deploy logs
deploy: ## deploy DaemonSet (APPLY=true to commit)
	$(KUBECTL) apply -n $(NAMESPACE) -f deploy/ $(DRYRUN_FLAG)
logs: ; $(KUBECTL) -n $(NAMESPACE) logs -l app=lode --tail=100 -f
