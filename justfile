image := "ghcr.io/sdsc-ordes/nds-lucid-graphdb-syncer"
tag := "latest"
container_runtime := "podman"
export TMPDIR := env("TMPDIR", "/tmp")
export LOGDIR := env("LOGDIR", "log")
export QUERY_PATH := env("QUERY_PATH", "")


default:
  @just --list --unsorted

_containerize *cmd:
  {{container_runtime}} run --rm \
  -it \
  -v "${PWD}:/app" \
  -v {{TMPDIR}}/syncer:/tmp/syncer \
  -e TMPDIR=/tmp/syncer \
  -e QUERY_PATH={{QUERY_PATH}} \
  -e LOGDIR={{LOGDIR}} \
  --network=host \
  --env-file .env \
  {{image}}:{{tag}} \
  {{cmd}}

_prepare:
  @mkdir -p {{TMPDIR}}/syncer
  @mkdir -p {{LOGDIR}}

# build container image
image-build:
  {{container_runtime}} build -t {{image}}:{{tag}} -f Containerfile .

# push container image
image-push: image-build
  {{container_runtime}} push --tls-verify {{image}}:{{tag}}

# push GPG-signed container image
image-push-signed FINGERPRINT: image-build
  {{container_runtime}} push --sign-by {{FINGERPRINT}} --tls-verify {{image}}:{{tag}}

# enter dev environment in container
container-dev: _prepare
  just _containerize

# run syncer inside container
container-run SOURCE-GRAPH TARGET-GRAPH: _prepare
  just _containerize "/app/bin/graphdb-sync {{SOURCE-GRAPH}} {{TARGET-GRAPH}}"

# run syncer directly deps required
run SOURCE-GRAPH TARGET-GRAPH: _prepare
  ./bin/graphdb-sync {{SOURCE-GRAPH}} {{TARGET-GRAPH}}

# Monitor filesystem changes in target directory and re-run the syncer
watch DIR: _prepare
  watchexec \
    -w {{DIR}} \
    -e json \
    -E TARGET_PREFIX='http://lucid-projects' \
    -E PROJECTS='los,lvc' \
    --fs-events modify,metadata \
    --emit-events-to file \
    './scripts/watchexec-event.sh $WATCHEXEC_EVENTS_FILE'
