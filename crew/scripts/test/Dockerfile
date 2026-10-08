# Test image for the crew plugin: the repo's usual Alpine/busybox target (bash:5) plus git,
# which every crew script needs. Build once:
#   docker build -t crew-test crew/scripts/test
FROM bash:5
RUN apk add --no-cache git
