# 🛠️ Enterprise CI/CD Pipeline — Jenkins → GitLab CI with GitOps & Observability

**A production-grade CI/CD platform that automates the complete lifecycle of a Spring Boot application — from source code to security-scanned production deployment — using Kubernetes, GitOps (Argo CD), container security scanning, and dynamic application testing.**

---

## 📌 Project Overview

This project demonstrates an **enterprise-scale CI/CD architecture** with multiple implementations:

- **Phase 1 (Complete):** Jenkins-based CI/CD with Kubernetes agents
- **Phase 2 (Complete):** GitOps-driven deployment with Argo CD (automatic syncing)
- **Phase 3 (In Progress):** GitLab CI/CD migration (replaces Jenkins)
- **Phase 4 (Planned):** Prometheus + Grafana for full observability

### 🔧 Deployment Methods Used

| Method | Components |
|--------|-----------|
| **Helm** | Jenkins, SonarQube, Nexus |
| **Kustomize** | Argo CD, Prometheus + Grafana |

### What This Delivers

✅ Automated build with Maven (cached via Nexus proxy)
✅ Static code analysis & quality gates (SonarQube)
✅ Artifact publishing to private repository (Nexus)
✅ Rootless container image build (Kaniko — no Docker daemon)
✅ Software Bill of Materials + CVE scanning (Syft & Grype — pre-installed custom image)
✅ GitOps-based deployment (Argo CD with automatic sync)
✅ Dynamic Application Security Testing (OWASP ZAP)
✅ **Zero-downtime deployments** via Kubernetes rolling updates
✅ **Disaster recovery procedures** documented and tested
📋 **Full observability stack (planned)** (Prometheus + Grafana via Kustomize)

---

## 🏗️ Architecture Overview

### Technology Stack

| Layer | Technology | Purpose | Installation Method |
|-------|-----------|---------|----------------------|
| **Source Control** | GitHub (+ GitLab mirror) | Hosts code and pipeline definitions | — |
| **CI Server (Legacy)** | Jenkins + Kubernetes plugin | Orchestrates builds using ephemeral pods | Helm |
| **CI Server (New)** | GitLab CI | Replaces Jenkins (same pipeline logic) | GitLab Runner (Helm) |
| **Build Tool** | Maven | Compiles, tests, packages application | — |
| **Code Quality** | SonarQube | Static analysis & quality gates | Helm |
| **Artifact Repository** | Nexus Repository Manager | Maven proxy + Docker registry | Helm |
| **Image Builder** | Kaniko | Rootless Docker builds on Kubernetes | — |
| **Container Registry** | Docker Hub | Stores built application images | — |
| **SBOM & Scanning** | Syft & Grype (custom image) | SBOM generation + CVE scanning | — |
| **DAST** | OWASP ZAP | Runtime security testing | — |
| **Orchestration** | Kubernetes (Kind) | Runtime for all services | — |
| **CD/GitOps** | Argo CD (Kustomize) | Automatic cluster synchronization | **Kustomize** |
| **Observability** | Prometheus + Grafana | Metrics collection & visualization | **Kustomize** |

> **Note:** Jenkins, SonarQube, and Nexus are installed via **Helm charts**. Argo CD and the observability stack (Prometheus + Grafana) are deployed via **Kustomize** — no Helm chart involved for either.

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      DEVELOPER WORKFLOW                          │
└─────────────────────────────────────────────────────────────────┘
                            │
                    Git Push to GitHub
                            │
           ┌────────────────┴────────────────┐
           ▼                                 ▼
      JENKINS (Legacy)              GITLAB CI (New)
      Kubernetes Agents            GitLab Runners
           │                                 │
    ┌──────┴──────────────────────────────────┤
    ▼                                         ▼
