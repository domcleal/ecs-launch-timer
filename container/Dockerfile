FROM ubuntu:latest AS builder

# Update and install deps
RUN set -e; \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
    build-essential;

WORKDIR /usr/src
COPY launch.c .
RUN gcc -o launch -static launch.c

FROM scratch

COPY --from=builder /usr/src/launch /launch

CMD ["/launch"]
