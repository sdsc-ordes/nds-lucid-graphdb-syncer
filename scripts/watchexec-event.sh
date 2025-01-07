#!/bin/bash
# This is a helper script used to run graphdb-syncer with watchexec.
# It assumes that the stdin is the watchexec event file path containing one watchexec event (updated file path) per line.
# The updated file paths are extracted from the event file, and the script assume these files are in json format with a "graph" key, from which it extracts the value.
# source graph uri. The prefix of this uri is then replaced with a hard-coded target prefix
# for each LUCID project.

set -euxo pipefail

if [[ -z "$PROJECTS" ]]; then
  echo "PROJECTS env var must be set to a comma-separated list of projects)" 1>&2
    exit 1
fi

if [[ -z "$TARGET_PREFIX" ]]; then
  echo "TARGET_PREFIX env var must be set to a URI prefix for the target graph name." 1>&2
    exit 1
fi


# Read event file; it may contain multiple events
while IFS= read -r EVENT_PATH; do
  # Strip the filesystem operation from watchexec
  INPUT_FILE=$(echo "$EVENT_PATH" | cut -f2- -d:)

  # Read the source graph uri from file
  if [[ -f "$INPUT_FILE" ]]; then
    SOURCE=$(jq -r '.graph' "$INPUT_FILE")
    STATUS=$(jq -r '.status' "$INPUT_FILE")
    
    # Skip transfers for failed uploads
    if [[ "$STATUS" != "SUCCESS" ]]; then
      continue
    fi

    for PROJECT in $(echo "${PROJECTS}" | tr ',' '\n'); do
      # replace prefix with target
      TARGET="${TARGET_PREFIX}/${PROJECT}/${SOURCE##*/}"

      # run graphdb-syncer
      if [[ -z "$DRY_RUN" ]]; then
        just \
          --set QUERY_PATH "queries/${PROJECT}.rq" \
          run "$SOURCE" "$TARGET"
      else
        echo just \
          --set QUERY_PATH "queries/${PROJECT}.rq" \
          run "$SOURCE" "$TARGET"
      fi
    done
  fi
done < "${1:-/dev/stdin}"
