#!/usr/bin/bash

# ./debug.sh {POD} {CMD} ${IMAGE}
POD="${1}"
CMD="${2:-bash}"
IMAGE="${3:-ubuntu}"
# runtime attributes
KUBECTL="${KUBECTL_PLUGINS_CALLER}"
NAMESPACE="${KUBECTL_PLUGINS_LOCAL_FLAG_NAMESPACE:-$KUBECTL_PLUGINS_CURRENT_NAMESPACE}"
# get the node where the pod deploy
NODE_NAME=$($KUBECTL --namespace ${NAMESPACE} get pod ${POD} -o go-template='{{.spec.nodeName}}')
# get the container id, default is the first container of the pod
CONTAINER="${KUBECTL_PLUGINS_LOCAL_FLAG_CONTAINER}"
if [[ -n ${CONTAINER} ]]; then
  CONTAINER_ID=$( $KUBECTL --namespace ${NAMESPACE} get pod ${POD} -o go-template="'{{ range .status.containerStatuses }}{{ if eq .name \"${CONTAINER}\" }}{{ .containerID }}{{ end }}{{ end }}'" )
else
  CONTAINER_ID=$( $KUBECTL --namespace ${NAMESPACE} get pod ${POD} -o go-template='{{ (index .status.containerStatuses 0).containerID }}' )
fi
CONTAINER_ID=${CONTAINER_ID#*//}

go run client.sh -container_id ${CONTAINER_ID} -node_ip ${NODE_NAME} -cmd ${CMD}

