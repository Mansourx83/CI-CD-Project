# 🛠️ Enterprise Multi-Application DevOps Platform

**A production-oriented DevOps platform demonstrating how multiple applications can be delivered through different CI platforms while sharing a centralized GitOps-based Continuous Delivery layer.**

The platform contains two applications:

* **Spring Boot Application** — GitHub + Jenkins CI *(complete)*
* **Bootstrap 5 Application** — GitLab + GitLab CI *(planned — Phase 3)*

Both applications are deployed to the same Kubernetes environment and, eventually, managed through a **centralized Argo CD GitOps layer**.

The goal is not to build two complex applications. The goal is to demonstrate a scalable DevOps platform where CI implementations can differ while the CD/GitOps platform remains centralized and consistent.

---

## 📌 Project Status at a Glance

| Phase | Description | Status |
|---|---|---|
| **1** | Jenkins CI/CD for Spring Boot (Helm-installed tooling) | ✅ Complete |
| **2** | GitOps deployment via Argo CD (Kustomize-installed) | ✅ Complete |
| **3** | Second application (Bootstrap 5) + GitLab CI | 🔵 Next |
| **3.5 / 3.6** | Centralize both apps into one GitOps repo + one shared Argo CD instance | 🔜 Planned |
| **4** | Argo CD App of Apps pattern | 🔜 Planned |
| **5** | Observability — Prometheus + Grafana (Kustomize) | 🔜 Planned |
| **6** | Production hardening (RBAC, network policies, secrets, DR validation) | 🔜 Planned |

