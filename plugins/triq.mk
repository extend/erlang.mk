# Copyright (c) 2015-2016, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

ifeq ($(filter triq,$(DEPS) $(TEST_DEPS)),triq)
.PHONY: triq

# Targets.

tests:: triq

define triq_check.erl
	$(call cover.erl)
	code:add_pathsa([
		"$(call core_native_path,$(CURDIR)/ebin)",
		"$(call core_native_path,$(DEPS_DIR)/*/ebin)",
		"$(call core_native_path,$(TEST_DIR))"]),
	try begin
		CoverSetup(),
		Res = case $(1) of
			all -> [true] =:= lists:usort([triq:check(M) || M <- [$(call comma_list,$(3))]]);
			module -> triq:check($(2));
			function -> triq:check($(2))
		end,
		CoverExport("$(COVER_DATA_DIR)/triq.coverdata"),
		Res
	end of
		true -> halt(0);
		_ -> halt(1)
	catch error:undef$(if $V,:Stacktrace) ->
		io:format("Undefined property or module?~n$(if $V,~p~n)", [$(if $V,Stacktrace)]),
		halt(0)
	end.
endef

ifdef t
ifeq (,$(findstring :,$(t)))
triq: test-build cover-data-dir
	$(verbose) $(call erlang,$(call triq_check.erl,module,$(t)))
else
triq: test-build cover-data-dir
	$(verbose) echo Testing $(t)/0
	$(verbose) $(call erlang,$(call triq_check.erl,function,$(t)()))
endif
else
triq: test-build cover-data-dir
	$(eval MODULES := $(patsubst %,'%',$(sort $(notdir $(basename \
		$(wildcard ebin/*.beam) $(call core_find,$(TEST_DIR)/,*.beam))))))
	$(gen_verbose) $(call erlang,$(call triq_check.erl,all,undefined,$(MODULES)))
endif
endif
