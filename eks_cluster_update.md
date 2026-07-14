# Amazon Elastic Kubernetes Service (EKS) Cluster Upgrade Guide (2026)

A complete, production-ready guide for upgrading an **Amazon Elastic Kubernetes Service (EKS) Cluster** using the latest **AWS CLI** and **kubectl**.

---

## Environment

| Item | Value |
|------|-------|
| Kubernetes | Amazon EKS |
| Upgrade Method | AWS CLI |
| AWS CLI | Latest Version |
| Cluster Name | `production-cluster` |
| Region | `us-east-1` |

---

# EKS Upgrade Workflow

```text
                    Check Cluster Health
                             │
                             ▼
                  Check Current Version
                             │
                             ▼
               Check Available EKS Versions
                             │
                             ▼
                  Upgrade Control Plane
                             │
                             ▼
             Verify Control Plane Version
                             │
                             ▼
              Upgrade Managed Node Groups
                             │
                             ▼
                Upgrade Add-ons (Optional)
                             │
                             ▼
                 Verify Node Versions
                             │
                             ▼
              Validate Applications & Pods
                             │
                             ▼
                 Monitor Production
```

---

# 1. Verify Cluster Health

Before upgrading, ensure your cluster is healthy.

## Check Nodes

```bash
kubectl get nodes
```

Example

```text
NAME                                           STATUS   VERSION
ip-192-168-1-101.ec2.internal                  Ready    v1.31.x
ip-192-168-1-102.ec2.internal                  Ready    v1.31.x
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

```bash
aws eks describe-cluster \
    --name production-cluster \
    --region us-east-1 \
    --query "cluster.version"
```

Example

```text
"1.31"
```

---

# 3. List Managed Node Groups

```bash
aws eks list-nodegroups \
    --cluster-name production-cluster \
    --region us-east-1
```

Example

```text
{
    "nodegroups": [
        "production-nodegroup"
    ]
}
```

---

# 4. Check Current Node Group Version

```bash
aws eks describe-nodegroup \
    --cluster-name production-cluster \
    --nodegroup-name production-nodegroup \
    --region us-east-1
```

---

# 5. Check Available Kubernetes Versions

```bash
aws eks describe-addon-versions
```

or

```bash
aws eks describe-cluster-versions
```

Verify the Kubernetes versions supported in your AWS Region.

---

# 6. Upgrade the Control Plane

Upgrade only the EKS Control Plane.

```bash
aws eks update-cluster-version \
    --name production-cluster \
    --kubernetes-version 1.32 \
    --region us-east-1
```

Example Output

```text
Cluster update initiated.
```

---

# 7. Monitor Upgrade Progress

```bash
aws eks describe-update \
    --name production-cluster \
    --update-id UPDATE_ID \
    --region us-east-1
```

Wait until

```text
status = Successful
```

---

# 8. Verify Control Plane Version

```bash
aws eks describe-cluster \
    --name production-cluster \
    --region us-east-1 \
    --query "cluster.version"
```

Expected

```text
1.32
```

---

# 9. Upgrade Managed Node Group

Upgrade the managed node group.

```bash
aws eks update-nodegroup-version \
    --cluster-name production-cluster \
    --nodegroup-name production-nodegroup \
    --region us-east-1
```

To upgrade to a specific AMI release:

```bash
aws eks update-nodegroup-version \
    --cluster-name production-cluster \
    --nodegroup-name production-nodegroup \
    --release-version latest \
    --region us-east-1
```

---

# 10. Verify Node Upgrade

```bash
kubectl get nodes
```

Expected

```text
NAME                                      STATUS   VERSION
ip-192-168-1-101.ec2.internal             Ready    v1.32.x
ip-192-168-1-102.ec2.internal             Ready    v1.32.x
```

---

# 11. Upgrade Core Add-ons

## Update VPC CNI

```bash
aws eks update-addon \
    --cluster-name production-cluster \
    --addon-name vpc-cni \
    --resolve-conflicts OVERWRITE
```

---

## Update CoreDNS

```bash
aws eks update-addon \
    --cluster-name production-cluster \
    --addon-name coredns \
    --resolve-conflicts OVERWRITE
```

---

## Update kube-proxy

```bash
aws eks update-addon \
    --cluster-name production-cluster \
    --addon-name kube-proxy \
    --resolve-conflicts OVERWRITE
```

---

## Update EBS CSI Driver

```bash
aws eks update-addon \
    --cluster-name production-cluster \
    --addon-name aws-ebs-csi-driver \
    --resolve-conflicts OVERWRITE
