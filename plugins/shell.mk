# Copyright (c) 2014, M Robert Martin <rob@version2beta.com>
# This file is contributed to erlang.mk and subject to the terms of the ISC License.

.PHONY: shell

# Configuration.

SHELL_PATH ?= -pa ../$(PROJECT)/ebin $(DEPS_DIR)/*/ebin
SHELL_OPTS ?=

ALL_SHELL_DEPS_DIRS = $(addprefix $(DEPS_DIR)/,$(SHELL_DEPS))

# Core targets

help::
	@printf "%s\n" "" \
		"Shell targets:" \
		"  shell              Run an erlang shell with SHELL_OPTS or reasonable default"

# Plugin-specific targets.

$(foreach dep,$(SHELL_DEPS),$(eval $(call dep_target,$(dep))))

build-shell-deps: $(ALL_SHELL_DEPS_DIRS)
	@for dep in $(ALL_SHELL_DEPS_DIRS) ; do $(MAKE) -C $$dep ; done

shell: build-shell-deps
	$(gen_verbose) erl $(SHELL_PATH) $(SHELL_OPTS)