> Everything above Phase 3 is **implemented and verified**. Phases 3–6 are the roadmap, not yet built — see the [Roadmap](#-roadmap) section for scope.

---

## 🔧 Deployment Methods Used

| Method | Components |
|---|---|
| **Helm** | Jenkins, SonarQube, Nexus |
| **Kustomize** | Argo CD |

---

## 🏗️ Architecture Overview (Current — Phase 1 & 2)

### Technology Stack

| Layer | Technology | Purpose | Installed Via |
|---|---|---|---|
| **Source Control** | GitHub | Hosts app code and pipeline definitions | — |
| **CI Server** | Jenkins + Kubernetes plugin | Orchestrates builds using ephemeral pods | Helm |
| **Build Tool** | Maven | Compiles, tests, packages the application | — |
| **Code Quality** | SonarQube | Static analysis & quality checks | Helm |
| **Artifact Repository** | Nexus Repository Manager | Maven artifact publishing | Helm |
| **Image Builder** | Kaniko | Rootless container builds on Kubernetes | — |
| **Container Registry** | Docker Hub | Stores built application images | — |
| **SBOM & Scanning** | Syft & Grype (custom pre-built image) | SBOM generation + CVE reporting | — |
| **DAST** | OWASP ZAP | Runtime security testing against the live app | — |
| **Orchestration** | Kubernetes (Kind) | Runtime for all services | — |
| **CD / GitOps** | Argo CD | Automatic cluster synchronization | Kustomize |

### Data Flow (Current)

```
Git Push (GitHub)
      │
      ▼
   Jenkins (Kubernetes agents)
      │
      ▼
[SonarQube Analysis] → [Build & Publish to Nexus] → [Kaniko Image Build]
      │
      ▼
[Syft SBOM + Grype CVE Scan]
      │
      ▼
[GitOps Update — commit new image tag to manifests repo]
      │
      ▼
   Argo CD (auto-sync)
      │
      ▼
   Kubernetes — Application Pods Updated
      │
      ▼
[OWASP ZAP DAST Scan against the live app]
```

---

## 🔄 Pipeline Stages (Jenkins — Current)

### 1. Checkout Code
Pulls the latest source from GitHub (`checkout scm`).

### 2. Static Code Analysis (SonarQube)
Runs `mvn sonar:sonar` against the in-cluster SonarQube instance. Runs **first**, before anything is published or built, so bad code never gets packaged.

### 3. Build and Deploy to Nexus
Publishes the Maven artifact to the in-cluster Nexus repository using a generated `settings.xml` with Nexus credentials.

> **Note on Nexus as a Maven proxy:** A `maven-central-proxy` + `maven-public` group repository has been configured in the Nexus UI to cache dependencies from Maven Central. The Jenkinsfile does **not yet** point Maven at this mirror via `settings.xml` — this wiring is a pending follow-up, not yet delivered.

### 4. Build & Push Image (Kaniko)
Builds the application's Docker image with Kaniko (no Docker daemon in the agent pod) and pushes it to Docker Hub, tagged with the Jenkins build number and `latest`.

### 5. Security Scan (Syft & Grype)
- **Syft** generates a full SBOM (`sbom.json`) for the built image.
- **Grype** scans the same image for known CVEs and exports a summary (`grype-report.json`).
- Both reports are archived as Jenkins build artifacts.
- **Current behavior:** findings are reported only — the pipeline does **not** fail on High/Critical CVEs yet (no `--fail-on` flag is set). This is intentional for now, same posture as the DAST stage below, and can be tightened later.

### 6. GitOps Update Manifests
Clones the `spring-boot-app-manifests-gitops` repository, updates the image tag in `deployment.yaml`, and pushes the change — only if something actually changed. Jenkins never touches the Kubernetes API directly for deployment; **Argo CD does that**.

### 7. DAST Scan (OWASP ZAP)
Runs an OWASP ZAP baseline scan against the **live, deployed** application. The ZAP pod mounts an `emptyDir` volume for its working directory, stays alive briefly after the scan so the HTML report can be copied out via `kubectl cp`, then is cleaned up. Findings do not fail the build — they're for review, not enforced as a hard gate (for now).

---

## ✅ Prerequisites

### Local Machine
- Kubernetes cluster: **Kind**
- `kubectl`, `helm`, `git` installed
- ~8GB RAM allocated to the cluster (comfortable minimum with Jenkins + SonarQube + Nexus + Argo CD running together)
- Docker Desktop (or equivalent) for building the custom `syft-grype` image

### Repositories
- **Main repo:** `Mansourx83/CI-CD-full-project` (GitHub)
  - `spring-boot-app/` — application source, `pom.xml`, `Dockerfile`
  - `Jenkinsfile` — Jenkins pipeline
  - `syft-grype.Dockerfile` — custom Syft+Grype image definition
  - `helm-values/` — Helm values for Jenkins, SonarQube, Nexus
  - `kustomize-manifests/argocd/` — Argo CD install (Kustomize)
  - `jenkins-rbac.yaml` — RBAC for the Jenkins ServiceAccount
  - `README.md`

- **GitOps repo:** `Mansourx83/spring-boot-app-manifests-gitops`
  - `deployment.yaml`
  - `service.yaml`

### Accounts & Credentials
- GitHub account with repo access (+ a token scoped to the GitOps repo for Jenkins)
- Docker Hub account
- SonarQube admin credentials (generated on first login)
- Nexus admin credentials (generated on first login)

---

## 🚀 Setup Guide

### 1. Create Namespaces

```bash
kubectl create namespace jenkins
kubectl create namespace sonarqube
kubectl create namespace nexus
kubectl create namespace argocd
```

### 2. Apply Jenkins RBAC

The Jenkins ServiceAccount needs more than the Kubernetes plugin's defaults — specifically `pods/log` and `pods/exec`, required by the DAST stage's `kubectl logs` and `kubectl cp` calls.

```bash
kubectl apply -f jenkins-rbac.yaml
```

### 3. Install Jenkins, SonarQube, and Nexus (Helm)

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

helm install my-jenkins jenkins/jenkins -n jenkins -f helm-values/jenkins-values.yaml
helm install sonarqube sonarqube/sonarqube -n sonarqube -f helm-values/sonarqube-values.yaml
helm install nexus sonatype/nexus-repository-manager -n nexus -f helm-values/nexus-values.yml
```

> ⚠️ SonarQube and Nexus both take several minutes to fully initialize on first boot. Default Helm chart probe timeouts are too aggressive for this — increase `initialDelaySeconds`, `timeoutSeconds`, and `failureThreshold` in the values files (already done in `helm-values/`), or you'll see repeated pod restarts before the app is actually ready.

### 4. Install Argo CD (Kustomize)

```bash
kubectl apply -k kustomize-manifests/argocd/
```

### 5. Retrieve Initial Credentials

```bash
# Jenkins
kubectl get secret --namespace jenkins my-jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# Nexus
kubectl exec -it <nexus-pod-name> -n nexus -- cat /nexus-data/admin.password

# Argo CD
kubectl get secret --namespace argocd argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

SonarQube's default login is `admin` / `admin` (you'll be prompted to change it on first login).

### 6. Create Jenkins Credentials

