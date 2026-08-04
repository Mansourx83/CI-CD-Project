# 🛠️ Jenkins CI/CD Pipeline for a Spring Boot App — Kubernetes, SonarQube, Nexus, Kaniko, Syft/Grype & OWASP ZAP

**An end-to-end Jenkins pipeline that builds, tests, analyzes, publishes, containerizes, scans, deploys, and security-tests a Spring Boot application on a Kubernetes (Kind) cluster.**

---

## 📌 Project Overview

This project automates the complete lifecycle of a Spring Boot application — from source code checkout to a running, security-scanned deployment on Kubernetes — using a self-hosted, cloud-native toolchain running entirely inside the cluster.

### What This Delivers

✅ Automated build with Maven
✅ Static code analysis & quality gate (SonarQube)
✅ Artifact publishing to a private repository (Nexus)
✅ Rootless container image build (Kaniko — no Docker daemon required)
✅ Software Bill of Materials + vulnerability scanning (Syft & Grype)
✅ Automated deployment to Kubernetes
✅ Dynamic Application Security Testing against the live app (OWASP ZAP)

---

## 🏗️ Architecture & Technology Stack

| Component | Technology | Purpose |
| --- | --- | --- |
| **Source Control** | Git / GitHub | Hosts application code and the Jenkinsfile |
| **CI/CD Server** | Jenkins (Kubernetes plugin) | Orchestrates the pipeline using ephemeral per-build pods |
| **Build Tool** | Maven | Compiles, tests, and packages the application |
| **Code Quality** | SonarQube | Static analysis and code quality gating |
| **Artifact Repository** | Nexus Repository Manager | Hosts published Maven artifacts |
| **Image Build** | Kaniko | Builds and pushes container images without a Docker daemon |
| **Container Registry** | Docker Hub | Stores the built application images |
| **SBOM & Vulnerability Scanning** | Syft & Grype | Generates a software bill of materials and scans the image for known CVEs |
| **DAST** | OWASP ZAP | Scans the live, deployed application for runtime security issues |
| **Orchestration** | Kubernetes (Kind) | Runtime environment for Jenkins, SonarQube, Nexus, and the application |

---

## ✅ Prerequisites

- A Kubernetes cluster (this project uses **Kind** running locally)
- `kubectl` and `helm` installed and configured against the cluster
- A Spring Boot application repository containing:
  - `spring-boot-app/` — source code, `pom.xml`, `Dockerfile`
  - `spring-boot-app-manifests/` — `deployment.yaml`, `service.yaml`
  - `Jenkinsfile` at the repository root
- A Docker Hub account (for pushing built images)

---

## 🔌 Cluster Components (installed via Helm)

| Component | Namespace | Notes |
| --- | --- | --- |
| **Jenkins** | `jenkins` | Installed via the official Helm chart, using Kubernetes agents (no static build nodes) |
| **SonarQube** | `sonarqube` | Installed via the SonarQube Helm chart (Community Edition) |
| **Nexus Repository Manager** | `nexus` | Installed via the Sonatype Helm chart |

> ⚠️ **Startup probes:** SonarQube and Nexus both take several minutes to fully initialize on first boot. Default Helm chart liveness/readiness probe timeouts are too aggressive for this and will cause repeated pod restarts before the app is ready. Increase `initialDelaySeconds`, `timeoutSeconds`, and `failureThreshold` in the Helm values for both charts (see `helm-values/`).

---

## 🔄 Jenkins Pipeline Stages

### Complete Pipeline Flow

#### **Stage 1: Checkout Code**
Pulls the latest source from the configured Git repository (`checkout scm`).

#### **Stage 2: Static Code Analysis (SonarQube)**
Runs `mvn sonar:sonar` against the in-cluster SonarQube instance, authenticated via a Jenkins-stored token. Runs **before** publishing or building an image, so bad code never gets packaged.

#### **Stage 3: Build and Deploy to Nexus**
Publishes the Maven artifact to the in-cluster Nexus repository using a generated `settings.xml` with Nexus credentials.

#### **Stage 4: Build & Push Image (Kaniko)**
Builds the application's Docker image using Kaniko (no Docker daemon needed inside the Jenkins agent pod) and pushes it to Docker Hub, tagged with both the Jenkins build number and `latest`.

#### **Stage 5: Security Scan (Syft & Grype)**
- **Syft** generates a full SBOM (`sbom.json`) for the built image.
- **Grype** scans the same image for known CVEs and prints a summary table.
- Both reports are archived as Jenkins build artifacts.

#### **Stage 6: Deploy to K8s**
Applies or updates the Kubernetes Deployment/Service for the application, then waits for the rollout to complete (`kubectl rollout status`).

#### **Stage 7: DAST Scan (OWASP ZAP)**
Runs an OWASP ZAP baseline scan against the **live, deployed** application inside the cluster. The ZAP pod mounts an `emptyDir` volume for its working directory, stays alive briefly after the scan so the HTML report can be copied out via `kubectl cp`, and is then cleaned up. Findings do not fail the build — they are reported for review, not enforced as a hard gate (for now).

