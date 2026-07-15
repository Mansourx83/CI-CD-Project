pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8.5-openjdk-17
    command: ['cat']
    tty: true
  - name: docker
    image: docker:20.10
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
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
        stage('Docker Build and Push') {
            steps {
                container('docker') {
                    script {
                        docker.withRegistry('', 'docker-cred') {
                            dir('spring-boot-app') {
                                def customImage = docker.build("mansour19/my-app:${env.BUILD_NUMBER}")
                                customImage.push()
                                customImage.push('latest')
                            }
                        }
                    }
                }
            }
        }
    }
}