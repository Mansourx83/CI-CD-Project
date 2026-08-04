pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins
spec:
  serviceAccountName: jenkins
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest

  - name: maven
    image: maven:3.8.4-openjdk-17
    command: ['cat']
    tty: true

  - name: kaniko
    image: gcr.io/kaniko-project/executor:v1.23.2-debug
    command: ['sleep']
    args: ['infinity']
    tty: true
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker

  - name: kubectl
    image: alpine/k8s:1.29.2
    command: ['sh', '-c', 'while true; do sleep 30; done']
    tty: true

  - name: syft-grype
    image: mansour19/syft-grype:latest
    command: ['cat']
    tty: true

  volumes:
  - name: docker-config
    emptyDir: {}
'''
        }
    }

    environment {
        IMAGE_NAME  = 'mansour19/spring-boot-demo'
        IMAGE_TAG   = "${env.BUILD_NUMBER}"
        SONAR_HOST  = 'http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000'
        NEXUS_URL   = 'http://nexus-nexus-repository-manager.nexus.svc.cluster.local:8081'
        APP_URL     = 'http://spring-boot-app-service.jenkins.svc.cluster.local:80'
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        // Check code quality/security first, before building any artifact or image
        stage('Static Code Analysis (SonarQube)') {
            steps {
                container('maven') {
                    dir('spring-boot-app') {
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                            sh """
                                mvn sonar:sonar \
                                  -Dsonar.projectKey=spring-boot-demo \
                                  -Dsonar.host.url=${SONAR_HOST} \
                                  -Dsonar.login=\$SONAR_TOKEN
                            """
                        }
                    }
                }
            }
        }

        // Once the code passes quality checks, publish the artifact to Nexus
        // (if the credentials are wrong, this stage fails directly — no need for a separate check)
        stage('Build and Deploy to Nexus') {
            steps {
                container('maven') {
                    dir('spring-boot-app') {
                        withCredentials([usernamePassword(credentialsId: 'nexus-cred', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USER')]) {
                            sh '''
                                cat > nexus-settings.xml <<EOF
<settings>
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>${NEXUS_USER}</username>
      <password>${NEXUS_PASSWORD}</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>${NEXUS_USER}</username>
      <password>${NEXUS_PASSWORD}</password>
    </server>
  </servers>
