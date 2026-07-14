# Kubernetes Architecture Explained (Beginner to Production)

A complete beginner-to-production guide explaining **how Kubernetes works internally** and **what happens when you run a Deployment** using `kubectl`.

---

## What Happens When You Run?

```bash
kubectl apply -f deployment.yaml
```

Kubernetes receives your request, stores the desired state, schedules Pods, creates containers, configures networking, and continuously ensures that your application remains healthy.

---

# Kubernetes as a Company

One of the easiest ways to understand Kubernetes is to compare it to a company.

| Company | Kubernetes Component | Responsibility |
|----------|----------------------|----------------|
| 👨‍💻 Employee | Developer / DevOps Engineer | Submits work |
| 📩 Reception | `kubectl` | Sends the request |
| 👨‍💼 Manager | API Server | Receives and validates requests |
| 📁 Database | etcd | Stores all cluster information |
| 👮 Supervisor | Controller Manager | Ensures desired state matches actual state |
| 👥 HR | Scheduler | Assigns work to employees |
| 👷 Employees | Worker Nodes | Execute the work |
| 🛠 Machine Operator | kubelet | Starts containers |
| 📦 Factory Machine | Container Runtime | Runs containers |
| 🚦 Traffic Manager | kube-proxy | Routes network traffic |

---

# Kubernetes Architecture

```text
                           USER / DEVOPS ENGINEER
                                    │
                                    │
                    kubectl apply -f deployment.yaml
                                    │
                                    ▼
                     +-------------------------------+
                     |         API SERVER            |
                     |  Entry Point of Kubernetes    |
                     +-------------------------------+
                          │      │         │
                          │      │
                          │      │ Validate Request
                          │
                          ▼
                    +----------------+
                    |      ETCD      |
                    | Cluster Database|
                    +----------------+
                          ▲
                          │
                          │ Desired State
                          │
                +-------------------------+
                | Controller Manager      |
                +-------------------------+
                          │
                          │ Creates ReplicaSet
                          ▼
                +-------------------------+
                | Kubernetes Scheduler    |
                +-------------------------+
                          │
                Select Best Worker Node
                          │
          ┌───────────────┼─────────────────┐
          │               │                 │
          ▼               ▼                 ▼
 +----------------+ +----------------+ +----------------+
 | Worker Node 1  | | Worker Node 2  | | Worker Node 3  |
 |----------------| |----------------| |----------------|
 | kubelet        | | kubelet        | | kubelet        |
 | kube-proxy     | | kube-proxy     | | kube-proxy     |
 | Container      | | Container      | | Container      |
 | Runtime        | | Runtime        | | Runtime        |
 +----------------+ +----------------+ +----------------+
          │
          ▼
    Docker / containerd / CRI-O
          │
          ▼
     Running Application Pods
```

---

# Kubernetes Components

---

# 1. kubectl

`kubectl` is the Kubernetes Command Line Interface (CLI).

Whenever you execute a command such as:

```bash
kubectl apply -f deployment.yaml
```

`kubectl` converts the YAML into an API request and sends it to the Kubernetes API Server.

Think of it like:

> 🌐 A web browser sending a request to a website.

---

# 2. API Server

The **API Server** is the heart of Kubernetes.

Every Kubernetes component communicates through the API Server.

### Responsibilities

- Authentication
- Authorization
- Validate YAML
- Accept API requests
- Store objects in etcd
- Return responses
- Communicate with Controllers and Scheduler

### Example

You execute

```bash
kubectl apply -f deployment.yaml
```

The API Server checks:

- Is the YAML valid?
- Does the namespace exist?
- Is the Deployment API correct?
- Does the user have permission?
- Does the image name exist?

If everything is valid, it stores the Deployment in etcd.

---

# 3. etcd

`etcd` is Kubernetes' distributed database.

It stores the **Desired State** of the cluster.

### Examples of Data Stored

- Deployments
- ReplicaSets
- Pods
- Services
- ConfigMaps
- Secrets
- Nodes
- Namespaces
- Persistent Volumes

Example Deployment

```yaml
replicas: 3
image: nginx
namespace: dev
```

etcd stores

```text
Desired State

Deployment
-----------
Replicas : 3
Image    : nginx
Namespace: dev
```

> **Important:** etcd **does not create Pods**. It only stores the desired state.

---

# 4. Controller Manager

The Controller Manager continuously compares:

```text
Desired State
        VS
Actual State
```

Example

Desired Pods

```text
3
```

Actual Pods

```text
0
```

Controller Manager detects the difference.

It creates a ReplicaSet.

ReplicaSet creates:

```text
Pod-1
Pod-2
Pod-3
```

This process is called **Reconciliation**.

---

# 5. Scheduler

Once Pods are created, they don't know which node to run on.

The Scheduler selects the best Worker Node.

Example

