# Copyright (c) 2015-2016, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: rebar.config

# We strip out -Werror because we don't want to fail due to
# warnings when used as a dependency.

compat_prepare_erlc_opts = $(shell echo "$1" | sed 's/, */,/g')

define compat_convert_erlc_opts
$(if $(filter-out -Werror,$1),\
	$(if $(findstring +,$1),\
		$(shell echo $1 | cut -b 2-)))
endef

define compat_erlc_opts_to_list
[$(call comma_list,$(foreach o,$(call compat_prepare_erlc_opts,$1),$(call compat_convert_erlc_opts,$o)))]
endef

define compat_rebar_config
{deps, [
$(call comma_list,$(foreach d,$(DEPS),\
	$(if $(filter hex,$(call dep_fetch,$d)),\
		{$(call dep_name,$d)$(comma)"$(call dep_repo,$d)"},\
		{$(call dep_name,$d)$(comma)".*"$(comma){git,"$(call dep_repo,$d)"$(comma){ref,"$(call dep_commit,$d)"}}})))
]}.
{erl_opts, $(call compat_erlc_opts_to_list,$(ERLC_OPTS))}.
endef

rebar.config:
	$(gen_verbose) $(call core_render,compat_rebar_config,rebar.config)
