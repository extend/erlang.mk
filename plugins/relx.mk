# Copyright (c) 2013-2014, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: distclean-rel

# Configuration.

RELX_CONFIG ?= $(CURDIR)/relx.config

ifneq ($(wildcard $(RELX_CONFIG)),)

RELX ?= $(CURDIR)/relx
export RELX

RELX_URL ?= https://github.com/erlware/relx/releases/download/v1.0.2/relx
RELX_OPTS ?=
RELX_OUTPUT_DIR ?= _rel

ifeq ($(firstword $(RELX_OPTS)),-o)
	RELX_OUTPUT_DIR = $(word 2,$(RELX_OPTS))
endif

# Core targets.

rel:: distclean-rel $(RELX)
	@if [ -z "$$(grep -E '{modules,[[:space:]]*\[\]}' src/$(PROJECT).app.src)" ]; then \
		echo "WARNING: empty modules entry not found in src/$(PROJECT).app.src. This may result in relx release failure." \
		"See README for details."; \
	fi
	@$(RELX) -c $(RELX_CONFIG) $(RELX_OPTS)

distclean:: distclean-rel distclean-relx

# Plugin-specific targets.

define relx_fetch
	$(call core_http_get,$(RELX),$(RELX_URL))
	chmod +x $(RELX)
endef

$(RELX):
	@$(call relx_fetch)

distclean-rel:
	$(gen_verbose) rm -rf $(RELX_OUTPUT_DIR)

distclean-relx:
	$(gen_verbose) rm -rf $(RELX)

endif
