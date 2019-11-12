# Package definition
PYTHON := Python
PYTHON_VERS := 2.7.16
PYTHON_DIR := $(PYTHON)-$(PYTHON_VERS)
# Increase this to enforce a recreation of the build cache
PYTHON_BUILD_ID := 0

PYTHON_BUILD := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-build
PYTHON_BUILD_UNCACHED := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-build-uncached
PYTHON_BUILD_PKG_UPLOAD := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-build-pkg-upload
PYTHON_BUILD_TMP_INSTALL := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-install-for-build
PYTHON_COMPILE := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-compile
PYTHON_INSTALL := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-install
PYTHON_PATCHING := $(BUILD_HELPER_DIR)/$(PYTHON_DIR)-patching

# HACK!
PYTHON_PACKAGE_DIR := $(PACKAGE_DIR)/$(PYTHON)
PYTHON_SITECUSTOMIZE_SOURCE := $(PYTHON_PACKAGE_DIR)/sitecustomize.py
PYTHON_SITECUSTOMIZE_COMPILED := $(PYTHON_PACKAGE_DIR)/sitecustomize.pyc

.PHONY: Python Python-install Python-skel Python-clean upstream

.NOTPARALLEL: $(PYTHON_INSTALL)

Python: $(PYTHON_BUILD)

Python-install: $(PYTHON_INSTALL)

# Environment variables
PATH_VAR := PATH="$(abspath bin):$$PATH"

CC_COMPILERS = gcc-9 clang-8 gcc-8 gcc-7 clang-6.0 clang-5.0 gcc-6 clang-4.0 gcc-5 clang-3.9 clang-3.8 clang-3.7 clang-3.6 clang-3.5 gcc-4.9 gcc clang
CXX_COMPILERS := g++-9 clang++-8 g++-8 clang++-7 g++-7 clang++-6.0 clang++-5.0 g++ clang++

$(PYTHON_BUILD): $(PYTHON_SITECUSTOMIZE_COMPILED)
	$(TOUCH) $@

PYTHON_BUILD_PKG_PATH := $(call build_pkg_path,$(PYTHON_DIR),$(PYTHON_BUILD_ID))

$(PYTHON_BUILD_PKG_PATH):
	$(call build_pkg_archive,$@,$(PYTHON_DIR),$(PYTHON_BUILD_ID),$(PYTHON_BUILD_UNCACHED))

$(PYTHON_BUILD_PKG_UPLOAD): $(PYTHON_BUILD_PKG_PATH)
	$(call unpack_pkg_archive,$(PYTHON_BUILD_PKG_PATH),$(PYTHON_DIR))
	$(call upload_pkg_archive,$(PYTHON_BUILD_PKG_PATH),$(PYTHON_DIR),$(PYTHON_BUILD_ID))
	$(TOUCH) $@

$(PYTHON_BUILD_UNCACHED): $(PYTHON_COMPILE)
	$(TOUCH) $@

$(PYTHON_COMPILE): $(PYTHON_PATCHING) bin/gcc bin/g++
# Things are a bit tricky here: For PGO/LTO we need a rather recent compiler,
# but we don't want to bake paths to our build system into _sysconfigdata and
# friends. Workaround: Find a recent compiler to be used for building and make a
# symlink for it under a generic name. :-P Furthermore, the build with PGO/LTO
# enables is mainly sequential, so a high build parallelism doesn't really
# help. Therefore we use just -j2.
	cd $(PYTHON_DIR) ; $(PATH_VAR) ; \
	$(TEST) "$(DISTRO_NAME)" = "SLES" && sed -i 's,#include <panel.h>,#include <ncurses/panel.h>,' Modules/_curses_panel.c ; \
	./configure \
	    --prefix="" \
	    --enable-shared \
	    --enable-unicode=ucs4 \
	    --with-ensurepip=install \
	    $(PYTHON_ENABLE_OPTIMIZATIONS) \
	    LDFLAGS="-Wl,--rpath,$(OMD_ROOT)/lib"
	cd $(PYTHON_DIR) ; $(PATH_VAR) ; $(MAKE) -j2
	$(TOUCH) $@

# Install python files (needed by dependent packages like mod_python,
# python-modules, ...) during compilation and install targets.
# NOTE: -j1 seems to be necessary when --enable-optimizations is used
$(PYTHON_BUILD_TMP_INSTALL): $(PYTHON_BUILD_PKG_UPLOAD)
	$(PATH_VAR) ; $(MAKE) -j1 -C $(PYTHON_DIR) DESTDIR=$(PACKAGE_PYTHON_DESTDIR) install
	$(TOUCH) $@