| Credential ID | Type | Used For |
|---|---|---|
| `docker-cred` | Username with password | Kaniko → Docker Hub push |
| `nexus-cred` | Username with password | Maven → Nexus publish |
| `sonarqube-token` | Secret text | SonarQube analysis auth |
| `github-cred` | Username / Personal Access Token | Pushing image-tag updates to the GitOps repo |

### 7. Configure Nexus Maven Proxy (UI-side setup)

1. In Nexus: **⚙️ Settings → Repository → Repositories → Create repository**
2. Create a **maven2 (proxy)** repo:
   - Name: `maven-central-proxy`
   - Remote storage: `https://repo1.maven.org/maven2/`
3. Create a **maven2 (group)** repo:
   - Name: `maven-public`
   - Members: `maven-central-proxy`

> This step is done, but the Jenkinsfile does not point Maven at it yet — see the note under Pipeline Stage 3 above.

### 8. Create the Jenkins Multibranch Pipeline Job

- **New Item → Multibranch Pipeline**
- Branch source: the GitHub repository above
- Build configuration: **by Jenkinsfile**

### 9. Create the Argo CD Application

Either via the UI (`https://localhost:8083` after port-forwarding `argocd-server`), or by applying:

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

**Current sync policy: Automatic** (with `prune` and `selfHeal` enabled) — Argo CD applies changes from the GitOps repo without manual intervention.

### 10. Run the Pipeline

Trigger a Jenkins build and watch each stage. On success, the GitOps repo gets a new commit, and Argo CD picks it up automatically — no manual `kubectl apply` needed anywhere in the flow.

---

## 📋 File Organization

### Main Repository

```
CI-CD-full-project/
├── spring-boot-app/
│   ├── src/main/java/...
│   ├── pom.xml
│   ├── Dockerfile
│   └── README.md
├── Jenkinsfile
├── syft-grype.Dockerfile
├── helm-values/
│   ├── jenkins-values.yaml
│   ├── sonarqube-values.yaml
│   └── nexus-values.yml
├── kustomize-manifests/
│   └── argocd/
│       └── kustomization.yaml
├── jenkins-rbac.yaml
└── README.md
```

### GitOps Repository

```
spring-boot-app-manifests-gitops/
├── deployment.yaml    # updated by Jenkins, applied by Argo CD
├── service.yaml
└── README.md
```

---

## 🔐 Security Practices Applied

- ✅ Quality checks run **before** anything is published or built (SonarQube first).
- ✅ Rootless image builds via Kaniko — no Docker socket mounted.
- ✅ Every image gets an SBOM (Syft) and a CVE report (Grype), archived per build.
- ✅ No plaintext credentials anywhere — everything goes through Jenkins Credentials.
- ✅ Jenkins has **no direct Kubernetes deploy access** — it only writes to Git; Argo CD is the sole deployer (GitOps separation of concerns).
- ✅ RBAC scoped to what the Jenkins ServiceAccount actually needs (`pods/log`, `pods/exec` added deliberately for the DAST stage, not broad cluster-admin).
- ✅ The live application is scanned post-deployment (DAST), not just the static code/image.

**Not yet enforced (documented as future work, not overclaimed):**
- Grype does not currently fail the build on High/Critical CVEs.
- ZAP findings do not currently fail the build.
- Nexus Maven proxy is configured but not wired into the Jenkinsfile yet.

---

## 🔄 Disaster Recovery

Kind clusters (and everything installed on them) are disposable — a machine restart, an accidental `kind delete cluster`, or a Docker Desktop reset wipes everything. This is the exact recovery sequence, based on real recoveries done while building this project.

```bash
# 1. Recreate the cluster (if needed)
kind create cluster --config kind-config.yaml

# 2. Recreate namespaces
kubectl create namespace jenkins sonarqube nexus argocd

# 3. Reapply RBAC (before installing Jenkins)
kubectl apply -f jenkins-rbac.yaml

# 4. Reinstall Helm-based components
helm install my-jenkins jenkins/jenkins -n jenkins -f helm-values/jenkins-values.yaml
helm install sonarqube sonarqube/sonarqube -n sonarqube -f helm-values/sonarqube-values.yaml
helm install nexus sonatype/nexus-repository-manager -n nexus -f helm-values/nexus-values.yml

# 5. Reapply Kustomize-based components
kubectl apply -k kustomize-manifests/argocd/

# 6. Recreate credentials (see Setup Guide step 6)
# 7. Reconfigure the Nexus Maven proxy (see Setup Guide step 7)
# 8. Recreate the Jenkins Multibranch Pipeline job
# 9. Recreate the Argo CD Application (see Setup Guide step 9)
```

