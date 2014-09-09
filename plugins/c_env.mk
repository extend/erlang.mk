# Copyright (c) 2014, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: clean-c_env
# todo

# Configuration.

C_SRC_ENV ?= env.mk


# Verbosity.

c_src_verbose_0 = @echo " C_SRC " $(?F);
c_src_verbose = $(appsrc_verbose_$(V))


# Targets.

app:: $(C_SRC_ENV)

$(C_SRC_ENV):
	erl -noshell -noinput -eval "file:write_file(\"$(C_SRC_ENV)\", \
		io_lib:format(\"ERTS_INCLUDE_DIR ?= ~s/erts-~s/include/\", \
			[code:root_dir(), erlang:system_info(version)])), \
		init:stop()."

-include $(C_SRC_ENV)

clean:: clean-c_env

clean-c_env:
	$(gen_verbose) rm -f $(C_SRC_ENV)