$(PYTHON_SITECUSTOMIZE_COMPILED): $(PYTHON_SITECUSTOMIZE_SOURCE) $(PYTHON_BUILD_TMP_INSTALL)
	export PYTHONPATH="$$PYTHONPATH:$(PACKAGE_PYTHON_PYTHONPATH)" ; \
	export LDFLAGS="$(PACKAGE_PYTHON_LDFLAGS)" ; \
	export LD_LIBRARY_PATH="$(PACKAGE_PYTHON_LD_LIBRARY_PATH)" ; \
	$(PACKAGE_PYTHON_EXECUTABLE) -m py_compile $<

# The compiler detection code below is basically what part of AC_PROC_CXX does.
bin/gcc:
	@CC="" ; \
	for PROG in $(CC_COMPILERS); do \
	    echo -n "checking for $$PROG... "; SAVED_IFS=$$IFS; IFS=: ; \
	    for DIR in $$PATH; do \
	        IFS=$$SAVED_IFS ; \
	        $(TEST) -z "$$DIR" && DIR=. ; \
	        ABS_PROG="$$DIR/$$PROG" ; \
	        $(TEST) -x "$$ABS_PROG" && { CC="$$ABS_PROG"; echo "$$CC"; break 2; } ; \
	    done ; \
	    echo "no"; IFS=$$SAVED_IFS ; \
	done ; \
	$(TEST) -z "$$CC" && { echo "error: no C compiler found" >&2 ; exit 1; } ; \
	$(MKDIR) bin ; \
	$(RM) bin/gcc ; \
	$(LN) -s "$$CC" bin/gcc ; \


bin/g++:
	@CXX="" ; \
	for PROG in $(CXX_COMPILERS); do \
	    echo -n "checking for $$PROG... "; SAVED_IFS=$$IFS; IFS=: ; \
	    for DIR in $$PATH; do \
	        IFS=$$SAVED_IFS ; \
	        $(TEST) -z "$$DIR" && DIR=. ; \
	        ABS_PROG="$$DIR/$$PROG" ; \
	        $(TEST) -x "$$ABS_PROG" && { CXX="$$ABS_PROG"; echo "$$CXX"; break 2; } ; \
	    done ; \
	    echo "no"; IFS=$$SAVED_IFS ; \
	done ; \
	$(TEST) -z "$$CXX" && { echo "error: no C++ compiler found" >&2 ; exit 1; } ; \
	$(MKDIR) bin ; \
	$(RM) bin/g++ ; \
	$(LN) -s "$$CXX" bin/g++

$(PYTHON_INSTALL): $(PYTHON_BUILD)
# Install python files (needed by dependent packages like mod_python,
# python-modules, ...) during compilation and install targets.
# NOTE: -j1 seems to be necessary when --enable-optimizations is used
	$(PATH_VAR) ; $(MAKE) -j1 -C $(PYTHON_DIR) DESTDIR=$(DESTDIR)$(OMD_ROOT) install
# Cleanup unused stuff: We ship 2to3 from Python3 and we don't need some example proxy.
	$(RM) $(addprefix $(DESTDIR)$(OMD_ROOT)/bin/,2to3 smtpd.py)
# Fix python interpreter for kept scripts
	$(SED) -i '1s|^#!.*/python2\.7$$|#!/usr/bin/env python2|' $(addprefix $(DESTDIR)$(OMD_ROOT)/bin/,easy_install easy_install-2.7 idle pip pip2 pip2.7 pydoc python2.7-config)
# Fix pip configuration
	$(SED) -i '/^import re$$/i import os\nos.environ["PIP_DISABLE_PIP_VERSION_CHECK"] = "True"\nos.environ["PIP_TARGET"] = os.path.join(os.environ["OMD_ROOT"], "local/lib/python")' $(addprefix $(DESTDIR)$(OMD_ROOT)/bin/,pip pip2 pip2.7)
	install -m 644 $(PYTHON_SITECUSTOMIZE_SOURCE) $(DESTDIR)$(OMD_ROOT)/lib/python2.7/
	install -m 644 $(PYTHON_SITECUSTOMIZE_COMPILED) $(DESTDIR)$(OMD_ROOT)/lib/python2.7/
	$(TOUCH) $(PYTHON_INSTALL)

Python-skel:

Python-clean:
	$(RM) -r $(DIR) $(BUILD_HELPER_DIR)/$(MSITOOLS)* bin build  $(PACKAGE_PYTHON_DESTDIR)

upstream:
	git rm Python-*.tgz
	wget https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz
	git add Python-$(PYTHON_VERSION).tgz