| Worker Node | CPU | Memory | Decision |
|-------------|----:|-------:|----------|
| Worker-1 | 80% | 90% | Skip |
| Worker-2 | 20% | 30% | Selected |
| Worker-3 | 60% | 70% | Skip |

Scheduler assigns

```text
Pod → Worker Node 2
```

---

# 6. kubelet

Every Worker Node contains a kubelet.

The kubelet receives instructions from the API Server.

Example

```text
Run Pod
```

The kubelet asks the Container Runtime to:

- Pull the image
- Create the container
- Start the container

---

# 7. Container Runtime

The Container Runtime actually runs containers.

Common runtimes include:

- containerd
- CRI-O
- Docker (older Kubernetes versions)

Example

```text
Pull Image

nginx:latest
```

Then

- Download image
- Create container
- Start container

---

# 8. kube-proxy

Every Worker Node runs kube-proxy.

Its responsibility is networking.

It maps

```text
Service
     │
     ▼
Pod IP
     │
     ▼
Container
```

Example

User opens

```text
http://myapp-service
```

kube-proxy forwards requests to

```text
Pod-1

Pod-2

Pod-3
```

This provides built-in load balancing.

---

# Complete Deployment Flow

Suppose the Deployment YAML contains:

```yaml
replicas: 3
image: nginx
```

---

## Step 1

Developer executes

```bash
kubectl apply -f deployment.yaml
```

↓

---

## Step 2

API Server receives the request.

- Validate YAML
- Authenticate User
- Authorize Request

↓

---

## Step 3

Deployment is stored inside etcd.

```text
Deployment

Replicas = 3
Image = nginx
```

↓

---

## Step 4

Controller Manager notices

```text
Desired Pods = 3
Actual Pods = 0
```

Creates ReplicaSet.

↓

---

## Step 5

ReplicaSet creates

```text
Pod-1

Pod-2

Pod-3
```

↓

---

## Step 6

Scheduler selects

```text
Worker Node 2
```

↓

---

## Step 7

kubelet receives

```text
Run Pod
```

↓

---

## Step 8

Container Runtime

```text
Pull nginx image
```

↓

---

## Step 9

Container starts.

↓

---

## Step 10

Pod becomes

```text
Running
```

↓

---

## Step 11

kube-proxy updates networking.

↓

---

## Step 12

Application becomes available.

---

# Complete Internal Flow Diagram

```text
Developer
    │
    │ kubectl apply -f deployment.yaml
    ▼
+----------------------+
|      kubectl         |
+----------------------+
          │
          ▼
+----------------------+
|     API Server       |
| Validate Request     |
+----------------------+
          │
          ▼
+----------------------+
|        etcd          |
| Desired State Store  |
+----------------------+
          ▲
          │
+----------------------+
| Controller Manager   |
| Compare Desired vs   |
| Actual State         |
+----------------------+
          │
          ▼
+----------------------+
| ReplicaSet Created   |
+----------------------+
          │
          ▼
+----------------------+
|     Scheduler        |
| Select Worker Node   |
+----------------------+
          │
          ▼
+----------------------+
|      kubelet         |
+----------------------+
          │
          ▼
+----------------------+
| Container Runtime    |
| containerd / CRI-O   |
+----------------------+
          │
          ▼
+----------------------+
| Running Pod          |
+----------------------+
          │
          ▼
+----------------------+
| kube-proxy           |
| Configure Networking |
+----------------------+
          │
          ▼
     Application Ready
```

---

# What Happens if a Pod Crashes?

Suppose

```text
Pod-2
```

crashes.

Current state

```text
Pod-1 ✅

Pod-2 ❌

Pod-3 ✅
```

Controller Manager checks

```text
Desired Pods = 3

Actual Pods = 2
```

Difference detected.

New flow

```text
Controller Manager
        │
        ▼
Create New Pod
        │
        ▼
Scheduler Selects Node
        │
        ▼
kubelet Starts Pod
        │
        ▼
Container Runtime Pulls Image
        │
        ▼
New Pod Running
```

This automatic recovery is known as **Self-Healing**.

---

# Interview Memory Trick

Remember the sequence:

```text
K → A → E → C → S → K → C → P
```

| Letter | Component | Responsibility |
|---------|-----------|----------------|
| K | kubectl | Sends request |
| A | API Server | Validates request |
| E | etcd | Stores desired state |
| C | Controller Manager | Creates and monitors resources |
| S | Scheduler | Selects Worker Node |
| K | kubelet | Starts Pods |
| C | Container Runtime | Runs Containers |
| P | kube-proxy | Routes network traffic |

---

# Key Takeaways

- `kubectl` sends requests to the API Server.
- API Server validates and stores the desired state in **etcd**.
- Controller Manager continuously compares the desired state with the actual state.
- Scheduler selects the most suitable Worker Node.
- kubelet starts the Pod using the Container Runtime.
- kube-proxy configures networking and load balancing.
- Kubernetes continuously monitors workloads and automatically recreates failed Pods, providing **self-healing**, **scalability**, and **high availability**.
