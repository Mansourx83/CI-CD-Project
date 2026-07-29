# 🛠️ Jenkins CI/CD Pipeline for Java Applications using Maven, SonarQube, Helm, Argo CD & Kubernetes

**An end-to-end Jenkins pipeline that builds, tests, analyzes, packages, and deploys a Java application to Kubernetes — with GitOps-based promotion to production via Argo CD.**

---

## 📌 Project Overview

This project automates the complete lifecycle of a Java application, from source code checkout to production deployment, using a modern cloud-native toolchain.

### What This Delivers

✅ Automated build with Maven
✅ Unit testing (JUnit + Mockito)
✅ Static code analysis (SonarQube)
✅ Artifact packaging (JAR)
✅ Test-environment deployment via Helm
✅ User acceptance testing (Selenium)
✅ GitOps production promotion via Argo CD

### Application Packaging

- Java application built and packaged into a JAR file using Maven
- Deployed to Kubernetes using Helm charts, tracked and synced by Argo CD

---

## 🏗️ Architecture & Technology Stack

| Component | Technology | Purpose |
| --- | --- | --- |
| **Source Control** | Git | Hosts application code and Helm charts |
| **CI/CD Server** | Jenkins | Orchestrates the pipeline |
| **Build Tool** | Maven | Compiles, tests, and packages the application |
| **Testing** | JUnit + Mockito | Unit testing framework |
| **Code Quality** | SonarQube | Static analysis and code quality gating |
| **UAT Framework** | Selenium | User acceptance testing on deployed builds |
| **Package Manager** | Helm | Templated Kubernetes deployments |
| **GitOps Engine** | Argo CD | Declarative, Git-driven production promotion |
| **Orchestration** | Kubernetes | Runtime environment for test and production |

---

## ✅ Prerequisites

- Java application code hosted on a Git repository
- A running Jenkins server
- A Kubernetes cluster
- Helm package manager installed
- Argo CD installed on the cluster

---

## 🔌 Required Jenkins Plugins

| Plugin | Purpose |
| --- | --- |
| **Git Plugin** | Checks out source code from the Git repository |
| **Maven Integration Plugin** | Builds and packages the Java application |
| **Pipeline Plugin** | Enables Jenkinsfile-based pipeline definitions |
| **Kubernetes Continuous Deploy Plugin** | Deploys to Kubernetes/test environments via Helm |

---

## 🔄 Jenkins Pipeline Stages

### Complete Pipeline Flow

#### **Stage 1: Checkout Source Code**
- Uses the **Git plugin** to pull the latest code from the configured repository.

#### **Stage 2: Build the Application**
- Uses the **Maven Integration plugin** to compile the Java application.

#### **Stage 3: Run Unit Tests**
- Executes unit tests using **JUnit** and **Mockito**.
- Fails the pipeline early if tests do not pass.

#### **Stage 4: Static Code Analysis (SonarQube)**
- Runs a SonarQube scan to evaluate code quality, bugs, code smells, and vulnerabilities.
- Uses the **SonarQube plugin** integrated with Jenkins.

#### **Stage 5: Package the Application**
- Packages the compiled code into a deployable **JAR** file using Maven.

#### **Stage 6: Deploy to Test Environment (Helm)**
- Uses the **Kubernetes Continuous Deploy plugin** to deploy the packaged application to a test environment using a Helm chart.

#### **Stage 7: User Acceptance Testing**
- Runs automated UAT scripts using **Selenium** against the deployed test environment.

#### **Stage 8: Promote to Production (Argo CD)**
- Updates the Git repository tracked by Argo CD (Helm values/manifests).
- Argo CD detects the change and syncs the production environment automatically (GitOps).

---

## 🚀 Setup Guide

