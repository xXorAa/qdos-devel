FROM debian:10.10
ARG TARGETARCH

WORKDIR build
COPY build .
RUN bash ./build.sh
RUN rm -rf /build

RUN yes | adduser --home /qdos --shell /bin/bash --disabled-password qdos

USER qdos:qdos
WORKDIR /qdos

