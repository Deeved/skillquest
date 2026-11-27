ARG GO_IMAGE
ARG NODE_IMAGE

FROM ${NODE_IMAGE} AS node

FROM ${GO_IMAGE}
ARG CLAUDE_CODE_VERSION
ARG UID_LOCAL=1000
ARG GID_LOCAL=1000

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git make \
 && rm -rf /var/lib/apt/lists/*

RUN test -n "${CLAUDE_CODE_VERSION}" \
 && npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

# T-02: instalar aqui as dependências de Go e Angular, para o verify rodar sem internet.

# Mesmo UID e GID de quem desenvolve, para os arquivos não ficarem com outro dono.
RUN groupadd --non-unique --gid "${GID_LOCAL}" dev \
 && useradd --non-unique --uid "${UID_LOCAL}" --gid "${GID_LOCAL}" --create-home dev \
 && install -d -o "${UID_LOCAL}" -g "${GID_LOCAL}" /home/dev/.claude

ENV GOTOOLCHAIN=local
USER dev
WORKDIR /workspace
