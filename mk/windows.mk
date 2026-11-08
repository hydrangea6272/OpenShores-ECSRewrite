.PHONY: win win-client win-toolchain

win-toolchain:
	docker build --tag "$(WINDOWS_IMAGE)" \
		--target toolchain \
		--file docker/windows/Dockerfile docker/windows

win win-client:
	HAZERON_MINGW_IMAGE="$(WINDOWS_IMAGE)" \
	HAZERON_WINDOWS_CACHE_VOLUME="$(WINDOWS_CACHE_VOLUME)" \
	HAZERON_BUILD_CONFIG="$(CONFIG)" \
	HAZERON_CMAKE_ARGS="$(CMAKE_ARGS)" \
	AU_TARGET=$(if $(filter win,$@),clients,client) \
		bash docker/windows/build-client.sh
