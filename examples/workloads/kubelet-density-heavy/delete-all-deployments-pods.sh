#!/bin/bash

# Copyright (c) 2025 Athena RC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#
# Contributors:
#      George Koukis - author

# Specific pod range
start=0
end=10
namespace="kubelet-density-heavy"

# Array of deployment name patterns
deployment_names=("perfapp-" "postgres-")

for deployment_name_prefix in "${deployment_names[@]}"; do
    for i in $(seq $start $end); do
        deployment_name="${deployment_name_prefix}${i}-0"
        echo "Scaling down deployment: $deployment_name"

        # Scale down the deployment to 0 replicas
        kubectl scale --replicas=0 deployment/$deployment_name -n $namespace

        echo "Deleting deployment: $deployment_name"
        # Delete the deployment to ensure no pods are redeployed
        kubectl delete deployment $deployment_name -n $namespace

        echo "Deleting any remaining pods for deployment: $deployment_name"
        # Force delete all pods that start with the deployment_name
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
done

echo "All deployments and pods have been processed."