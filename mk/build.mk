# Extra CMake configure arguments for every build, e.g. CMAKE_ARGS="-DAU_UNITY_BUILD=ON".
CMAKE_ARGS ?=

DEFAULT_CACHE_VOLUMES := \
	hazeron-linux-debug-cache \
	hazeron-linux-release-cache \
	hazeron-linux-relwithdebinfo-cache \
	hazeron-windows-debug-cache \
	hazeron-windows-release-cache \
	hazeron-windows-relwithdebinfo-cache \
	hazeron-assets-cache

LINUX_BUILD_TARGETS := linux linux-client linux-clients linux-servers linux-cgi linux-tools

.PHONY: all $(LINUX_BUILD_TARGETS) linux-toolchain clean _linux-docker-clients

define run_linux_build
HAZERON_LINUX_IMAGE="$(LINUX_IMAGE)" \
HAZERON_LINUX_CACHE_VOLUME="$(LINUX_CACHE_VOLUME)" \
HAZERON_BUILD_CONFIG="$(CONFIG)" \
HAZERON_CMAKE_ARGS="$(CMAKE_ARGS)" \
	bash docker/linux/build.sh $(1)
endef

all: linux win

linux-toolchain:
	docker build --tag "$(LINUX_IMAGE)" \
		--target toolchain \
		--file docker/linux/Dockerfile docker/linux

# Only Linux compilation selects a native toolchain. Packaging and asset tools
# use run_linux_build directly so their Docker output paths stay predictable.
ifeq ($(NATIVE),1)
$(LINUX_BUILD_TARGETS): _native-configure
	$(call run_native_build,$(if $(filter linux,$@),programs,$(patsubst linux-%,%,$@)))
else
$(filter-out linux-clients,$(LINUX_BUILD_TARGETS)):
	$(call run_linux_build,$(if $(filter linux,$@),programs,$(patsubst linux-%,%,$@)))

linux-clients: _linux-docker-clients
endif

# Share this dependency with packaging so a combined invocation builds clients
# once rather than starting concurrent builds against the same Docker cache.
_linux-docker-clients: audio-assets
	$(call run_linux_build,clients)

clean:
	$(CMAKE) -E remove_directory build
	@for volume in $(sort $(DEFAULT_CACHE_VOLUMES) $(LINUX_CACHE_VOLUME) $(WINDOWS_CACHE_VOLUME) $(ASSETS_CACHE_VOLUME)); do \
		docker volume rm "$$volume" >/dev/null 2>&1 || true; \
	done
