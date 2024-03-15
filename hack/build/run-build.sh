#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Default values
default_git_repo_url=https://github.com/devfile-samples/devfile-sample-go-basic
default_git_revision=main
default_docker_filepath=docker/Dockerfile
default_config_file="${SCRIPT_DIR}/build-config.env"
default_pipeline=docker-build-rhtap


# Load build credentials and configuration
CONFIG_FILE="${CONFIG_FILE:-$default_config_file}"
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "$SCRIPT_DIR/build-config.env does not exists. Look at instructions in $SCRIPT_DIR/build-config-template.env"
  exit 1
fi
# Get IMAGE_REPOSITORY
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

GIT_REPO_URL="${GIT_REPO_URL:-$default_git_repo_url}"
GIT_REVISION="${GIT_REVISION:-$default_git_revision}"
OUTPUT_IMAGE="${OUTPUT_IMAGE:-$IMAGE_REPOSITORY}"
DOCKER_FILEPATH="${DOCKER_FILEPATH:-$default_docker_filepath}"

PIPELINE="${PIPELINE:-$default_pipeline}"

oc delete pipelinerun "$PIPELINE" &> /dev/null
echo "Running pipeline $PIPELINE to build $GIT_REPO_URL @ $GIT_REVISION into $OUTPUT_IMAGE"

cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: ${PIPELINE}
spec:
  pipelineRef:
    name: ${PIPELINE}
  params:
    - name: git-url
      value: "${GIT_REPO_URL}"
    - name: revision
      value: "${GIT_REVISION}"
    - name: output-image
      value: "${OUTPUT_IMAGE}"
    - name: dockerfile
      value: "${DOCKER_FILEPATH}"
    - name: event-type
      value: push
  taskRunTemplate:
    serviceAccountName: rhtap-pipeline
  workspaces:
    - name: workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF
