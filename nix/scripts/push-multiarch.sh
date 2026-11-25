#!/bin/bash
if [ "$#" -lt 2 ]; then
  echo "Usage: push-multiarch <registry-repo> <platform>=<image-tar> [<platform>=<image-tar> ...]"
  exit 1
fi

REPO=$(echo "$1" | tr '[:upper:]' '[:lower:]')
shift

if [ -z "${TAGS:-}" ]; then
  echo "Error: TAGS environment variable is not set"
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

INDEX_REF_ARGS=()
i=0
for spec in "$@"; do
  PLATFORM="${spec%%=*}"
  IMAGE_TAR="${spec#*=}"
  if [ "$PLATFORM" = "$spec" ] || [ -z "$PLATFORM" ] || [ -z "$IMAGE_TAR" ]; then
    echo "Error: Invalid image spec '$spec' (expected <platform>=<image-tar>)"
    exit 1
  fi

  OCI_DIR="$TMP_DIR/oci-$i"
  i=$((i + 1))

  # Import image into a local OCI layout directory directly from the Nix build output
  regctl image import "ocidir://$OCI_DIR" "$IMAGE_TAR"
  DIGEST=$(regctl image digest "ocidir://$OCI_DIR")

  # Push single-architecture layers and manifest by digest
  echo "Pushing $PLATFORM digest: $DIGEST to $REPO..."
  regctl image copy "ocidir://$OCI_DIR" "$REPO@$DIGEST"

  INDEX_REF_ARGS+=(--ref "$REPO@$DIGEST" --platform "$PLATFORM")
done

ANNOTATION_ARGS=()
if [ -n "${SOURCE_URL:-}" ]; then
  ANNOTATION_ARGS+=(--annotation "org.opencontainers.image.source=$SOURCE_URL")
fi

# Create and push the multi-architecture manifest index for each tag
# Since TAGS is multiline, we read it line by line
echo "$TAGS" | while read -r tag || [ -n "$tag" ]; do
  if [ -n "$tag" ]; then
    echo "Creating and pushing OCI index for $tag..."
    regctl index create "$tag" \
      "${ANNOTATION_ARGS[@]}" \
      "${INDEX_REF_ARGS[@]}"
  fi
done
