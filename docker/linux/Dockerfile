FROM ubuntu:22.04 AS toolchain

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        ccache \
        cmake \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libopenal-dev \
        libqt5opengl5-dev \
        libqt5sql5-psql \
        libsdl2-dev \
        lld \
        ninja-build \
        python3 \
        qtbase5-dev \
        qtbase5-dev-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
CMD ["/bin/bash"]