[Stage: SonarQube Analysis]        [Stage: SonarQube Analysis]
[Stage: Maven Build → Nexus]       [Stage: Maven Build → Nexus]
[Stage: Kaniko Image Build]        [Stage: Kaniko Image Build]
[Stage: Syft/Grype Scan]           [Stage: Syft/Grype Scan]
[Stage: GitOps Update]             [Stage: GitOps Update]
      │                                 │
      └──────────────┬──────────────────┘
                     ▼
        Git Push to Manifests Repo
        (Update deployment.yaml)
                     │
    ┌────────────────┴────────────────┐
    ▼                                 ▼
  ARGOCD                         ARGOCD
  (Continuous Sync)              (Continuous Sync)
    │                                 │
    └──────────────┬──────────────────┘
                   ▼
         KUBERNETES CLUSTER
    ┌──────────────────────────────┐
    │  Application Pods Update      │
    │  (Rolling Deployment)         │
    │                               │
    ▼                               ▼
[OWASP ZAP DAST Scan]       [Prometheus Metrics]
[Build Artifacts Archive]   [Grafana Dashboards]
└──────────────────────────────────┘
```

---

## 🔄 Pipeline Stages (Same Logic for Jenkins & GitLab)

### 1. **Checkout Code**
Pulls latest source from Git.

### 2. **Static Code Analysis (SonarQube)**
- Runs `mvn sonar:sonar` with quality gates
- **Gating:** Blocks pipeline if quality threshold not met
- Runs **first** to prevent bad code from being packaged

### 3. **Build & Deploy to Nexus**
- Maven compiles, tests, and publishes artifact to Nexus
- Nexus Maven proxy caches dependencies (faster subsequent builds)

### 4. **Build & Push Image (Kaniko)**
- Rootless image build (no Docker daemon needed)
- Pushes to Docker Hub with build number + `latest` tags

### 5. **Security Scan (Syft & Grype)**
- **Syft:** Generates SBOM (CycloneDX format)
- **Grype:** Scans for CVEs with `--fail-on high` threshold
- Reports archived as build artifacts

### 6. **GitOps Update Manifests**
- Updates `deployment.yaml` image tag in manifests repository
- Commits change to trigger Argo CD sync
- **Separation of concerns:** Jenkins writes Git, Argo CD reads Git (true GitOps)

### 7. **DAST Scan (OWASP ZAP)**
- Runs baseline scan against **live** application in cluster
- Findings logged but don't fail build (for now)
- Report archived for security review

---

## ✅ Prerequisites

### Local Machine
- Kubernetes cluster: **Kind** (or any K8s cluster)
- `kubectl`, `helm`, `git` installed
- 8GB RAM allocated to cluster (minimum for all services)
- Docker Desktop or equivalent

### Source Repositories
- **Main repo:** `Mansourx83/CI-CD-Project` (GitHub)
  - `spring-boot-app/` — application source
  - `.gitlab-ci.yml` — GitLab CI pipeline
  - `Jenkinsfile` — Jenkins pipeline (legacy)
  - `syft-grype.Dockerfile` — custom scanning image
  - `helm-values/` — Helm configurations (Jenkins, SonarQube, Nexus)
  - `kustomize-manifests/argocd/` — Argo CD setup (Kustomize)
  - `kustomize-manifests/observability/` — Prometheus + Grafana setup (Kustomize)
  - `kubernetes-rbac.yaml` — RBAC for application
  - `jenkins-rbac.yaml` — RBAC for Jenkins (legacy)

- **GitOps repo:** `Mansourx83/spring-boot-app-manifests-gitops`
  - `deployment.yaml` — K8s deployment
  - `service.yaml` — K8s service
  - `kustomization.yaml` — Kustomize config

### Accounts & Credentials
- GitHub account with repository access
- GitLab account (for GitLab CI phase)
- Docker Hub account (for pushing images)
- SonarQube admin credentials (generated after install)
- Nexus admin credentials (generated after install)

---

## 🚀 Setup Guide

### Phase 1: Jenkins Setup (Existing Infrastructure) — via Helm

#### 1. Create Namespaces

```bash
kubectl create namespace jenkins
kubectl create namespace sonarqube
kubectl create namespace nexus
kubectl create namespace argocd
```

#### 2. Apply RBAC

```bash
# Jenkins RBAC (CI server)
kubectl apply -f jenkins-rbac.yaml