---

## 🚀 Setup Guide

### 1. Create Namespaces

```bash
kubectl create namespace jenkins
kubectl create namespace sonarqube
kubectl create namespace nexus
```

### 2. Apply Jenkins RBAC

The Jenkins ServiceAccount needs permissions beyond the Kubernetes plugin defaults — specifically `pods/log` and `pods/exec`, required by the DAST stage's `kubectl logs` and `kubectl cp` calls.

```bash
kubectl apply -f jenkins-rbac.yaml
```

### 3. Install Jenkins, SonarQube, and Nexus

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

helm install my-jenkins jenkins/jenkins -n jenkins -f helm-values/jenkins-values.yaml
helm install sonarqube sonarqube/sonarqube -n sonarqube -f helm-values/sonarqube-values.yaml
helm install nexus sonatype/nexus-repository-manager -n nexus -f helm-values/nexus-values.yml
```

### 4. Retrieve Initial Credentials

```bash
# Jenkins admin password
kubectl get secret --namespace jenkins my-jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# Nexus initial admin password
kubectl exec -it <nexus-pod-name> -n nexus -- cat /nexus-data/admin.password
```

SonarQube's default login is `admin` / `admin` (you'll be prompted to change it on first login).

### 5. Create Jenkins Credentials

In **Manage Jenkins → Credentials → (global)**, add:

| Credential ID | Type | Used For |
| --- | --- | --- |
| `docker-cred` | Username with password | Pushing images from Kaniko to Docker Hub |
| `nexus-cred` | Username with password | Publishing artifacts to Nexus |
| `sonarqube-token` | Secret text | Authenticating with SonarQube |

### 6. Create the Multibranch Pipeline Job

- **New Item → Multibranch Pipeline**
- Add the GitHub repository as a branch source
- Build configuration: **by Jenkinsfile**, script path `Jenkinsfile` (or the correct path if nested)

### 7. Configure Nexus as a Maven Proxy (speeds up builds, reduces external dependency)

Instead of Maven hitting Maven Central directly on every build, point it at Nexus so previously-downloaded dependencies are served from a local cache.

1. In Nexus: **⚙️ Settings → Repository → Repositories → Create repository**
2. Choose **maven2 (proxy)**:
   - **Name:** `maven-central-proxy`
   - **Remote storage:** `https://repo1.maven.org/maven2/`
3. Create a second repository, **maven2 (group)**:
   - **Name:** `maven-public`
   - **Member repositories:** add `maven-central-proxy` (and `maven-releases` / `maven-snapshots` if present)
4. In the Jenkinsfile's Maven stages, mirror all traffic through the group repo via a generated `settings.xml`:

```xml
<mirror>
  <id>nexus</id>
  <mirrorOf>*</mirrorOf>
  <url>http://nexus-nexus-repository-manager.nexus.svc.cluster.local:8081/repository/maven-public/</url>
</mirror>
```

---

### 8. Run the Pipeline

Trigger a build and monitor each stage's console output. On first run, expect the image pulls (Kaniko, Syft/Grype installers, ZAP) to add a few extra minutes versus subsequent runs.

---

## 🔁 Disaster Recovery — Rebuilding From Scratch

Kind clusters (and the tools installed on them) are disposable — a machine restart, an accidental `kind delete cluster`, or a Docker Desktop reset can wipe everything. This section is the exact sequence to get back to a working state, based on real recoveries done while building this project.

### 1. Recreate the cluster (if needed)

```bash
kind create cluster --config kind-config.yaml
```

### 2. Recreate namespaces

```bash
kubectl create namespace jenkins
kubectl create namespace sonarqube
kubectl create namespace nexus
```

### 3. Reapply RBAC (before installing Jenkins)

```bash
kubectl apply -f jenkins-rbac.yaml
kubectl create serviceaccount jenkins -n jenkins
```

### 4. Reinstall Jenkins, SonarQube, and Nexus

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

