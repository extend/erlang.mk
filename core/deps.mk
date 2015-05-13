# Copyright (c) 2013-2015, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: distclean-deps distclean-pkg pkg-list pkg-search

# Configuration.

AUTOPATCH ?= edown gen_leader gproc
export AUTOPATCH

DEPS_DIR ?= $(CURDIR)/deps
export DEPS_DIR

REBAR_DEPS_DIR = $(DEPS_DIR)
export REBAR_DEPS_DIR

ALL_DEPS_DIRS = $(addprefix $(DEPS_DIR)/,$(DEPS))
BUILD_DEPS_DIRS = $(filter-out $(addprefix $(DEPS_DIR)/,$(DEPS_FETCH_ONLY)), $(ALL_DEPS_DIRS))

ifeq ($(filter $(DEPS_DIR),$(subst :, ,$(ERL_LIBS))),)
ifeq ($(ERL_LIBS),)
	ERL_LIBS = $(DEPS_DIR)
else
	ERL_LIBS := $(ERL_LIBS):$(DEPS_DIR)
endif
endif
export ERL_LIBS

PKG_FILE2 ?= $(CURDIR)/.erlang.mk.packages.v2
export PKG_FILE2

PKG_FILE_URL ?= https://raw.githubusercontent.com/ninenines/erlang.mk/master/packages.v2.tsv

# Verbosity.

dep_verbose_0 = @echo " DEP   " $(1);
dep_verbose = $(dep_verbose_$(V))

# Core targets.

ifneq ($(SKIP_DEPS),)
deps::
else
deps:: $(ALL_DEPS_DIRS)
	@for dep in $(BUILD_DEPS_DIRS) ; do \
		if [ -f $$dep/GNUmakefile ] || [ -f $$dep/makefile ] || [ -f $$dep/Makefile ] ; then \
			$(MAKE) -C $$dep IS_DEP=1 || exit $$? ; \
		else \
			echo "ERROR: No makefile to build dependency $$dep. Consider adding it to AUTOPATCH." ; \
			exit 1 ; \
		fi ; \
	done
endif

distclean:: distclean-deps distclean-pkg

# Deps related targets.

# @todo rename GNUmakefile and makefile into Makefile first, if they exist
# While Makefile file could be GNUmakefile or makefile,
# in practice only Makefile is needed so far.
define dep_autopatch
	if [ -f $(DEPS_DIR)/$(1)/Makefile ]; then \
		if [ 0 != `grep -ci rebar $(DEPS_DIR)/$(1)/Makefile` ]; then \
			$(call dep_autopatch2,$(1)); \
		else \
			$(call dep_autopatch_erlang_mk,$(1)); \
		fi \
	else \
		$(call dep_autopatch2,$(1)); \
	fi
endef

define dep_autopatch2
	if [ ! -f $(DEPS_DIR)/$(1)/rebar.config ]; then \
		$(call dep_autopatch_gen,$(1)); \
	else \
		$(call dep_autopatch_rebar,$(1)); \
	fi
endef

# Overwrite erlang.mk with the current file by default.
ifeq ($(NO_AUTOPATCH_ERLANG_MK),)
define dep_autopatch_erlang_mk
	rm -f $(DEPS_DIR)/$(1)/erlang.mk; \
	cd $(DEPS_DIR)/$(1)/ && ln -s ../../erlang.mk; \
	$(call erlang,$(call dep_autopatch_appsrc.erl,$(1)))
endef
else
define dep_autopatch_erlang_mk
	$(call erlang,$(call dep_autopatch_appsrc.erl,$(1)))
endef
endif

define dep_autopatch_gen
	printf "%s\n" \
		"ERLC_OPTS = +debug_info" \
		"include ../../erlang.mk" > $(DEPS_DIR)/$(1)/Makefile; \
	$(call erlang,$(call dep_autopatch_appsrc.erl,$(1)))
endef

