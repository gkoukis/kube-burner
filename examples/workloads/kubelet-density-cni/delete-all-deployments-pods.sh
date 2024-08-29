#!/bin/bash

# Specific pod range
start=0
end=50
namespace="kubelet-density-cni"

for i in $(seq $start $end); do
    #deployment_name="webserver-1-$i"
    #deployment_name="curl-1-$i"
    deployment_name="curl-$i-0"
    echo "Scaling down deployment: $deployment_name"

    # Scale down the deployment to 0 replicas
    kubectl scale --replicas=0 deployment/$deployment_name -n $namespace

    echo "Deleting deployment: $deployment_name"
    # Delete the deployment to ensure no pods are redeployed
    kubectl delete deployment $deployment_name -n $namespace

    echo "Deleting any remaining pods for deployment: $deployment_name"
    # Force delete all pods that start with the pod_name
    kubectl get pods -n $namespace --no-headers | awk '{print $1}' | grep "^$deployment_name-" | xargs -r -I {} kubectl delete pod {} -n $namespace --grace-period=0 --force

    # Wait for a moment to allow command to send
    sleep 2

    # Check if any pods with the name still exist and attempt to remove finalizers if necessary
    remaining_pods=$(kubectl get pods -n $namespace --no-headers | awk '{print $1}' | grep "^$deployment_name-")
    if [ ! -z "$remaining_pods" ]; then
        echo "Some pods still exist, attempting to remove finalizers..."
        for pod in $remaining_pods; do
            kubectl patch pod $pod -n $namespace --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
        done
    fi

    echo "Deployment $deployment_name and its pods handled."
done

echo "All specified deployments and their pods have been processed."