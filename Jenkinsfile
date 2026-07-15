pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:

  containers:

  - name: maven
    image: maven:3.9.9-eclipse-temurin-17
    command:
      - cat
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
    image: bitnami/kubectl:1.31
    command:
      - cat
    tty: true

  volumes:
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
'''
        }
    }

    stages {

        stage('Build with Maven') {
            steps {
                container('maven') {
                    dir('spring-boot-app') {
                        sh 'mvn clean package -DskipTests'
                    }
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                container('docker') {
                    script {
                        docker.withRegistry('', 'docker-cred') {

                            dir('spring-boot-app') {

                                def app = docker.build("mansour19/my-app:${BUILD_NUMBER}")

                                app.push()

                                app.push("latest")
                            }
                        }
                    }
                }
            }
        }

        stage('Debug Kubectl') {
            steps {
                container('kubectl') {

                    sh '''
                    echo "========== DEBUG =========="

                    whoami

                    pwd

                    ls -la

                    which kubectl

                    kubectl version --client

                    echo "==========================="
                    '''
                }
            }
        }

        stage('Verify Cluster') {
            steps {
                container('kubectl') {

                    sh '''
                    kubectl cluster-info

                    kubectl get nodes

                    kubectl get deployment spring-boot-app
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                container('kubectl') {

                    sh """
                    kubectl set image deployment/spring-boot-app \
                    spring-boot-app=mansour19/my-app:${BUILD_NUMBER}
                    """

                    sh '''
                    kubectl rollout status deployment/spring-boot-app
                    '''
                }
            }
        }
    }
}
