ARG GO_IMAGE
FROM ${GO_IMAGE} AS build
WORKDIR /src
COPY go.mod *.go ./
RUN CGO_ENABLED=0 go build -trimpath -o /rede .

FROM scratch
COPY --from=build /rede /rede
USER 65534:65534
ENTRYPOINT ["/rede"]
