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
    image: alpine:3.19
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

        stage('Verify Nexus Credentials') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-cred', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USER')]) {
                    sh '''
                        echo "Testing connection to Nexus..."
                        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$NEXUS_USER:$NEXUS_PASSWORD" "$NEXUS_URL/service/rest/v1/status")
                        echo "Nexus Status Code: $HTTP_STATUS"
                        if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 400 ] || [ "$HTTP_STATUS" -eq 404 ]; then
                            echo "Authentication Successful! Credentials are valid."
                        else
                            echo "Authentication Failed or Nexus is unreachable. Status code: $HTTP_STATUS"
                            exit 1
                        fi
                    '''
                }
            }
        }

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

        stage('Security Scan (Syft & Grype)') {
            steps {
                container('syft-grype') {
                    sh '''
                        apk add --no-cache curl bash ca-certificates

                        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
                          | sh -s -- -b /usr/local/bin

                        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
                          | sh -s -- -b /usr/local/bin

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
    }

    post {
        always {
            archiveArtifacts artifacts: 'sbom.json, grype-report.json', allowEmptyArchive: true
        }
        success {
            echo "Pipeline succeeded: ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed — check the logs above."
        }
    }
}
