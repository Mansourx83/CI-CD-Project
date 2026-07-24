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

        stage('Static Code Analysis (SonarQube)') {
            steps {
                container('maven') {
                    dir('spring-boot-app') {
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_AUTH_TOKEN')]) {
                            sh '''
                            echo "Running SonarQube analysis..."
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

        stage('Verify K8s Connection') {
            steps {
                container('kubectl') {
                    sh '''
                    echo "Checking Kubernetes connection..."
                    kubectl cluster-info

                    echo "Checking nodes..."
                    kubectl get nodes

                    echo "Checking application deployment..."
                    kubectl get deployment spring-boot-app -n default
                    '''
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
