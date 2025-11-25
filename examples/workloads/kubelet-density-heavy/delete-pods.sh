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
end=24
namespace="kubelet-density-heavy"

for i in $(seq $start $end); do
    pod_name="curl-1-$i-*"
    echo "Attempting to delete pod: $pod_name"

    # Force delete the pod
    kubectl delete pod $pod_name -n $namespace --grace-period=0 --force

    # Wait for a moment to allow command to send
    sleep 2

    # Check if the pod still exists and attempt to remove finalizers if necessary
    if kubectl get pod $pod_name &> /dev/null; then
        echo "Pod $pod_name still exists, attempting to remove finalizers..."
        kubectl patch pod $pod_name --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
    fi

    echo "Pod $pod_name handled."
done

echo "All specified pods have been processed."