# Application RBAC
kubectl apply -f kubernetes-rbac.yaml
```

#### 3. Install via Helm

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

# Jenkins with persistent storage
helm install my-jenkins jenkins/jenkins -n jenkins -f helm-values/jenkins-values.yaml

# SonarQube (increased probe timeouts!)
helm install sonarqube sonarqube/sonarqube -n sonarqube -f helm-values/sonarqube-values.yaml

# Nexus (increased probe timeouts!)
helm install nexus sonatype/nexus-repository-manager -n nexus -f helm-values/nexus-values.yml
```

#### 4. Install Argo CD (via Kustomize)

> **Note:** Unlike Jenkins, SonarQube, and Nexus (installed via Helm), Argo CD is deployed using **Kustomize** — no Helm chart involved here.

```bash
kubectl apply -k kustomize-manifests/argocd/
```

#### 5. Retrieve Credentials

```bash
# Jenkins
kubectl get secret --namespace jenkins my-jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# SonarQube (default: admin/admin)
kubectl port-forward -n sonarqube svc/sonarqube-sonarqube 9000:9000

# Nexus
kubectl exec -it <nexus-pod> -n nexus -- cat /nexus-data/admin.password

# Argo CD
kubectl get secret --namespace argocd argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

#### 6. Create Jenkins Credentials

| ID | Type | Used For |
|----|------|----------|
| `docker-cred` | Username/Password | Kaniko → Docker Hub |
| `nexus-cred` | Username/Password | Maven → Nexus |
| `sonarqube-token` | Secret Text | SonarQube auth |
| `github-cred` | Username/Personal Access Token | GitOps manifest updates |

#### 7. Configure Nexus Maven Proxy

1. **Create `maven-central-proxy` repository** (type: maven2 proxy)
   - Remote storage: `https://repo1.maven.org/maven2/`

2. **Create `maven-public` repository** (type: maven2 group)
   - Members: `maven-central-proxy` + `maven-releases` + `maven-snapshots`

#### 8. Create Jenkins Multibranch Pipeline Job

- **New Item → Multibranch Pipeline**
- Branch source: GitHub repository
- Build configuration: by Jenkinsfile

---

### Phase 2: GitOps Setup (Argo CD via Kustomize)

#### 1. Create Argo CD Application

Navigate to Argo CD UI (localhost:8083) and create application:

- **Name:** `spring-boot-app`
- **Repository URL:** `https://github.com/Mansourx83/spring-boot-app-manifests-gitops.git`
- **Path:** `.` (root)
- **Destination Cluster:** `kubernetes.default.svc`
- **Destination Namespace:** `jenkins`
- **Sync Policy:** Automatic

Or use YAML:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: spring-boot-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Mansourx83/spring-boot-app-manifests-gitops.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: jenkins
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### Phase 3: GitLab CI/CD Migration (🔄 In Progress)

#### 1. Create GitLab Project

- Import from GitHub or create new
- Copy `.gitlab-ci.yml` to root

#### 2. Install GitLab Runner

```bash
# On Kubernetes (recommended)
helm repo add gitlab https://charts.gitlab.io
helm install gitlab-runner gitlab/gitlab-runner -n gitlab-runner --create-namespace \
  --set gitlab-url=https://gitlab.com/ \
  --set gitlabToken=<YOUR_RUNNER_TOKEN> \
  --set runners.image=ubuntu:22.04
```

#### 3. Push `.gitlab-ci.yml`

(See GitLab section below)

> **Status:** This phase is still being worked on — pipeline logic is being ported over from the Jenkinsfile, and stage-by-stage validation against GitLab Runner is ongoing.

---

### Phase 4: Prometheus + Grafana (Planned — via Kustomize)

> **Note:** Observability stack will be deployed via **Kustomize**, consistent with Argo CD's installation method — not Helm, unlike Jenkins/SonarQube/Nexus.

#### 1. Create Namespace & Deploy

```bash
kubectl create namespace monitoring
kubectl apply -k kustomize-manifests/observability/base/
```

Or target a specific environment overlay:

```bash
kubectl apply -k kustomize-manifests/observability/overlays/prod/
```

#### 2. Verify Deployment

