ARG GO_IMAGE
ARG NODE_IMAGE

FROM ${NODE_IMAGE} AS node

FROM ${GO_IMAGE}
ARG CLAUDE_CODE_VERSION
ARG LOCAL_UID=1000
ARG LOCAL_GID=1000

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git make \
 && rm -rf /var/lib/apt/lists/*

RUN test -n "${CLAUDE_CODE_VERSION}" \
 && npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

# Mesmo UID e GID de quem desenvolve, para os arquivos não ficarem com outro dono.
RUN groupadd --non-unique --gid "${LOCAL_GID}" dev \
 && useradd --non-unique --uid "${LOCAL_UID}" --gid "${LOCAL_GID}" --create-home dev \
 && install -d -o "${LOCAL_UID}" -g "${LOCAL_GID}" /home/dev/.claude

# Dependências da web, instaladas na construção para o verify rodar sem internet.
# O Go não tem dependências externas. O "make setup" copia /opt/web/node_modules para web/.
# O usuário dev já existe aqui, então pode ser o dono de /opt/web.
ENV NG_CLI_ANALYTICS=false
RUN install -d -o "${LOCAL_UID}" -g "${LOCAL_GID}" /opt/web
COPY --chown=${LOCAL_UID}:${LOCAL_GID} web/package.json web/package-lock.json /opt/web/

ENV GOTOOLCHAIN=local
USER dev
RUN cd /opt/web \
 && npm ci --ignore-scripts --cache /tmp/npm-cache \
 && rm -rf /tmp/npm-cache
WORKDIR /workspace
