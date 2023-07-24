ARG path
ARG manifestPath

FROM golang:latest as build-env
ARG path
ENV CGO_ENABLED=0

COPY ./$path /app/
WORKDIR /app/

RUN mkdir /data && \
    go build -o app -ldflags="-extldflags=-static -w" .

FROM gramineproject/gramine:v1.4
ARG manifestPath
COPY --from=build-env \
    /app/app \
    /app/
    
    
RUN apt-get update &&  apt-get install -y xxd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/

COPY ./$manifestPath ./entrypoint.sh /app/

RUN gramine-sgx-gen-private-key \
    && gramine-manifest -Darch_libdir=/lib/x86_64-linux-gnu app.manifest.template app.manifest \
    && gramine-sgx-sign --manifest app.manifest --output app.manifest.sgx
    

ENTRYPOINT [ "/app/entrypoint.sh" ]
