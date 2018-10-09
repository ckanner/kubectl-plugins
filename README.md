# kubectl-plugins

Some plugins for kubectl.

## kubectl debug

It is useful for debug container.

Usually when we debug the container, we will use kubectl exec to enter the container to execute some commands. But In our container, it's usually a very thin image, so we can't use some of the tools commonly used in virtual machines to debug.

Use kubectl debug plugin，We can easily start a debug container to debug the container running in kubernetes. The image of this debug container contains most of the common debugging tools, such as gdb, jmap, etc., so that it can debug most of the containers.

* The agent is deployed in binary on each node of the kubernetes. Of course, we can use the daemonset way to deploy the management agent.
* `kubectl plugin debug -n <namespace> <pod-name> -c <container-name> [command]`
* After executing the above command, a client will be run, and then a message will be sent to the agent. After the agent receives it, it will start a debugging container, and then the agent will be responsible for forwarding the output to the plugin.