```bash
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

#### 3. Kustomize Structure

```
kustomize-manifests/observability/
├── base/
│   ├── namespace.yaml
│   ├── prometheus/
│   │   ├── prometheus-deployment.yaml
│   │   ├── prometheus-service.yaml
│   │   ├── prometheus-configmap.yaml
│   │   └── prometheus-rbac.yaml
│   ├── grafana/
│   │   ├── grafana-deployment.yaml
│   │   ├── grafana-service.yaml
│   │   └── grafana-datasource-configmap.yaml
│   └── kustomization.yaml
└── overlays/
    └── prod/
        └── kustomization.yaml
```

Dashboards to create:
- **Pipeline Metrics:** Build duration, success rates, stage breakdowns
- **Application Metrics:** Request rate, latency, error rate, resource usage
- **Infrastructure Metrics:** Cluster CPU/memory, pod restarts, network I/O

> **Status:** This phase has not been implemented yet — the Kustomize structure above is the planned layout.

---

## 📋 File Organization

### Main Repository (`CI-CD-Project`)

```
CI-CD-Project/
├── spring-boot-app/              # Application source code
│   ├── src/main/java/...
│   ├── pom.xml
│   ├── Dockerfile
│   └── README.md
├── spring-boot-app-manifests/    # (Legacy, moved to separate repo)
│   ├── deployment.yaml
│   └── service.yaml
├── .gitlab-ci.yml                # GitLab CI pipeline
├── Jenkinsfile                   # Jenkins pipeline (legacy)
├── syft-grype.Dockerfile         # Custom Syft+Grype image
├── helm-values/                  # Helm configurations (Jenkins, SonarQube, Nexus)
│   ├── jenkins-values.yaml
│   ├── sonarqube-values.yaml
│   └── nexus-values.yml
├── kustomize-manifests/          # Kustomize configs
│   ├── argocd/                   # Argo CD install
│   │   └── kustomization.yaml
│   └── observability/            # Prometheus + Grafana install
│       ├── base/
│       └── overlays/
├── kubernetes-rbac.yaml          # App-level RBAC
├── jenkins-rbac.yaml             # Jenkins RBAC (legacy)
├── .gitignore
└── README.md
```

### GitOps Repository (`spring-boot-app-manifests-gitops`)

```
spring-boot-app-manifests-gitops/
├── deployment.yaml               # Updated by Jenkins/GitLab CI
├── service.yaml
├── kustomization.yaml
└── README.md
```

---

## 🔐 Security Best Practices

✅ **Quality gates first:** SonarQube runs before packaging/building
✅ **Rootless builds:** Kaniko used instead of Docker socket
✅ **SBOM tracking:** Every image gets Syft-generated SBOM
✅ **CVE scanning:** Grype gates on high/critical vulnerabilities
✅ **No credentials in code:** All secrets in Jenkins/GitLab CI variables
✅ **RBAC isolation:** Minimal permissions per ServiceAccount
✅ **GitOps separation:** CI writes Git, CD reads Git (audit trail in Git history)
✅ **Runtime scanning:** DAST scans live application, not just static code/images

---

## 🔄 Disaster Recovery

### Full Cluster Reset

```bash
# Delete and recreate Kind cluster
kind delete cluster
kind create cluster --config kind-config.yaml

# Recreate namespaces
kubectl create namespace jenkins sonarqube nexus argocd

# Apply RBAC
kubectl apply -f jenkins-rbac.yaml kubernetes-rbac.yaml

# Reinstall Helm-based charts
helm install my-jenkins jenkins/jenkins -n jenkins -f helm-values/jenkins-values.yaml
helm install sonarqube sonarqube/sonarqube -n sonarqube -f helm-values/sonarqube-values.yaml
helm install nexus sonatype/nexus-repository-manager -n nexus -f helm-values/nexus-values.yml

# Reapply Kustomize-based components
kubectl apply -k kustomize-manifests/argocd/

# (Once Phase 4 is implemented) reapply observability stack:
# kubectl apply -k kustomize-manifests/observability/base/

