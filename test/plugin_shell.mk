# Shell plugin.

SHELL_CASES = default kjell
SHELL_TARGETS = $(addprefix shell-,$(SHELL_CASES))
SHELL_CLEAN_TARGETS = $(addprefix clean-,$(SHELL_TARGETS))

.PHONY: shell $(C_SRC_TARGETS) clean-shell $(SHELL_CLEAN_TARGETS)

clean-shell: $(SHELL_CLEAN_TARGETS)

$(SHELL_CLEAN_TARGETS):
	$t rm -fr $(APP_TO_CLEAN)/

shell: $(SHELL_TARGETS)

shell-default: build clean-shell-default

	$i "Bootstrap a new OTP library named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap-lib $v

	$i "Run the shell"
	$t $(MAKE) -C $(APP) shell SHELL_OPTS="-eval 'halt()'" $v

shell-kjell: build clean-shell-kjell

	$i "Bootstrap a new OTP library named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap-lib $v

	$i "Add Kjell to the list of shell dependencies and set as default shell"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "SHELL_DEPS = kjell\nSHELL_ERL = \$$(DEPS_DIR)/kjell/bin/kjell\n"}' $(APP)/Makefile

	$i "Run the shell"
	$t $(MAKE) -C $(APP) shell SHELL_OPTS="-eval 'halt()'" $v
