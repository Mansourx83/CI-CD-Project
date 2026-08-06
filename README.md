# 🚀 Enterprise Spring Boot DevSecOps Platform

A production-oriented DevSecOps platform demonstrating a complete CI/CD and GitOps workflow for deploying a Spring Boot application on Kubernetes.

The project integrates Continuous Integration, DevSecOps, and GitOps using Jenkins, SonarQube, Nexus, Kaniko, Syft, Grype, and Argo CD.

---

# 🎯 Project Goal

The goal of this project is to demonstrate how a modern enterprise CI/CD platform can deliver applications to Kubernetes using GitOps principles.

Instead of deploying directly from Jenkins, the pipeline updates a dedicated GitOps repository. Argo CD continuously watches this repository and synchronizes the Kubernetes cluster automatically.

This separation keeps Continuous Integration independent from Continuous Delivery while following GitOps best practices.

---

# 🏗 Architecture

```
                        GitHub
                           │
                           ▼
                  Jenkins Pipeline
                           │
     ┌──────────────┬──────────────┬
     ▼              ▼              ▼
 SonarQube       Maven Build      Nexus
                           │
                           ▼
                       Kaniko
                           │
                           ▼
                      Docker Hub
                           │
                           ▼
                 Syft + Grype Scan
                           │
                           ▼
            GitOps Manifests Repository
                           │
                           ▼
                       Argo CD
                           │
                           ▼
                    Kubernetes Cluster
                           │
                           ▼
                  Spring Boot Application
                           │
                           ▼
                    OWASP ZAP Scan
```

---

# ⚙ Technology Stack

| Category | Technology |
|----------|------------|
| Source Control | GitHub |
| CI | Jenkins |
| Build Tool | Maven |
| Code Quality | SonarQube |
| Artifact Repository | Nexus Repository |
| Image Builder | Kaniko |
| Container Registry | Docker Hub |
| SBOM | Syft |
| Vulnerability Scanner | Grype |
| GitOps | Argo CD |
| Container Platform | Kubernetes (Kind) |
| Security Testing | OWASP ZAP |

---

# ✅ Implemented Features

## Jenkins Platform

- Jenkins deployed on Kubernetes using Helm
- Dynamic Kubernetes Agents
- Multi-container Jenkins Pods
- Multibranch Pipeline
- Jenkins Credentials Management
- Kubernetes RBAC Configuration

---

## CI Pipeline

- Source Code Checkout
- Static Code Analysis using SonarQube
- Maven Build & Package
- Artifact Publishing to Nexus
- Docker Image Build using Kaniko
- Push Image to Docker Hub

---

## DevSecOps

- Software Bill of Materials (SBOM) Generation using Syft
- Container Vulnerability Scanning using Grype
- Dynamic Application Security Testing using OWASP ZAP
- Security Reports archived in Jenkins

---

## GitOps Platform

- Argo CD installed using Kustomize
- Dedicated GitOps Repository
- Automatic Image Tag Update
- Automatic Argo CD Synchronization
- Continuous Deployment to Kubernetes
- Git-based Deployment Workflow
- No direct deployment from Jenkins to Kubernetes

---

# 🔄 Pipeline Workflow

```
Git Push
    │
    ▼
Jenkins
    │
    ▼
Checkout
    │
    ▼
SonarQube Analysis
    │
    ▼
Maven Build
    │
    ▼
Publish Artifact to Nexus
    │
    ▼
Build Container Image (Kaniko)
    │
    ▼
Push Image to Docker Hub
    │
    ▼
Generate SBOM (Syft)
    │
    ▼
Scan Image (Grype)
    │
    ▼
Update GitOps Repository
    │
    ▼
Argo CD Auto Sync
    │
    ▼
Deploy to Kubernetes
    │
    ▼
OWASP ZAP Scan
```

---

# 📂 Repository Structure

```
.
├── spring-boot-app/
├── Jenkinsfile
├── helm-values/
│   ├── jenkins-values.yaml
│   ├── sonarqube-values.yaml
│   └── nexus-values.yaml
├── kustomize-manifests/
│   └── argocd/
├── syft-grype.Dockerfile
├── jenkins-rbac.yaml
└── README.md
```

---

# 📦 Related Repositories

| Repository | Purpose |
|------------|---------|
| Spring Boot Application | Application source code |
| GitOps Repository | Kubernetes deployment manifests managed by Argo CD |

---

# 🔐 Security Practices

- Static code analysis before building
- Rootless container image builds using Kaniko
- SBOM generation for every image
- Container vulnerability scanning
- Runtime DAST scanning using OWASP ZAP
- GitOps deployment model
- Jenkins credentials management
- Kubernetes RBAC
- Separation between CI and CD

---

# 🎯 Key Highlights

- Enterprise-style Jenkins Pipeline
- GitOps-based Deployment Strategy
- Centralized Continuous Delivery using Argo CD
- Dedicated GitOps Repository
- DevSecOps integrated into every build
- Kubernetes-native architecture
- Fully automated deployment pipeline

---

# 🚀 Current Status

✅ Jenkins CI Platform

✅ DevSecOps Pipeline

✅ GitOps Workflow

✅ Centralized Argo CD Deployment

✅ Spring Boot Deployment on Kubernetes

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