# Recreate credentials (see "Setup" section)
```

**Credentials that do NOT survive cluster reset:**
- Jenkins Credentials (docker-cred, nexus-cred, sonarqube-token, github-cred)
- Nexus Maven proxy configuration
- SonarQube tokens (regenerate via `My Account → Security`)

**Things that DO survive (if using persistent volumes):**
- Jenkins job definitions and build history
- Application deployment history in Argo CD

---

## 🚨 Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| SonarQube/Nexus pods restart repeatedly | Probe timeouts too short for slow startup (7-15 min) | Increase `initialDelaySeconds=180`, `timeoutSeconds=10`, `failureThreshold=20-30` in Helm values |
| Nexus PVC stuck `Terminating` | Incomplete resource cleanup | `helm uninstall nexus -n nexus`, `kubectl delete namespace nexus --force --grace-period=0`, recreate |
| ZAP scan fails: "directory not mounted" | No volume for `/zap/wrk` | Add `emptyDir` volume to ZAP pod spec |
| `kubectl cp` fails for ZAP | Pod already completed | Keep container alive with `sleep 300` after scan, then copy, then delete |
| RBAC: `pods/log` forbidden | Jenkins ServiceAccount missing permissions | Add `pods/log` and `pods/exec` to `jenkins-rbac.yaml` ClusterRole |
| SonarQube: "Not authorized" | Stale token after reinstall | Regenerate token in `My Account → Security` after SonarQube reinstall |
| Maven can't find artifact | Not using Nexus proxy | Configure Maven `settings.xml` mirror to point to Nexus `maven-public` group repo |

---

## 📊 Observability Roadmap

### Prometheus + Grafana (Kustomize) — 📋 Planned

**Metrics to collect:**
- **Pipeline metrics:** Build duration, success rate, stage duration breakdown
- **Application metrics:** Request rate, response latency, error rate
- **Infrastructure metrics:** Pod CPU/memory usage, cluster capacity, network I/O
- **Security metrics:** CVE scan results trend, DAST findings count

**Dashboards to build:**
1. **CI/CD Health Dashboard** — build trends, deployment frequency, lead time
2. **Application Performance Dashboard** — request rate, latency p50/p95/p99, errors
3. **Infrastructure Dashboard** — cluster utilization, pod restarts, disk I/O

---

## 📝 Summary

This project demonstrates an **enterprise-scale CI/CD platform** with:

✅ **Jenkins-based CI** (Phase 1 — complete, legacy, Helm)
🔄 **GitLab CI** (Phase 3 — in progress, replacing Jenkins, same pipeline logic)
✅ **GitOps deployment** (Phase 2 — complete, fully automatic, Kustomize)
✅ **Multi-layer security scanning** (static + dynamic)
✅ **Production-grade disaster recovery** (documented and tested)
📋 **Observability** (Phase 4 — planned, Prometheus + Grafana )

**Total automation:** From code commit to production-ready, security-tested deployment — **zero manual steps** after initial Argo CD setup.

---

## 🎯 Next Steps

1. ✅ Complete Phase 1 (Jenkins — Helm) — **DONE**
2. ✅ Complete Phase 2 (Argo CD GitOps — Kustomize) — **DONE**
3. 🔄 Complete Phase 3 (GitLab CI/CD) — **IN PROGRESS**
4. 📋 Complete Phase 4 (Prometheus + Grafana) — **PLANNED**

---

## 📚 References

- [Kubernetes Best Practices](https://kubernetes.io/docs/)
- [GitOps with Argo CD](https://argo-cd.readthedocs.io/)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Kaniko Container Builder](https://github.com/GoogleContainerTools/kaniko)
- [Syft SBOM Tool](https://github.com/anchore/syft)
- [Grype Vulnerability Scanner](https://github.com/anchore/grype)
- [OWASP ZAP Security Testing](https://www.zaproxy.org/)
- [SonarQube Code Quality](https://www.sonarqube.org/)
- [Nexus Repository Manager](https://www.sonatype.com/products/repository-oss)
- [Kustomize](https://kustomize.io/)

---

**Project Status:** Production-Ready (Phase 1-2) | GitLab CI In-Progress (Phase 3) | Observability Planned (Phase 4)

**Last Updated:** August 2026
