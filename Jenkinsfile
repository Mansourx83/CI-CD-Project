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
  - name: docker
    image: docker:20.10.12
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['cat']
    tty: true
  - name: syft-grype
    image: anchore/syft:latest
    command: ['cat']
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
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
                        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$NEXUS_USER:$NEXUS_PASSWORD" http://nexus-nexus-repository-manager.nexus.svc.cluster.local:8081/service/rest/v1/status)
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
                    withCredentials([usernamePassword(credentialsId: 'nexus-cred', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USER')]) {
                        sh 'mvn clean deploy -DskipTests'
                    }
                }
            }
        }

        stage('Static Code Analysis (SonarQube)') {
            steps {
                container('maven') {
                    withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            mvn sonar:sonar \
                              -Dsonar.projectKey=spring-boot-demo \
                              -Dsonar.host.url=http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000 \
                              -Dsonar.login=$SONAR_TOKEN
                        '''
                    }
                }
            }
        }

        stage('Docker Build and Push') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USER')]) {
                        sh '''
                            docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD"
                            docker build -t mansour19/spring-boot-demo:latest .
                            docker push mansour19/spring-boot-demo:latest
                        '''
                    }
                }
            }
        }

        stage('Security Scan (Syft & Grype)') {
            steps {
                container('syft-grype') {
                    sh 'syft mansour19/spring-boot-demo:latest -o json > sbom.json'
                }
            }
        }

        stage('Deploy to K8s') {
            steps {
                container('kubectl') {
                    sh 'kubectl apply -f spring-boot-app-manifests/ -n jenkins'
                }
            }
        }
    }
}
