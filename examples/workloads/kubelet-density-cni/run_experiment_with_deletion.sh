#!/bin/bash

# Define the number of times to repeat the entire set of experiments
iterations=10

# ---------------------------------------------------------------------------
# Experiments configuration (small version)
# ---------------------------------------------------------------------------
experiments=(
  "jobIterations=1 qps=1 burst=1 webserver_replicas=1 curl_replicas=1 service_replicas=1"
  "jobIterations=1 qps=10 burst=10 webserver_replicas=1 curl_replicas=1 service_replicas=1"
  "jobIterations=1 qps=25 burst=25 webserver_replicas=1 curl_replicas=1 service_replicas=1"
  "jobIterations=1 qps=50 burst=50 webserver_replicas=1 curl_replicas=1 service_replicas=1"
  "jobIterations=1 qps=75 burst=75 webserver_replicas=1 curl_replicas=1 service_replicas=1"
  "jobIterations=1 qps=100 burst=100 webserver_replicas=1 curl_replicas=1 service_replicas=1"
)

# ---------------------------------------------------------------------------
# Function: HIGH-ACCURACY deletion measurement (ms resolution, 3 decimals)
# ---------------------------------------------------------------------------
measure_delete_time() {
  local ns="kubelet-density-cni"
  local experiment_desc="$1"
  local run_id="$2"

  echo "------"
  echo "Starting deletion of resources in namespace '${ns}' for run=${run_id}"
  echo "Experiment: ${experiment_desc}"

  # Start timestamp in milliseconds
  local start_ts_ms
  start_ts_ms=$(date +%s%3N)

  # Delete deployments and services created by kube-burner
  kubectl delete deployment,svc -n "${ns}" --all --ignore-not-found=true

  # Poll until all pods, deployments, and services disappear
  while true; do
    local remaining
    remaining=$(kubectl get pods,deploy,svc -n "${ns}" --no-headers 2>/dev/null | wc -l)

    if [ "${remaining}" -eq 0 ]; then
      break
    fi

    echo "Waiting for resources to be deleted... remaining objects: ${remaining}"
    sleep 0.2  # 200ms polling interval
  done

  # End timestamp in milliseconds
  local end_ts_ms
  end_ts_ms=$(date +%s%3N)

  # Duration in milliseconds
  local duration_ms=$((end_ts_ms - start_ts_ms))

  # Convert ms → X.XXX seconds
  local sec=$((duration_ms / 1000))
  local ms_rem=$((duration_ms % 1000))
  local duration
  duration=$(printf "%d.%03d" "${sec}" "${ms_rem}")

  # Log accurate delete duration
  echo "DeleteDurationSeconds run=${run_id} ${experiment_desc} duration=${duration}s"
  echo "DeleteDurationSeconds run=${run_id} ${experiment_desc} duration=${duration}s" >> deletion_times_cni.log

  echo "Finished deletion timing for run=${run_id} (${duration}s)"
  echo "------"
}

# ---------------------------------------------------------------------------
# Determine starting counter for log filenames
# ---------------------------------------------------------------------------
if ls kubelet-density-cni_*.log 1> /dev/null 2>&1; then
  counter=$(ls kubelet-density-cni_*.log | grep -o '[0-9]*\.log' | grep -o '[0-9]*' | sort -n | tail -1)
  counter=$((counter + 1))
else
  counter=1
fi

# ---------------------------------------------------------------------------
# Main experiment execution loop
# ---------------------------------------------------------------------------
for (( run=1; run<=iterations; run++ )); do
  echo "============================================================"
  echo "Starting run ${run} of ${iterations}"
  echo "============================================================"

  for experiment in "${experiments[@]}"; do
    echo "------------------------------------------------------------"
    echo "Running experiment: ${experiment}"
    echo "------------------------------------------------------------"

    # Delete namespace if it already exists
    if kubectl get namespace kubelet-density-cni &> /dev/null; then
      echo "Namespace exists. Deleting it..."
      kubectl delete namespace kubelet-density-cni

      while kubectl get namespace kubelet-density-cni &> /dev/null; do
        echo "Waiting for namespace cleanup..."
        sleep 1
      done
    fi

    # Create fresh namespace
    kubectl create namespace kubelet-density-cni

    # Parse experiment variables
    eval "${experiment}"

    export JOB_ITERATIONS="${jobIterations}"
    export QPS="${qps}"
    export BURST="${burst}"
    export WEBSERVER_REPLICAS="${webserver_replicas}"
    export CURL_REPLICAS="${curl_replicas}"
    export SERVICE_REPLICAS="${service_replicas}"

    # Build the kube-burner manifest
    envsubst < kubelet-density-cni.template.yml > kubelet-density-cni.yml

    # Run kube-burner
    kube-burner init -c kubelet-density-cni.yml

    # Find and rename kube-burner log file
    log_file=$(ls -t kube-burner-*.log | head -n 1)
    new_log_file="kubelet-density-cni_jobIterations${jobIterations}_qps${qps}_burst${burst}_webserver${webserver_replicas}_curl${curl_replicas}_service${service_replicas}_${counter}.log"
    mv "${log_file}" "${new_log_file}"

    # Measure accurate deletion timing (pods + deployments + services)
    measure_delete_time "${experiment}" "${run}"

    counter=$((counter + 1))

    echo "Sleeping 45 seconds before next experiment..."
    sleep 45
  done
done

echo "All experiments completed."