define dep_autopatch_rebar
	rm -f $(DEPS_DIR)/$(1)/Makefile; \
	$(call erlang,$(call dep_autopatch_rebar.erl,$(1))); \
	$(call erlang,$(call dep_autopatch_appsrc.erl,$(1)))
endef

define dep_autopatch_rebar.erl
	{ok, Conf} = file:consult("$(DEPS_DIR)/$(1)/rebar.config"),
	Write = fun (Text) ->
		file:write_file("$(DEPS_DIR)/$(1)/Makefile", Text, [append])
	end,
	Write("ERLC_OPTS = +debug_info\n\n"),
	fun() ->
		File = case lists:keyfind(deps, 1, Conf) of
			false -> [];
			{_, Deps} ->
				[begin
					Name = element(1, Dep),
					{Method, Repo, Commit} = case element(3, Dep) of
						{git, R} -> {git, R, master};
						{M, R, {branch, C}} -> {M, R, C};
						{M, R, {tag, C}} -> {M, R, C};
						{M, R, C} -> {M, R, C}
					end,
					Write(io_lib:format("DEPS += ~s\ndep_~s = ~s ~s ~s~n", [Name, Name, Method, Repo, Commit])),
					Opts = case size(Dep) of 4 -> element(4, Dep); _ -> [] end,
					case lists:any(fun(O) -> if O == raw -> true; true -> false end end, Opts) of
						true -> Write(io_lib:format("DEPS_FETCH_ONLY += ~s~n", [Name]));
						false -> true
					end
				end || Dep <- Deps, tuple_size(Dep) > 2]
		end
	end(),
	fun() ->
		First = case lists:keyfind(erl_first_files, 1, Conf) of false -> []; {_, Files} ->
			Names = [[" ", begin "lre." ++ Elif = lists:reverse(F), lists:reverse(Elif) end]
				 || "src/" ++ F <- Files],
			Write(io_lib:format("COMPILE_FIRST +=~s\n", [Names]))
		end
	end(),
	case $(1) of
		proper -> Write("\n# Proper hack.\napp::\n\t./write_compile_flags include/compile_flags.hrl\n");
		_ -> ok
	end,
	Write("\ninclude ../../erlang.mk"),
	halt()
endef

define dep_autopatch_appsrc.erl
	AppSrcOut = "$(DEPS_DIR)/$(1)/src/$(1).app.src",
	AppSrcIn = case filelib:is_regular(AppSrcOut) of false -> "$(DEPS_DIR)/$(1)/ebin/$(1).app"; true -> AppSrcOut end,
	case filelib:is_regular(AppSrcIn) of
		false -> ok;
		true ->
			fun() ->
				{ok, [{application, $(1), L}]} = file:consult(AppSrcIn),
				L2 = case lists:keyfind(modules, 1, L) of {_, _} -> L; false -> [{modules, []}|L] end,
				L3 = case lists:keyfind(vsn, 1, L2) of {vsn, git} -> lists:keyreplace(vsn, 1, L2, {vsn, "git"}); _ -> L2 end,
				ok = file:write_file(AppSrcOut, io_lib:format("~p.~n", [{application, $(1), L3}]))
			end(),
			case AppSrcOut of AppSrcIn -> ok; _ -> ok = file:delete(AppSrcIn) end
	end,
	halt()
endef

define dep_fetch
	if [ "$$$$VS" = "git" ]; then \
		git clone -q -n -- $$$$REPO $(DEPS_DIR)/$(1); \
		cd $(DEPS_DIR)/$(1) && git checkout -q $$$$COMMIT; \
	elif [ "$$$$VS" = "hg" ]; then \
		hg clone -q -U $$$$REPO $(DEPS_DIR)/$(1); \
		cd $(DEPS_DIR)/$(1) && hg update -q $$$$COMMIT; \
	elif [ "$$$$VS" = "svn" ]; then \
		svn checkout -q $$$$REPO $(DEPS_DIR)/$(1); \
	elif [ "$$$$VS" = "cp" ]; then \
		cp -R $$$$REPO $(DEPS_DIR)/$(1); \
	else \
		echo "Unknown or invalid dependency: $(1). Please consult the erlang.mk README for instructions." >&2; \
		exit 78; \
	fi
