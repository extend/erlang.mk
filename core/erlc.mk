# Copyright (c) 2013-2014, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: clean-app

# Configuration.

ERLC_OPTS ?= -Werror +debug_info +warn_export_vars +warn_shadow_vars \
	+warn_obsolete_guard # +bin_opt_info +warn_export_all +warn_missing_spec
COMPILE_FIRST ?=
COMPILE_FIRST_PATHS = $(addprefix src/,$(addsuffix .erl,$(COMPILE_FIRST)))
ERLC_EXCLUDE ?=
ERLC_EXCLUDE_PATHS = $(addprefix src/,$(addsuffix .erl,$(ERLC_EXCLUDE)))

ERLC_MIB_OPTS ?=
COMPILE_MIB_FIRST ?=
COMPILE_MIB_FIRST_PATHS = $(addprefix mibs/,$(addsuffix .mib,$(COMPILE_MIB_FIRST)))

# Verbosity.

appsrc_verbose_0 = @echo " APP   " $(PROJECT).app.src;
appsrc_verbose = $(appsrc_verbose_$(V))

erlc_verbose_0 = @echo " ERLC  " $(filter-out $(patsubst %,%.erl,$(ERLC_EXCLUDE)),\
	$(filter %.erl %.core,$(?F)));
erlc_verbose = $(erlc_verbose_$(V))

xyrl_verbose_0 = @echo " XYRL  " $(filter %.xrl %.yrl,$(?F));
xyrl_verbose = $(xyrl_verbose_$(V))

mib_verbose_0 = @echo " MIB   " $(filter %.bin %.mib,$(?F));
mib_verbose = $(mib_verbose_$(V))

# Core targets.

app:: erlc-include ebin/$(PROJECT).app
	$(eval MODULES := $(shell find ebin -type f -name \*.beam \
		| sed "s/ebin\//'/;s/\.beam/',/" | sed '$$s/.$$//'))
	@if [ -z "$$(grep -E '^[^%]*{modules,' src/$(PROJECT).app.src)" ]; then \
		echo "Empty modules entry not found in $(PROJECT).app.src. Please consult the erlang.mk README for instructions." >&2; \
		exit 1; \
	fi
	$(eval GITDESCRIBE := $(shell git describe --dirty --abbrev=7 --tags --always --first-parent 2>/dev/null || true))
	$(appsrc_verbose) cat src/$(PROJECT).app.src \
		| sed "s/{modules,[[:space:]]*\[\]}/{modules, \[$(MODULES)\]}/" \
		| sed "s/{id,[[:space:]]*\"git\"}/{id, \"$(GITDESCRIBE)\"}/" \
		> ebin/$(PROJECT).app

define compile_erl
	$(erlc_verbose) erlc -v $(ERLC_OPTS) -o ebin/ \
		-pa ebin/ -I include/ $(filter-out $(ERLC_EXCLUDE_PATHS),\
		$(COMPILE_FIRST_PATHS) $(1))
endef

define compile_xyrl
	$(xyrl_verbose) erlc -v -o ebin/ $(1)
	$(xyrl_verbose) erlc $(ERLC_OPTS) -o ebin/ ebin/*.erl
	@rm ebin/*.erl
endef

define compile_mib
	$(mib_verbose) erlc -v $(ERLC_MIB_OPTS) -o priv/mibs/ \
		-I priv/mibs/ $(COMPILE_MIB_FIRST_PATHS) $(1)
	$(mib_verbose) erlc -o include/ -- priv/mibs/*.bin
endef

ifneq ($(wildcard src/),)
ebin/$(PROJECT).app::
	@mkdir -p ebin/

ifneq ($(wildcard mibs/),)
ebin/$(PROJECT).app:: $(shell find mibs -type f -name \*.mib)
	@mkdir -p priv/mibs/ include
	$(if $(strip $?),$(call compile_mib,$?))
endif

ebin/$(PROJECT).app:: $(shell find src -type f -name \*.erl) \
		$(shell find src -type f -name \*.core)
	$(if $(strip $?),$(call compile_erl,$?))

ebin/$(PROJECT).app:: $(shell find src -type f -name \*.xrl) \
		$(shell find src -type f -name \*.yrl)
	$(if $(strip $?),$(call compile_xyrl,$?))
endif

clean:: clean-app

# Extra targets.

erlc-include:
	-@if [ -d ebin/ ]; then \
		find include/ src/ -type f -name \*.hrl -newer ebin -exec touch $(shell find src/ -type f -name "*.erl") \; 2>/dev/null || printf ''; \
	fi

clean-app:
	$(gen_verbose) rm -rf ebin/ priv/mibs/ \
		$(addprefix include/,$(addsuffix .hrl,$(notdir $(basename $(wildcard mibs/*.mib)))))
