# Copyright (c) 2013-2014, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: relx-rel distclean-relx-rel distclean-relx

# Configuration.

RELX_CONFIG ?= $(CURDIR)/relx.config

RELX ?= $(CURDIR)/relx
export RELX

RELX_URL ?= https://github.com/erlware/relx/releases/download/v1.0.2/relx
RELX_OPTS ?=
RELX_OUTPUT_DIR ?= _rel

ifeq ($(firstword $(RELX_OPTS)),-o)
	RELX_OUTPUT_DIR = $(word 2,$(RELX_OPTS))
endif

# Core targets.

ifneq ($(wildcard $(RELX_CONFIG)),)
rel:: distclean-relx-rel relx-rel
endif

distclean:: distclean-relx-rel distclean-relx

# Plugin-specific targets.

define relx_fetch
	$(call core_http_get,$(RELX),$(RELX_URL))
	chmod +x $(RELX)
endef

$(RELX):
	@$(call relx_fetch)

relx-rel: $(RELX)
	@$(RELX) -c $(RELX_CONFIG) $(RELX_OPTS)

distclean-relx-rel:
	$(gen_verbose) rm -rf $(RELX_OUTPUT_DIR)

distclean-relx:
	$(gen_verbose) rm -rf $(RELX)
