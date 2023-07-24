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
    && apt install caddy \
    && rm -rf /var/lib/apt/lists/*

RUN rm -rf /usr/share/caddy/* && \
    rm -rf /etc/caddy/Caddyfile

COPY ./frontend/frontend/elonwallet.io/Caddyfile \
    /etc/caddy/Caddyfile
    

COPY --from=build-env \
    /app/.output/public \
    /usr/share/caddy

WORKDIR /app/

COPY ./frontend/app.manifest.template ./entrypoint.sh /app/

RUN gramine-sgx-gen-private-key \
    && gramine-manifest -Darch_libdir=/lib/x86_64-linux-gnu app.manifest.template app.manifest \
    && gramine-sgx-sign --manifest app.manifest --output app.manifest.sgx
    

ENTRYPOINT [ "/app/entrypoint.sh" ]
