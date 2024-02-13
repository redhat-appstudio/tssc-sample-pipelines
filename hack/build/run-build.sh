#!/bin/bash

# Default values
default_git_repo_url=https://github.com/devfile-samples/devfile-sample-go-basic
default_git_revision=main
default_docker_filepath=docker/Dockerfile

default_pipeline=docker-build-rhtap


# Load build credentials and configuration
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
config_file="${SCRIPT_DIR}/build-config.env"
if [ ! -f $config_file ]; then
  echo "$SCRIPT_DIR/build-config.env does not exists. Look at instructions in $SCRIPT_DIR/build-config-template.env"
  exit 1
fi
# Get IMAGE_REPOSITORY and ROX_ENDPOINT
source "$config_file"


GIT_REPO_URL="${GIT_REPO_URL:-$default_git_repo_url}"
GIT_REVISION="${GIT_REVISION:-$default_git_revision}"
OUTPUT_IMAGE="${OUTPUT_IMAGE:-$IMAGE_REPOSITORY}"
DOCKER_FILEPATH="${DOCKER_FILEPATH:-$default_docker_filepath}"

PIPELINE="${PIPELINE:-$default_pipeline}"

if [ $ROX_ENDPOINT == 'in-cluster' ] ; then
  ROX_ENDPOINT=$(oc get route central -o jsonpath='{.spec.host}' -n rhacs-operator):443
fi

oc delete pipelinerun $PIPELINE &> /dev/null
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
    - name: stackrox-endpoint
      value: "${ROX_ENDPOINT}"
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
