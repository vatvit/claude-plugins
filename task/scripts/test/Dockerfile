# Test image for the task plugin: the repo's usual Alpine/busybox target (bash:5) plus git,
# which the git id source and the worktree suite need. Build once:
#   docker build -t task-test task/scripts/test
FROM bash:5
RUN apk add --no-cache git
