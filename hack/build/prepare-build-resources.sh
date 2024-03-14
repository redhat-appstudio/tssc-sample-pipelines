#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Default values
default_config_file="${SCRIPT_DIR}/build-config.env"

# Load build credentials and configuration
CONFIG_FILE="${CONFIG_FILE:-$default_config_file}"
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "$SCRIPT_DIR/build-config.env does not exists. Look at instructions in $SCRIPT_DIR/build-config-template.env"
  exit 1
fi

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

NAMESPACE=$(oc config view --minify -o 'jsonpath={..namespace}')

function cleanNamespace() {
    oc delete serviceaccount rhtap-pipeline
    oc delete secret docker-push-secret
    oc delete rolebinding rhtap-pipelines-runner
    oc delete secret rox-api-token
}

function provisionNamespace() {
    oc create serviceaccount rhtap-pipeline

    oc create secret docker-registry docker-push-secret \
      --docker-server="${IMAGE_REPOSITORY}" --docker-username="${DOCKER_USERNAME}" --docker-password="${DOCKER_PASSWORD}"
    oc secret link rhtap-pipeline docker-push-secret
    oc secret link rhtap-pipeline docker-push-secret --for=pull,mount

    oc create rolebinding rhtap-pipelines-runner --clusterrole=rhtap-pipelines-runner --serviceaccount="${NAMESPACE}":rhtap-pipeline

    if [ "$ROX_ENDPOINT" == 'in-cluster' ] ; then
      ROX_ENDPOINT=$(oc get route central -o jsonpath='{.spec.host}' -n rhacs-operator):443
    fi
    oc create secret generic rox-api-token --from-literal=rox-api-token="${ROX_TOKEN}" --from-literal=rox-api-endpoint="${ROX_ENDPOINT}"
}

function cleanCluster() {
  oc delete securitycontextconstraint rhtap-pipelines-scc
  oc delete clusterrole rhtap-pipelines-runner
}

function provisionCluster() {
  cat <<EOF | oc apply -f -
    apiVersion: security.openshift.io/v1
    kind: SecurityContextConstraints
    metadata:
      name: rhtap-pipelines-scc
    allowHostDirVolumePlugin: false
    allowHostIPC: false
    allowHostNetwork: false
    allowHostPID: false
    allowHostPorts: false
    allowPrivilegeEscalation: false
    allowPrivilegedContainer: false
    allowedCapabilities:
      - SETFCAP
    defaultAddCapabilities: null
    fsGroup:
      type: MustRunAs
    groups:
      - system:cluster-admins
    priority: 10
    readOnlyRootFilesystem: false
    requiredDropCapabilities:
      - MKNOD
    runAsUser:
      type: RunAsAny
    seLinuxContext:
      type: MustRunAs
    supplementalGroups:
      type: RunAsAny
    users: []
    volumes:
      - configMap
      - downwardAPI
      - emptyDir
      - persistentVolumeClaim
      - projected
      - secret
EOF

  cat <<EOF | oc apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: rhtap-pipelines-runner
    rules:
    - apiGroups:
        - tekton.dev
      resources:
        - pipelineruns
      verbs:
        - get
    - apiGroups:
        - tekton.dev
      resources:
        - taskruns
      verbs:
        - get
        - list
        - patch
    - apiGroups:
        - ""
      resources:
        - secrets
      verbs:
        - get
    - apiGroups:
        - security.openshift.io
      resourceNames:
        - rhtap-pipelines-scc
      resources:
        - securitycontextconstraints
      verbs:
        - use
EOF
}

cleanCluster
provisionCluster
cleanNamespace
provisionNamespace