</settings>
EOF
                                mvn -s nexus-settings.xml clean deploy -DskipTests
                            '''
                        }
                    }
                }
            }
        }

        // Build the Docker image now that the artifact is ready
        stage('Build & Push Image (Kaniko)') {
            steps {
                container('kaniko') {
                    withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USER')]) {
                        sh '''
                            AUTH=$(echo -n "$DOCKER_USER:$DOCKER_PASSWORD" | base64 | tr -d '\\n')
                            cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$AUTH"
    }
  }
}
EOF
                            /kaniko/executor \
                              --context "$(pwd)/spring-boot-app" \
                              --dockerfile "$(pwd)/spring-boot-app/Dockerfile" \
                              --destination "${IMAGE_NAME}:${IMAGE_TAG}" \
                              --destination "${IMAGE_NAME}:latest" \
                              --cache=true
                        '''
                    }
                }
            }
        }

        // Scan the image itself right after it's built
        stage('Security Scan (Syft & Grype)') {
            steps {
                container('syft-grype') {
                    sh '''
                        syft "${IMAGE_NAME}:${IMAGE_TAG}" \
                          --scope all-layers \
                          -o json > sbom.json

                        echo "===== Syft SBOM ====="
                        syft "${IMAGE_NAME}:${IMAGE_TAG}" \
                          --scope all-layers \
                          -o table

                        grype "${IMAGE_NAME}:${IMAGE_TAG}" -o json > grype-report.json

                        echo "===== Grype Summary ====="
                        grype "${IMAGE_NAME}:${IMAGE_TAG}" -o table
                    '''
                }
            }
        }

        // Deploy the application to the cluster
        stage('Deploy to K8s') {
            steps {
                container('kubectl') {
                    sh '''
                        echo "======================================"
                        echo "Starting Deployment..."
                        echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
                        echo "Namespace: jenkins"
                        echo "======================================"

                        if kubectl get deployment spring-boot-app -n jenkins > /dev/null 2>&1; then
                            echo "Deployment EXISTS — Updating image..."
                            kubectl set image deployment/spring-boot-app \
                              spring-boot-app="${IMAGE_NAME}:${IMAGE_TAG}" \
                              -n jenkins

                            echo "Waiting for rollout to complete..."
                            kubectl rollout status deployment/spring-boot-app \
                              -n jenkins --timeout=120s

                            echo "======================================"
                            echo "Successfully updated deployment!"
                            echo "Image deployed: ${IMAGE_NAME}:${IMAGE_TAG}"
                            echo "======================================"
                        else
                            echo "Deployment NOT FOUND — Applying manifests..."
                            kubectl apply -f spring-boot-app-manifests/deployment.yaml -n jenkins
                            kubectl apply -f spring-boot-app-manifests/service.yaml -n jenkins

                            echo "Waiting for rollout to complete..."
                            kubectl rollout status deployment/spring-boot-app \
                              -n jenkins --timeout=120s

                            echo "======================================"
                            echo "Successfully created deployment!"
                            echo "Image deployed: ${IMAGE_NAME}:${IMAGE_TAG}"
                            echo "======================================"
                        fi

                        echo "--- Current Deployment Status ---"
                        kubectl get deployment spring-boot-app -n jenkins
                        kubectl get pods -n jenkins -l app=spring-boot-demo
                    '''
                }
            }
        }

        // Final step: scan the application itself while it's actually running in the cluster
        stage('DAST Scan (OWASP ZAP)') {
            steps {
                container('kubectl') {
                    sh '''
                        echo "Running OWASP ZAP baseline scan against ${APP_URL} ..."

                        # Remove any leftover pod with the same name from a previous attempt
                        kubectl delete pod zap-scan-${BUILD_NUMBER} -n jenkins --ignore-not-found=true

                        # ZAP needs a real mounted working directory (/zap/wrk) to write the report into.
                        # We also keep the container alive after the scan (via a wrapper shell command)
                        # so that "kubectl cp" (which uses exec) can still reach it — exec does not work
                        # once a Never-restart pod has already completed.
                        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: zap-scan-${BUILD_NUMBER}
  namespace: jenkins
spec:
  restartPolicy: Never
  containers:
  - name: zap
    image: ghcr.io/zaproxy/zaproxy:stable
    command: ["/bin/bash", "-c"]
    args:
      - "zap-baseline.py -t ${APP_URL} -r zap-report.html; echo DONE > /zap/wrk/scan-complete; sleep 300"
    volumeMounts:
    - name: zap-wrk
      mountPath: /zap/wrk
  volumes:
  - name: zap-wrk
    emptyDir: {}
EOF

                        echo "Waiting for the ZAP scan itself to finish (up to 5 minutes)..."

                        # Poll for the marker file that signals zap-baseline.py has actually completed
                        # (the pod stays Running because of the trailing "sleep 300")
                        for i in $(seq 1 30); do
                            MARKER=$(kubectl exec zap-scan-${BUILD_NUMBER} -n jenkins -- test -f /zap/wrk/scan-complete && echo yes || echo no)
                            echo "Scan complete marker present: $MARKER"
                            if [ "$MARKER" = "yes" ]; then
                                break
                            fi
                            sleep 10
                        done

                        echo "===== ZAP scan output ====="
                        kubectl logs zap-scan-${BUILD_NUMBER} -n jenkins || true

                        echo "Copying ZAP report out of the pod..."
                        kubectl cp jenkins/zap-scan-${BUILD_NUMBER}:/zap/wrk/zap-report.html ./zap-report.html -c zap || true

                        kubectl delete pod zap-scan-${BUILD_NUMBER} -n jenkins --ignore-not-found=true

                        echo "ZAP scan finished (findings, if any, do not fail the build)."
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'sbom.json, grype-report.json, zap-report.html', allowEmptyArchive: true
        }
        success {
            echo "Pipeline succeeded: ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed — check the logs above."
        }
    }
}