**Does NOT survive a full reset:**
- Jenkins Credentials (`docker-cred`, `nexus-cred`, `sonarqube-token`, `github-cred`)
- Nexus Maven proxy configuration (UI-side setup)
- SonarQube tokens (regenerate via My Account → Security after any SonarQube reinstall)

**DOES survive, if the same Helm release keeps its PersistentVolume:**
- Jenkins job definitions and build history
- Argo CD Application definitions (stored as Kubernetes custom resources, protected by the cluster's own `etcd`)

---

## 🚨 Troubleshooting Notes (from real issues hit while building this)

| Issue | Cause | Fix |
|---|---|---|
| `No plugin found for prefix 'sonar'` | `sonar-maven-plugin` not resolvable by prefix | Use full plugin coordinates or add the plugin to `pom.xml` |
| SonarQube: `Not authorized` | Deprecated `sonar.login` property, or a stale token after a reinstall | Use `sonar.token`; regenerate the token after any SonarQube reinstall |
| SonarQube / Nexus pods stuck restarting | Default Helm probe timeouts too short for slow first boot | Increase `initialDelaySeconds`, `timeoutSeconds`, `failureThreshold` |
| Nexus pod stuck `Pending` after reinstall | Old PVC stuck `Terminating`, blocking the new pod | `helm uninstall`, force-delete the namespace, recreate |
| `groovy.lang.MissingPropertyException: No such property: docker` | Docker Pipeline plugin not installed | Install **Docker Pipeline** under Manage Jenkins → Plugins |
| ZAP stage: `directory '/zap/wrk' is not mounted` | No writable volume for the ZAP container's report output | Mount an `emptyDir` volume at `/zap/wrk` |
| `kubectl cp`/`kubectl logs` forbidden for Jenkins | RBAC `ClusterRole` missing `pods/log` / `pods/exec` | Add both to `jenkins-rbac.yaml` and reapply |
| `kubectl cp` fails: "cannot exec into a container in a completed pod" | Pod already reached `Succeeded`/`Failed` before the copy ran | Keep the container alive briefly (trailing `sleep`) before copying, then delete the pod |

---

## 🗺️ Roadmap

### Phase 3 — Second Application + GitLab CI 🔵 Next

- Build a simple Bootstrap 5 (HTML/CSS/JS) application
- Create a GitLab project and repository
- Install GitLab Runner on the cluster
- Write `.gitlab-ci.yml` mirroring the Jenkinsfile's stage logic (build → image → SBOM/CVE scan → GitOps update)
- Validate the full flow end-to-end, including the existing GitOps repo and Argo CD

### Phase 3.5 / 3.6 — Centralization 🔜 Planned

- Refactor the GitOps repo to manage multiple apps (`apps/spring-boot/`, `apps/bootstrap/`)
- Consolidate to a single, shared Argo CD instance managing both applications

### Phase 4 — App of Apps 🔜 Planned

- Introduce Argo CD's App of Apps pattern: one root Application managing the Spring Boot and Bootstrap Applications as children
- Makes adding future applications a config change, not an architecture change

### Phase 5 — Observability 🔜 Planned

- Deploy Prometheus + Grafana via Kustomize (consistent with how Argo CD is installed)
- Dashboards: CI/CD health (build duration, success rate), application performance (latency, error rate), infrastructure (CPU/memory, pod restarts)

### Phase 6 — Production Hardening 🔜 Planned

- Least-privilege RBAC review across all ServiceAccounts
- Secrets management beyond plain Kubernetes Secrets
- Network policies
- Resource requests/limits and health probes reviewed for every workload
- Image security policies (e.g., enforcing the Grype/ZAP gates that are currently report-only)
- Backup/restore validation beyond the disaster-recovery steps already documented above

---

## 📚 References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Argo CD — GitOps](https://argo-cd.readthedocs.io/)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Kaniko](https://github.com/GoogleContainerTools/kaniko)
- [Syft](https://github.com/anchore/syft)
- [Grype](https://github.com/anchore/grype)
- [OWASP ZAP](https://www.zaproxy.org/)
- [SonarQube](https://www.sonarqube.org/)
- [Nexus Repository Manager](https://www.sonatype.com/products/repository-oss)
- [Kustomize](https://kustomize.io/)

---

**Project Status:** Phases 1–2 complete and verified · Phase 3 next · Phases 4–6 planned
