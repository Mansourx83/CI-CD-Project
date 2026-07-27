pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: maven
    image: maven:3.8.5-openjdk-17
    command:
    - sleep
    - "999999"
    tty: true
  - name: docker
    image: docker:27.1
    command:
    - cat
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: syft-grype
    image: alpine:3.20
    command:
    - /bin/sh
    - -c
    - |
      apk add --no-cache curl
      curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
      curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
      while true; do sleep 30; done
    tty: true
  - name: kubectl
    image: alpine:3.20
    command:
    - /bin/sh
    - -c
    - |
      apk add --no-cache kubectl
      while true; do sleep 30; done
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }
    environment {
        SONAR_URL = "http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"
    }
    stages {
        stage('Build with Maven') {
            steps {
                container('maven') {
                    dir('spring-boot-app') {
                        sh '''
                        echo "Building Maven project..."
                        mvn clean package -DskipTests
                        '''
                    }
                }
            }
        }
        stage('Publish to Nexus') {
            steps {
                container('maven') {
                    dir('spring-boot-app') {
                        withCredentials([usernamePassword(credentialsId: 'nexus-cred', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USER')]) {
                            sh '''
                            echo "Publishing artifacts to Nexus..."
                            mvn deploy -DskipTests \
                              -DaltDeploymentRepository=nexus-releases::default::http://nexus-nexus-repository-manager.nexus.svc.cluster.local:8081/repository/maven-releases/ \
                              -Dusername=${NEXUS_USER} -Dpassword=${NEXUS_PASSWORD}
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
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_AUTH_TOKEN')]) {
                            sh '''
                            echo "=== Running SonarQube analysis ==="
                            mvn org.sonarsource.scanner.maven:sonar-maven-plugin:3.9.1.2184:sonar \
                              -Dsonar.token=$SONAR_AUTH_TOKEN \
                              -Dsonar.host.url=${SONAR_URL}
                            '''
                        }
                    }
                }
            }
        }
        stage('Docker Build and Push') {
            steps {
                container('docker') {
                    script {
                        docker.withRegistry('', 'docker-cred') {
                            dir('spring-boot-app') {
                                def customImage = docker.build(
                                    "mansour19/my-app:${env.BUILD_NUMBER}"
                                )
                                customImage.push()
                                customImage.push('latest')
                            }
                        }
                    }
                }
            }
        }
        stage('Security Scan (Syft & Grype)') {
            steps {
                script {
                    def imageName = "mansour19/my-app:${env.BUILD_NUMBER}"
                    
                    container('syft-grype') {
                        echo "=== Generating visual table for console ==="
                        sh "syft ${imageName} -o table"
                        
                        echo "=== Exporting SBOM artifact file ==="
                        sh "syft ${imageName} -o spdx-json=sbom-report.json"
                        
                        echo "=== Scanning image for vulnerabilities with Grype ==="
                        sh "grype sbom:sbom-report.json"
                    }
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'spring-boot-app/sbom-report.json', fingerprint: true
                }
            }
        }
        stage('Deploy to K8s') {
            steps {
                container('kubectl') {
                    sh """
                    echo "Updating Kubernetes deployment..."
                    kubectl set image deployment/spring-boot-app \\
                    spring-boot-app=mansour19/my-app:${env.BUILD_NUMBER} \\
                    -n default
                    echo "Waiting for rollout..."
                    kubectl rollout status deployment/spring-boot-app \\
                    -n default
                    echo "Deployment completed successfully"
                    """
                }
            }
        }
    }
}
