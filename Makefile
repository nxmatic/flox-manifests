OUTPUT_DIR ?= $(CURDIR)/fleet
KUSTOMIZE ?= kustomize
YQ ?= yq
DASEL ?= dasel
PYTHON ?= python3
FIX_TOML ?= $(CURDIR)/bin/fix-toml-multiline.py

SHELL := bash
.SHELLFLAGS := -exu -o pipefail -c
.ONESHELL:

.PRECIOUS: $(OUTPUT_DIR)/%/.flox/env $(OUTPUT_DIR)/%/.flox/run $(BUILD_YAML)

FLOX_ENV_FILES := $(filter-out kustomization.yaml,$(wildcard *.yaml))
FLOX_ENV_NAMES := $(basename $(notdir $(FLOX_ENV_FILES)))
KUSTOMIZE_SOURCES := kustomization.yaml $(FLOX_ENV_FILES)
BUILD_YAML := $(OUTPUT_DIR)/.kustomize/flox.yaml

MANIFEST_TARGETS := $(addprefix $(OUTPUT_DIR)/,$(addsuffix /.flox/env/manifest.toml,$(FLOX_ENV_NAMES)))
ENV_JSON_TARGETS := $(addprefix $(OUTPUT_DIR)/,$(addsuffix /.flox/env.json,$(FLOX_ENV_NAMES)))
RENDER_TARGETS := $(MANIFEST_TARGETS) $(ENV_JSON_TARGETS)

.PHONY: all render clean-dist check-tools

all: render

render: check-tools clean-dist
	$(MAKE) $(RENDER_TARGETS)

clean-dist:
	@rm -rf "$(OUTPUT_DIR)"

check-tools:
	missing="";
	for cmd in $(KUSTOMIZE) $(YQ) $(DASEL); do
	  if ! command -v $$cmd >/dev/null 2>&1; then
	    missing="$$missing $$cmd";
	  fi;
	done;
	if [[ -n "$$missing" ]]; then
	  echo "Missing required commands:$$missing" >&2;
	  exit 1;
	fi;

$(BUILD_YAML): $(KUSTOMIZE_SOURCES)
	mkdir -p "$(dir $@)"
	$(KUSTOMIZE) build $(CURDIR) > "$@"

$(OUTPUT_DIR)/%/.flox/env:
	mkdir -p "$@"

$(OUTPUT_DIR)/%/.flox/run:
	mkdir -p "$@"

$(OUTPUT_DIR)/%/.flox/env/manifest.toml: $(BUILD_YAML) | $(OUTPUT_DIR)/%/.flox/env $(OUTPUT_DIR)/%/.flox/run
	$(YQ) eval "select(.kind == \"FloxEnvironment\" and .metadata.name == \"$*\") | .spec.manifest" "$(BUILD_YAML)" | \
		$(DASEL) -r yaml -w toml -f /dev/stdin > "$@"
	$(PYTHON) "$(FIX_TOML)" "$@"

$(OUTPUT_DIR)/%/.flox/env.json: $(BUILD_YAML) | $(OUTPUT_DIR)/%/.flox/env $(OUTPUT_DIR)/%/.flox/run
	$(YQ) eval "select(.kind == \"FloxEnvironment\" and .metadata.name == \"$*\") | .spec.env" "$(BUILD_YAML)" | \
		$(DASEL) -r yaml -w json -f /dev/stdin > "$@"
