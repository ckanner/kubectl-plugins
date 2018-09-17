#!/usr/bin/bash

# ./ssh.sh {POD} {CMD}
POD="${1}"
CMD="${2:-bash}"
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

APP_NAME="debug$(date +%s)"
read -r -d '' DAEMON_SET_JSON <<EOF
{
	"apiVersion": "apps/v1",
	"kind": "DaemonSet",
	"metadata": {
		"name": "${APP_NAME}",
		"namespace": "${NAMESPACE}",
		"labels": {
			"app": "${APP_NAME}"
		}
	},
	"spec": {
        "selector": {
            "matchLabels": {
                "name": "${APP_NAME}"
            }
        },
		"template": {
			"metadata": {
				"labels": {
					"name": "${APP_NAME}"
				}
			},
			"spec": {
				"nodeSelector": {
					"kubernetes.io/hostname": "${NODE_NAME}"
				},
				"containers": [
					{
						"name": "docker",
						"image": "docker",
						"stdin": true,
						"stdinOnce": true,
						"tty": true,
                        "securityContext": {
                            "privileged": true
                        },
						"command": ["docker"],
						"args": [
							"exec",
							"-it",
							"${CONTAINER_ID}",
							"${CMD}"
						],
						"volumeMounts": [
							{
								"name": "docker",
								"mountPath": "/var/run/docker.sock"
							}
						]
					}
				],
				"volumes": [
					{
						"name": "docker",
						"hostPath": {
							"type": "File",
							"path": "/var/run/docker.sock"
						}
					}
				]
			}
		}
	}
}
EOF

echo ${DAEMON_SET_JSON} | $KUBECTL create -f -