### 1. Install Jenkins Plugins
Install the plugins listed in the [Required Jenkins Plugins](#-required-jenkins-plugins) table via **Manage Jenkins → Plugins**.

### 2. Create the Jenkins Pipeline
- Create a new **Pipeline** job in Jenkins.
- Configure it with the Git repository URL of the Java application.
- Add a `Jenkinsfile` to the repository root defining the stages above.

### 3. Configure Pipeline Stages
| Stage | Tooling Used |
| --- | --- |
| Checkout | Git plugin |
| Build | Maven Integration plugin |
| Unit Tests | JUnit + Mockito |
| Code Quality | SonarQube plugin |
| Packaging | Maven Integration plugin |
| Test Deploy | Kubernetes Continuous Deploy plugin + Helm |
| UAT | Selenium |
| Production Promotion | Argo CD |

### 4. Set Up Argo CD
1. Install Argo CD on the Kubernetes cluster.
2. Create a Git repository (or reuse an existing one) for Argo CD to track — containing the Helm chart and Kubernetes manifests.
3. Build a Helm chart for the Java application, including:
   - Kubernetes manifests (Deployment, Service, etc.)
   - `values.yaml` for environment-specific configuration
4. Commit the Helm chart to the Argo CD–tracked repository.
5. Create an Argo CD Application resource pointing to that repository and chart path.

### 5. Integrate Jenkins with Argo CD
1. Generate an Argo CD API token.
2. Store the token in **Jenkins Credentials**.
3. Add a pipeline stage that updates the image tag/values in the Argo CD–tracked Git repo (triggering an automatic sync), or calls the Argo CD API/CLI directly to sync the application.

### 6. Run the Pipeline
1. Trigger the Jenkins pipeline (manually or via webhook on commit).
2. Monitor each stage in the Jenkins console output.
3. Resolve any failures (build errors, failed tests, quality gate failures, deployment issues) before re-running.

---

## 🔐 Jenkins Credentials Required

| Credential ID (suggested) | Type | Used For |
| --- | --- | --- |
| **git-cred** | SSH Key / Username-Password | Git checkout and pushing Helm chart updates |
| **sonarqube-token** | Secret Text | SonarQube authentication |
| **kubeconfig-cred** | Kubeconfig / Secret File | Deploying to the test environment via Helm |
| **argocd-token** | Secret Text | Argo CD API authentication for production promotion |

---

## 📂 Suggested Repository Structure

```
Jenkins-full-project/
├── src/                     # Java application source code
├── pom.xml                  # Maven build configuration
├── Jenkinsfile               # Pipeline definition
├── helm-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       └── service.yaml
└── README.md
```

---

## 🧭 Pipeline Flow Diagram

```
Git Push
   │
   ▼
[Checkout] → [Maven Build] → [Unit Tests] → [SonarQube Analysis]
   │
   ▼
[Package JAR]
   │
   ▼
[Deploy to Test via Helm] → [Selenium UAT]
   │
   ▼
[Update Argo CD Git Repo] → [Argo CD Auto-Sync] → [Production Deployment]
```

---

## 🛡️ Best Practices

- ✅ Keep quality gates (SonarQube) blocking for critical/blocker issues before packaging.
- ✅ Use separate Helm `values-test.yaml` and `values-prod.yaml` files for environment-specific configuration.
- ✅ Never store Argo CD tokens or kubeconfigs in plaintext — always use Jenkins Credentials.
- ✅ Let Argo CD manage production state exclusively (GitOps) — avoid manual `kubectl apply` to production.
- ✅ Version JAR artifacts and Helm chart versions together to keep traceability between builds and deployments.

---

## 🚨 Troubleshooting Tips

| Issue | Likely Cause | Fix |
| --- | --- | --- |
| SonarQube stage fails with plugin not found | `sonar-maven-plugin` missing from `pom.xml` | Add the plugin under `<build><plugins>` |
| Helm deploy fails in test environment | Invalid or missing `values.yaml` | Validate chart with `helm lint` and `helm template` |
| Argo CD not syncing after Git update | Auto-sync disabled or wrong repo path | Verify Argo CD Application config and enable auto-sync |
| UAT stage cannot reach test environment | Service not exposed or DNS not resolving | Check Kubernetes Service and Ingress configuration |
| Jenkins fails to authenticate to Argo CD | Expired or invalid API token | Regenerate token and update Jenkins credential |

---

## ✅ Summary

This end-to-end Jenkins pipeline automates the full CI/CD lifecycle for a Java application — from code checkout through build, testing, code quality analysis, and packaging, to test deployment, user acceptance testing, and GitOps-driven production promotion — using **Maven, SonarQube, Helm, Argo CD, and Kubernetes**.
