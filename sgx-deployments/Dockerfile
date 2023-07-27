ARG path
ARG manifestPath

FROM golang:latest as build-env
ARG path
ENV CGO_ENABLED=0

COPY ./$path /app/
WORKDIR /app/

RUN mkdir /data && \
    go build -o app -ldflags="-extldflags=-static -w" .

FROM golang:latest as build-env2
ENV CGO_ENABLED=0

COPY ./wallet-service/vault-sgx-plugin/ /app/
WORKDIR /app/
RUN go build -o premain  -buildmode=pie -ldflags="-extldflags=-static -w" ./cmd/premain-app


FROM gramineproject/gramine:v1.4
ARG manifestPath
COPY --from=build-env \
    /app/app \
    /app/
    
RUN apt-get update &&  apt-get install -y xxd 
RUN apt-get install -y --no-install-recommends libsgx-dcap-default-qpl
COPY ./wallet-service/sgx_default_qcnl.conf /etc/    
RUN mkdir -p /certs
WORKDIR /app/

COPY ./$manifestPath ./entrypoint.sh /app/
COPY --from=build-env2 /app/premain /app/
RUN gramine-sgx-gen-private-key \
    && gramine-manifest -Darch_libdir=/lib/x86_64-linux-gnu app.manifest.template app.manifest \
    && gramine-sgx-sign --manifest app.manifest --output app.manifest.sgx
RUN gramine-sgx-get-token --output app.token --sig app.sig    

ENTRYPOINT [ "/app/entrypoint.sh" ]
