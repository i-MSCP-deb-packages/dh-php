#!/usr/bin/make -f
# See debhelper(7) (uncomment to enable)
# output every command that modifies files on the build system.
#DH_VERBOSE = 1

# see EXAMPLES in dpkg-buildflags(1) and read /usr/share/dpkg/*
DPKG_EXPORT_BUILDFLAGS = 1
include /usr/share/dpkg/default.mk

# see FEATURE AREAS in dpkg-buildflags(1)
export DEB_BUILD_MAINT_OPTIONS = hardening=+all

# see ENVIRONMENT in dpkg-buildflags(1)
# package maintainers to append CFLAGS
export DEB_CFLAGS_MAINT_APPEND  = -Wall -pedantic
# package maintainers to append LDFLAGS
export DEB_LDFLAGS_MAINT_APPEND = -Wl,--as-needed

# Don't ever use RPATH on Debian
export PHP_RPATH=no

PHP_VERSIONS := $(shell /usr/sbin/phpquery -V)

PECL_NAME    := $(if $(PECL_NAME_OVERRIDE),$(PECL_NAME_OVERRIDE),$(subst php-,,$(DEB_SOURCE)))
INSTALL_ROOT = $(CURDIR)/debian/php-$(PECL_NAME)

# find corresponding package-PHP_MAJOR.PHP_MINOR.xml, package-PHP_MAJOR.xml or package.xml
$(foreach ver,$(PHP_VERSIONS),$(eval PACKAGE_XML_$(ver) := $(word 1,$(wildcard package-$(ver).xml package-$(basename $(ver)).xml package.xml))))
# fill DH_PHP_VERSIONS with versions that have corresponding package.xml
export DH_PHP_VERSIONS = $(if $(DH_PHP_VERSIONS_OVERRIDE),$(DH_PHP_VERSIONS_OVERRIDE),$(foreach ver,$(PHP_VERSIONS),$(if $(PACKAGE_XML_$(ver)),$(ver))))
ifneq ($(DH_PHP_VERSIONS_OVERRIDE),)
# for each ver in $(DH_PHP_VERSIONS), look into each corresponding package.xml for upstream PECL version
$(foreach ver,$(DH_PHP_VERSIONS),$(eval PECL_SOURCE_$(ver) := $(PECL_NAME)-$(shell xml2 < $(PACKAGE_XML_$(ver)) | sed -ne "s,^/package/version/release=,,p")))
endif

CONFIGURE_TARGETS = $(addprefix configure-,$(addsuffix -stamp,$(DH_PHP_VERSIONS)))
BUILD_TARGETS     = $(addprefix build-,$(addsuffix -stamp,$(DH_PHP_VERSIONS)))
INSTALL_TARGETS   = $(addprefix install-,$(addsuffix -stamp,$(DH_PHP_VERSIONS)))
CLEAN_TARGETS     = $(addprefix clean-,$(addsuffix -stamp,$(DH_PHP_VERSIONS)))

%:
	dh $@ --with php

override_dh_auto_configure: $(CONFIGURE_TARGETS)
override_dh_auto_build: $(BUILD_TARGETS)
override_dh_auto_install: $(INSTALL_TARGETS)
override_dh_auto_clean: $(CLEAN_TARGETS)
	-rm -f $(CONFIGURE_TARGETS) $(BUILD_TARGETS) $(INSTALL_TARGETS) $(CLEAN_TARGETS)

clean-%-stamp: SOURCE_DIR = build-$(*)
clean-%-stamp:
	rm -rf $(SOURCE_DIR)
	touch clean-$*-stamp

configure-%-stamp: SOURCE_DIR = build-$(*)
configure-%-stamp:
	echo PECL_SOURCE_$(*) $(PECL_SOURCE_$(*))
	cp -a $(PECL_SOURCE_$(*)) $(SOURCE_DIR)
	cd $(SOURCE_DIR) && phpize$(*)
	dh_auto_configure --sourcedirectory=$(SOURCE_DIR) -- --enable-$(PECL_NAME) --with-php-config=/usr/bin/php-config$*
	touch configure-$(*)-stamp

build-%-stamp: SOURCE_DIR = build-$(*)
build-%-stamp:
	dh_auto_build --sourcedirectory=$(SOURCE_DIR)
	touch build-$*-stamp

install-%-stamp: SOURCE_DIR = build-$(*)
install-%-stamp:
	dh_auto_install --sourcedirectory=$(SOURCE_DIR) -- INSTALL_ROOT=$(INSTALL_ROOT)
	touch install-$*-stamp

override_dh_gencontrol: ,:=,
override_dh_gencontrol:
	dh_gencontrol -- "-Vphp:Provides=$(addprefix php,$(addsuffix -$(PECL_NAME)$(,) ,$(DH_PHP_VERSIONS)))"

override_dh_php:
	dh_php -p php-$(PECL_NAME)