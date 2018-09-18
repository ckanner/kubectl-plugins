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
read -r -d '' OVERRIDES <<EOF
{
    "apiVersion": "v1",
    "spec": {
        "containers": [
            {
                "image": "docker",
                "name": "debuger",
                "stdin": true,
                "stdinOnce": true,
                "tty": true,
                "restartPolicy": "Never",
                "args": ["run", "-it", "--net=container:${CONTAINER_ID}", "--pid=container:${CONTAINER_ID}", "--ipc=container:${CONTAINER_ID}", "${IMAGE}", "${CMD}"],
                "volumeMounts": [
                    {
                        "mountPath": "/var/run/docker.sock",
                        "name": "docker"
                    }
                ]
            }
        ],
        "nodeSelector": {
          "kubernetes.io/hostname": "${NODE_NAME}"
        },
        "volumes": [
            {
                "name": "docker",
                "hostPath": {
                    "path": "/var/run/docker.sock",
                    "type": "File"
                }
            }
        ]
    }
}
EOF

eval ${KUBECTL} --namespace ${NAMESPACE} run -it --rm --restart=Never --image=docker --overrides="'${OVERRIDES}'" docker
