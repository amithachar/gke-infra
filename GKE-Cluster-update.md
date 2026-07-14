# GCP DevOps Management

Complete guide for upgrading a Google Kubernetes Engine (GKE) Standard Cluster.

---

# 1. Verify Cluster Health

Before starting the upgrade, ensure the Kubernetes cluster is healthy.

## Check Nodes

```bash
kubectl get nodes
```

Expected Output

```text
NAME                                         STATUS   VERSION
gke-lottery-cluster-default-pool-xxxxx       Ready    v1.34.x
```

---

## Check Pods

```bash
kubectl get pods -A
```

Verify:

- No CrashLoopBackOff
- No Pending Pods
- All Pods Running

---

## Check Deployments

```bash
kubectl get deployment -A
```

---

## Check Services

```bash
kubectl get svc -A
```

---

# 2. Check Current Cluster Version

Retrieve the current Control Plane and Node versions.

```bash
gcloud container clusters describe lottery-cluster \
    --zone us-central1-a \
    --format="value(currentMasterVersion,currentNodeVersion)"
```

Example Output

```text
1.34.6-gke.1056000
1.34.6-gke.1056000
```

---

# 3. Check Available Upgrade Versions

View all Kubernetes versions available for your region.

```bash
gcloud container get-server-config \
    --zone us-central1-a
```

Example

```text
Valid Master Versions

1.35.5-gke.1324000
1.35.4-gke.1200000
1.34.9-gke.1000000
```

---

# 4. Upgrade the Control Plane

Upgrade only the Kubernetes Control Plane.

```bash
gcloud container clusters upgrade lottery-cluster \
    --master \
    --cluster-version=1.35.5-gke.1324000 \
    --zone us-central1-a
```

When prompted:

```text
Do you want to continue (Y/n)?
```

Type:

```text
Y
```

---

# 5. Verify the Control Plane

```bash
gcloud container clusters describe lottery-cluster \
    --zone us-central1-a \
    --format="value(currentMasterVersion)"
```

---

# 6. Upgrade the Node Pool

The latest Google Cloud CLI upgrades node pools using the cluster upgrade command.

```bash
gcloud container clusters upgrade lottery-cluster \
    --node-pool=default-pool \
    --cluster-version=1.35.5-gke.1324000 \
    --zone us-central1-a
```

---

# 7. Verify Node Versions

```bash
kubectl get nodes
```

Expected Output

```text
NAME                                      STATUS   VERSION
gke-lottery-default-pool-abcde            Ready    v1.35.5-gke.1324000
```

---

# 8. Validate the Workloads

## Check Pods

```bash
kubectl get pods -A
```

---

## Check Deployments

```bash
kubectl get deployment -A
```

---

## Check Services

```bash
kubectl get svc -A
```

---

# 9. Check Rollout Status

```bash
kubectl rollout status deployment/lottery -n dev
```

---

# 10. Test the Application

Retrieve the external IP.

```bash
kubectl get svc -n dev
```

Example

```text
NAME               TYPE           EXTERNAL-IP
lottery-service    LoadBalancer   34.xxx.xxx.xxx
```

Open

```
http://EXTERNAL-IP
```

Verify:

- UI loads
- API works
- Pods are healthy
- No errors

---

# Production Checklist

- [ ] Cluster Healthy
- [ ] Pods Running
- [ ] Nodes Ready
- [ ] Control Plane Upgraded
- [ ] Node Pools Upgraded
- [ ] Services Working
- [ ] Smoke Tests Passed
- [ ] Logs Reviewed

---

# References

- Google Kubernetes Engine Documentation
- Google Cloud CLI Documentation
- Kubernetes Version Skew Policy