endef

define dep_target
$(DEPS_DIR)/$(1):
	@mkdir -p $(DEPS_DIR)
ifeq (,$(dep_$(1)))
	@if [ ! -f $(PKG_FILE2) ]; then $(call core_http_get,$(PKG_FILE2),$(PKG_FILE_URL)); fi
	$(dep_verbose) DEPPKG=$$$$(awk 'BEGIN { FS = "\t" }; $$$$1 == "$(1)" { print $$$$2 " " $$$$3 " " $$$$4 }' $(PKG_FILE2);); \
	VS=$$$$(echo $$$$DEPPKG | cut -d " " -f1); \
	REPO=$$$$(echo $$$$DEPPKG | cut -d " " -f2); \
	COMMIT=$$$$(echo $$$$DEPPKG | cut -d " " -f3); \
	$(call dep_fetch,$(1))
else
ifeq (1,$(words $(dep_$(1))))
	$(dep_verbose) VS=git; \
	REPO=$(dep_$(1)); \
	COMMIT=master; \
	$(call dep_fetch,$(1))
else
ifeq (2,$(words $(dep_$(1))))
	$(dep_verbose) VS=git; \
	REPO=$(word 1,$(dep_$(1))); \
	COMMIT=$(word 2,$(dep_$(1))); \
	$(call dep_fetch,$(1))
else
	$(dep_verbose) VS=$(word 1,$(dep_$(1))); \
	REPO=$(word 2,$(dep_$(1))); \
	COMMIT=$(word 3,$(dep_$(1))); \
	$(call dep_fetch,$(1))
endif
endif
endif
ifeq ($(filter $(1),$(DEPS_FETCH_ONLY)),)
	@if [ -f $(DEPS_DIR)/$(1)/configure.ac ]; then \
		echo " AUTO  " $(1); \
		cd $(DEPS_DIR)/$(1) && autoreconf -vif; \
	fi
	-@if [ -f $(DEPS_DIR)/$(1)/configure ]; then \
		echo " CONF  " $(1); \
		cd $(DEPS_DIR)/$(1) && ./configure; \
	fi
ifeq ($(filter $(1),$(NO_AUTOPATCH)),)
	@$(call dep_autopatch,$(1))
endif
endif
endef

$(foreach dep,$(DEPS),$(eval $(call dep_target,$(dep))))

distclean-deps:
	$(gen_verbose) rm -rf $(DEPS_DIR)

# Packages related targets.

$(PKG_FILE2):
	@$(call core_http_get,$(PKG_FILE2),$(PKG_FILE_URL))

pkg-list: $(PKG_FILE2)
	@cat $(PKG_FILE2) | awk 'BEGIN { FS = "\t" }; { print \
		"Name:\t\t" $$1 "\n" \
		"Repository:\t" $$3 "\n" \
		"Website:\t" $$5 "\n" \
		"Description:\t" $$6 "\n" }'

ifdef q
pkg-search: $(PKG_FILE2)
	@cat $(PKG_FILE2) | grep -i ${q} | awk 'BEGIN { FS = "\t" }; { print \
		"Name:\t\t" $$1 "\n" \
		"Repository:\t" $$3 "\n" \
		"Website:\t" $$5 "\n" \
		"Description:\t" $$6 "\n" }'
else
pkg-search:
	$(error Usage: make pkg-search q=STRING)
endif

ifeq ($(PKG_FILE2),$(CURDIR)/.erlang.mk.packages.v2)
distclean-pkg:
	$(gen_verbose) rm -f $(PKG_FILE2)
endif

help::
	@printf "%s\n" "" \
		"Package-related targets:" \
		"  pkg-list              List all known packages" \
		"  pkg-search q=STRING   Search for STRING in the package index"