helm install my-jenkins jenkins/jenkins -n jenkins -f helm-values/jenkins-values.yaml
helm install sonarqube sonarqube/sonarqube -n sonarqube -f helm-values/sonarqube-values.yaml
helm install nexus sonatype/nexus-repository-manager -n nexus -f helm-values/nexus-values.yml
```

Watch each one until it reaches `1/1 Running` **without repeated restarts** before moving on — SonarQube and Nexus can both take 5–15 minutes on first boot:

```bash
kubectl get pods -n jenkins -w
kubectl get pods -n sonarqube -w
kubectl get pods -n nexus -w
```

### 5. Recreate all Jenkins credentials

Everything below was lost on the last full reset and had to be recreated from scratch — **Jenkins Credentials are not preserved unless the Helm release keeps the same PersistentVolume**:

| Credential ID | Type | Source |
| --- | --- | --- |
| `docker-cred` | Username with password | Your Docker Hub account |
| `nexus-cred` | Username with password | Nexus admin (or a scoped deploy user) — get the initial password via `kubectl exec -it <nexus-pod> -n nexus -- cat /nexus-data/admin.password` |
| `sonarqube-token` | Secret text | Generate a new **User Token** in SonarQube: My Account → Security → Generate Tokens (any token from before a SonarQube reinstall is invalid) |

### 6. Reconfigure the Nexus Maven proxy

Repeat step 7 above (`maven-central-proxy` + `maven-public` group) — this is Nexus-side configuration and does **not** survive a Nexus reinstall.

### 7. Recreate the Multibranch Pipeline job

**New Item → Multibranch Pipeline** → point it at the GitHub repo → Build configuration: by Jenkinsfile.

### 8. Run a build and verify every stage

Watch the console output for all seven stages (Checkout → SonarQube → Nexus → Kaniko → Syft/Grype → Deploy → ZAP). Common first-run-after-recovery issues and their fixes are listed in the Troubleshooting table below — most have already been hit once and solved during this project's setup.

---

## 🔐 Jenkins Credentials Required

| Credential ID | Type | Used For |
| --- | --- | --- |
| **docker-cred** | Username/Password | Kaniko image push to Docker Hub |
| **nexus-cred** | Username/Password | Maven artifact publish to Nexus |
| **sonarqube-token** | Secret Text | SonarQube analysis authentication |

---

## 📂 Repository Structure

```
<repo-root>/
├── spring-boot-app/
│   ├── src/main
│   ├── Dockerfile
│   ├── pom.xml
│   └── README.md
├── spring-boot-app-manifests/
│   ├── deployment.yaml
│   └── service.yaml
├── Jenkinsfile
└── README.md
```

---

## 🧭 Pipeline Flow Diagram

```
Git Push
   │
   ▼
[Checkout] → [SonarQube Analysis] → [Publish to Nexus]
   │
   ▼
[Build & Push Image — Kaniko] → [SBOM + CVE Scan — Syft/Grype]
   │
   ▼
[Deploy to Kubernetes] → [DAST Scan — OWASP ZAP]
```

---

## 🛡️ Best Practices Applied

- ✅ Quality and security checks run **before** anything is published or built (SonarQube first).
- ✅ No plaintext credentials in the Jenkinsfile — everything goes through Jenkins Credentials.
- ✅ Rootless image builds via Kaniko instead of mounting a Docker socket.
- ✅ Every built image gets an SBOM and a CVE scan before deployment.
- ✅ The live application is scanned post-deployment, not just the static code/image.
- ✅ SBOM, vulnerability, and DAST reports are archived as Jenkins build artifacts for traceability across builds.

---

## 🚨 Troubleshooting Notes (from real issues hit while building this)

| Issue | Cause | Fix |
| --- | --- | --- |
| `No plugin found for prefix 'sonar'` | `sonar-maven-plugin` not resolvable by prefix | Use full plugin coordinates: `org.sonarsource.scanner.maven:sonar-maven-plugin:<version>:sonar` |
| `Not authorized` from SonarQube | Using deprecated `sonar.login` property, or a stale token after a SonarQube reinstall | Use `sonar.token` instead of `sonar.login`; regenerate the token after any SonarQube reinstall |
| SonarQube / Nexus pods stuck restarting | Default Helm chart probe timeouts too short for slow first-boot (Elasticsearch bootstrap, JVM warm-up) | Increase `initialDelaySeconds`, `timeoutSeconds`, and `failureThreshold` on liveness/readiness/startup probes |
| Nexus pod stuck `Pending` after reinstall | Old PVC stuck in `Terminating` blocking the new pod | `helm uninstall`, force-delete the namespace, recreate from scratch |
| `groovy.lang.MissingPropertyException: No such property: docker` | Docker Pipeline plugin not installed in Jenkins | Install the **Docker Pipeline** plugin under Manage Jenkins → Plugins |
| ZAP stage: `directory '/zap/wrk' is not mounted` | No writable volume provided to the ZAP container for its report output | Mount an `emptyDir` volume at `/zap/wrk` in the ZAP pod spec |
| `kubectl cp`/`kubectl logs` forbidden for the Jenkins ServiceAccount | RBAC `ClusterRole` missing `pods/log` and `pods/exec` | Add those resources/verbs to `jenkins-rbac.yaml` and reapply |
| `kubectl cp` fails with "cannot exec into a container in a completed pod" | Pod already reached `Succeeded`/`Failed` before the copy ran | Keep the container alive briefly after the task finishes (e.g. wrap the command with a trailing `sleep`) before copying and then deleting the pod |

---

## ✅ Summary

This pipeline automates the full CI/CD lifecycle for a Spring Boot application — from checkout through static analysis, artifact publishing, rootless image builds, SBOM/vulnerability scanning, Kubernetes deployment, and finally dynamic security testing against the live app — using **Maven, SonarQube, Nexus, Kaniko, Syft, Grype, Kubernetes, and OWASP ZAP**, all running self-hosted inside the cluster.
