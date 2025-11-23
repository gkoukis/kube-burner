# Kube-burner workloads

This directory structure holds several working kube-burner worloads that can be used as reference:

- api-intensive: This workload is meant to load kube-apiserver by creating pods mounting secrets and configmaps, and then delete them. You'll need to tweak QPS/Burst and jobIterations parameters according to the cluster size.
- service-latency-example: Showcases service latency measurment using a series of deloyments and services.
- kubelet-density: This is the most simple workload possible. It basically creates pods using an sleep image. Useful to verify max-pods in worker nodes.
- kubelet-density-profiling: Similar to the previous one, but with the addition of pprof measurements.
- kubelet-density-heavy: Similar to the previous one, with the difference that the pods it creates are actually a client/server application consisting of a basic application which performes queries in a pod running PostgreSQL and uses a k8s service to communicate with it.
The experiment stresses the Kubernetes control plane by generating repeated deployments of a coupled service–database micro-workload (Postgres backend and perfapp frontend), varying the API-server QPS/burst parameters, and measuring pod-level latency metrics to assess cluster responsiveness and scalability.
- deployment-pvc-move: This workload is meant to test the CSI's ability to move volumes between nodes by creating node bound deployments with volumes and moving the deployments between nodes. When running the workload set the `workerHostNames` according to your cluster. Adjust the `replica` and `jobIteration` values to your test

- udn-density-l3: For User-Defined Network (UDN) L3 segmentation testing. It creates two deployments, a client/curl and a server/nginx.

**qps = Queries Per Second**
This is the sustained rate of API calls per second that kube-burner will send. Includes:
POST deployments, POST pods, POST services, GET requests to check status

**burst = Maximum burst capacity**
This is the maximum number of requests that can be sent at once in a short spike.

**How kube-burner implements QPS & Burst internally**
Kube-burner relies on the Kubernetes client-go library, which includes a built-in rate limiter. Specifically, it uses:
- Token Bucket Rate Limiter
client-go’s rate limiter uses the classic token bucket algorithm with:

+ qps → Token refill rate
Tokens added to the bucket every second.
+ burst → Bucket capacity
Maximum number of tokens allowed.
+ API call → consumes 1 token

If bucket has tokens → request goes through.
If bucket empty → request waits until tokens refill.