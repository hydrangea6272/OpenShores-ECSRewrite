.PHONY: _native-configure

# Configure once before any native compilation in a multi-target invocation.
_native-configure:
	$(CMAKE) -S . -B "$(NATIVE_BUILD_DIR)" -G "$(GENERATOR)" \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) $(CMAKE_ARGS)

define run_native_build
$(CMAKE) --build "$(NATIVE_BUILD_DIR)" --target $(1) \
	--parallel "$(PARALLEL)"
endef
