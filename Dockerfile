# syntax=docker/dockerfile:1

# bump: libsamplerate /LIBSAMPLERATE_VERSION=([\d.]+)/ https://github.com/libsndfile/libsamplerate.git|*
# bump: libsamplerate after ./hashupdate Dockerfile LIBSAMPLERATE $LATEST
# bump: libsamplerate link "Release notes" https://github.com/libsndfile/libsamplerate/releases/tag/$LATEST
ARG LIBSAMPLERATE_VERSION=0.2.2
ARG LIBSAMPLERATE_URL=https://github.com/libsndfile/libsamplerate/archive/refs/tags/${LIBSAMPLERATE_VERSION}.tar.gz
ARG LIBSAMPLERATE_SHA256=16e881487f184250deb4fcb60432d7556ab12cb58caea71ef23960aec6c0405a

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBSAMPLERATE_URL
ARG LIBSAMPLERATE_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libsamplerate.tar.gz "$LIBSAMPLERATE_URL" && \
  echo "$LIBSAMPLERATE_SHA256  libsamplerate.tar.gz" | sha256sum --status -c - && \
  mkdir libsamplerate && \
  tar xf libsamplerate.tar.gz -C libsamplerate --strip-components=1 && \
  rm libsamplerate.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/libsamplerate/ /tmp/libsamplerate/
WORKDIR /tmp/libsamplerate/build
RUN \
  apk add --no-cache --virtual build \
    build-base cmake pkgconf && \
  cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path samplerate && \
  ar -t /usr/local/lib/libsamplerate.a && \
  readelf -h /usr/local/lib/libsamplerate.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBSAMPLERATE_VERSION
COPY --from=build /usr/local/lib/pkgconfig/samplerate.pc /usr/local/lib/pkgconfig/samplerate.pc
COPY --from=build /usr/local/lib/libsamplerate.a /usr/local/lib/libsamplerate.a
COPY --from=build /usr/local/include/samplerate.h /usr/local/include/samplerate.h
