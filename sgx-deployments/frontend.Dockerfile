FROM caddy:alpine as deps

FROM node:lts as build-env

WORKDIR /app

COPY ./frontend/frontend/elonwallet.io .

RUN yarn install && \
    yarn generate

FROM gramineproject/gramine:v1.4
ARG manifestPath
RUN apt update \
    && apt-get install -y xxd debian-keyring debian-archive-keyring apt-transport-https \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt update \
    && apt install -y caddy ca-certificates libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

RUN rm -rf /usr/share/caddy/* && \
    rm -rf /etc/caddy/Caddyfile
COPY --from=deps /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=deps /etc/mime.types /etc/nsswitch.conf /etc/
RUN setcap cap_net_bind_service=ep /usr/bin/caddy
    
COPY ./frontend/frontend/elonwallet.io/Caddyfile \
    /etc/caddy/Caddyfile
    

COPY --from=build-env \
    /app/.output/public \
    /usr/share/caddy
RUN mkdir /config
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data
ENV XCADDY_SETCAP 1
RUN chmod +x /usr/bin/caddy
WORKDIR /app/

COPY ./frontend/app.manifest.template ./entrypoint.sh /app/

RUN gramine-sgx-gen-private-key \
    && gramine-manifest -Darch_libdir=/lib/x86_64-linux-gnu app.manifest.template app.manifest \
    && gramine-sgx-sign --manifest app.manifest --output app.manifest.sgx
    

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019

ENTRYPOINT [ "/app/entrypoint.sh" ]
