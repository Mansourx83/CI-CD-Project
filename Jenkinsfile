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
    image: alpine:3.20

    command:
    - /bin/sh
    - -c

    args:
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


    stages {


        stage('Build with Maven') {

            steps {

                container('maven') {

                    dir('spring-boot-app') {

                        sh '''
                        mvn clean package -DskipTests
                        '''

                    }

                }

            }

        }



        stage('Docker Build and Push') {

            steps {

                container('docker') {

                    script {

                        docker.withRegistry(
                            '',
                            'docker-cred'
                        ) {


                            dir('spring-boot-app') {


                                def image = docker.build(
                                    "mansour19/my-app:${BUILD_NUMBER}"
                                )


                                image.push()

                                image.push('latest')


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

                    echo "Checking Kubernetes"

                    kubectl cluster-info

                    kubectl get nodes

                    kubectl get deployment spring-boot-app

                    '''

                }

            }

        }



        stage('Deploy to K8s') {

            steps {

                container('kubectl') {


                    sh """

                    kubectl set image deployment/spring-boot-app \
                    spring-boot-app=mansour19/my-app:${BUILD_NUMBER}


                    kubectl rollout status deployment/spring-boot-app

                    """


                }

            }

        }


    }

}