```

---

# 12. Verify Add-ons

```bash
aws eks list-addons \
    --cluster-name production-cluster
```

---

# 13. Validate Workloads

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

# 14. Check Rollout Status

```bash
kubectl rollout status deployment/myapp -n production
```

---

# 15. Validate the Application

Retrieve the LoadBalancer.

```bash
kubectl get svc -n production
```

Example

```text
NAME          TYPE           EXTERNAL-IP
myapp         LoadBalancer   xxxxxxxxx.elb.amazonaws.com
```

Open

```
http://ELB-DNS-NAME
```

Verify

- UI loads
- APIs respond
- Pods are healthy
- No application errors

---

# Useful Commands

## List Clusters

```bash
aws eks list-clusters
```

---

## Describe Cluster

```bash
aws eks describe-cluster \
    --name production-cluster
```

---

## List Node Groups

```bash
aws eks list-nodegroups \
    --cluster-name production-cluster
```

---

## Describe Node Group

```bash
aws eks describe-nodegroup \
    --cluster-name production-cluster \
    --nodegroup-name production-nodegroup
```

---

## View Nodes

```bash
kubectl get nodes
```

---

## View Pods

```bash
kubectl get pods -A
```

---

## View Services

```bash
kubectl get svc -A
```

---

## View Events

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

# Production Best Practices

## Before Upgrading

- Ensure all Pods are healthy.
- Upgrade one Kubernetes minor version at a time.
- Backup application data.
- Verify Persistent Volumes.
- Review Kubernetes API deprecations.
- Upgrade in Dev before Production.
- Ensure PodDisruptionBudgets are configured.
- Verify Auto Scaling Groups have sufficient capacity.

---

## During Upgrade

- Upgrade Control Plane first.
- Upgrade Managed Node Groups.
- Upgrade EKS Add-ons.
- Monitor workloads continuously.

Useful Commands

```bash
kubectl get nodes -w
```

```bash
kubectl get pods -A -w
```

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## After Upgrade

Verify

- Nodes Ready
- Pods Running
- Services Healthy
- Ingress Working
- Add-ons Healthy
- Smoke Tests Passed
- No Errors in Logs

---

# Troubleshooting

## Unsupported Kubernetes Version

```text
InvalidParameterException
```

Verify supported versions.

```bash
aws eks describe-addon-versions
```

---

## Node Group Upgrade Failed

Describe the update.

```bash
aws eks describe-update \
    --name production-cluster \
    --update-id UPDATE_ID
```

---

## Pods Not Starting

```bash
kubectl describe pod POD_NAME
```

```bash
kubectl logs POD_NAME
```

---

## Node Not Ready

```bash
kubectl describe node NODE_NAME
```

---

## Deployment Failed

```bash
kubectl rollout status deployment/myapp -n production
```

Rollback if required.

```bash
kubectl rollout undo deployment/myapp -n production
```

---

# Upgrade Checklist

## Pre-Upgrade

- [ ] Verify Cluster Health
- [ ] Verify Nodes
- [ ] Verify Pods
- [ ] Verify Deployments
- [ ] Verify Services
- [ ] Check Current Kubernetes Version
- [ ] Review Supported Kubernetes Versions
- [ ] Backup Critical Data

---

## Upgrade

- [ ] Upgrade Control Plane
- [ ] Verify Control Plane
- [ ] Upgrade Managed Node Groups
- [ ] Upgrade EKS Add-ons
- [ ] Verify Nodes

---

## Post-Upgrade

- [ ] Verify Pods
- [ ] Verify Services
- [ ] Verify Deployments
- [ ] Verify Ingress
- [ ] Run Smoke Tests
- [ ] Review Logs
- [ ] Monitor Production

---

# References

- Amazon EKS User Guide
- AWS CLI EKS Command Reference
- Amazon EKS Best Practices Guide
- Kubernetes Version Skew Policy

---

# Upgrade Summary

| Step | Action |
|------|--------|
| 1 | Verify Cluster Health |
| 2 | Check Current Version |
| 3 | Check Node Groups |
| 4 | Review Supported Versions |
| 5 | Upgrade Control Plane |
| 6 | Verify Control Plane |
| 7 | Upgrade Managed Node Groups |
| 8 | Upgrade EKS Add-ons |
| 9 | Verify Nodes |
| 10 | Validate Applications |
| 11 | Monitor Production |
