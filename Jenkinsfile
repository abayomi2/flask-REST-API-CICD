pipeline {
    agent any // Ensure this agent has git, docker, aws-cli, kubectl, and python installed

    environment {
        AWS_REGION         = 'us-east-1'
        EKS_CLUSTER_NAME   = 'my-dev-eks-cluster' // Ensure this matches your Terraform cluster name
        DOCKERHUB_USERNAME = 'abayomi2'
        APP_NAME           = 'my-simple-app'
        // DOCKER_IMAGE_NAME and IMAGE_TAG will be set in the Initialize stage
        DOCKER_IMAGE_NAME  = '' 
        IMAGE_TAG          = '' 
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    env.IMAGE_TAG = "v${env.BUILD_NUMBER}"
                    env.DOCKER_IMAGE_NAME = "${env.DOCKERHUB_USERNAME}/${env.APP_NAME}"
                    print "Docker Image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                }
            }
        }

        // Implicit SCM checkout by Jenkins happens before any stages execute when using "Pipeline script from SCM"

        stage('Run Unit Tests') {
            steps {
                dir('application') { // Navigate into the application directory
                    // Ensure python3 and pip3 are available on your Jenkins agent
                    sh '''
                        # Create a virtual environment
                        python3 -m venv .venv 
                        # Activate and use the virtual environment's pip to install dependencies
                        # Note: Activating a venv in a non-interactive shell script can be tricky.
                        # It's often easier to directly call the executables from the venv's bin directory.
                        ./.venv/bin/pip install -r requirements.txt
                        # Run tests using the virtual environment's python
                        ./.venv/bin/python -m unittest discover -v
                    '''
                }
                echo "Unit tests completed successfully!"
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('application') {
                    sh "docker build -t ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} -t ${env.DOCKER_IMAGE_NAME}:latest ."
                }
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh "echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin"
                }
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
                sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('Configure Kubectl') {
            steps {
                sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER_NAME}"
                sh "kubectl config get-contexts"
                sh "kubectl cluster-info"
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                sh "sed -i 's|image:.*|image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}|g' kubernetes/deployment.yaml"
                sh "cat kubernetes/deployment.yaml"
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script { 
                    sh "kubectl apply -f kubernetes/deployment.yaml"
                    sh "kubectl apply -f kubernetes/service.yaml"
                    sh "kubectl rollout status deployment/my-simple-app-deployment --namespace default --timeout=2m"
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            sh "command -v docker && docker logout || echo 'Docker command not found, skipping logout'"
        }
        success {
            echo "Successfully tested, built, and deployed ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} to EKS."
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}





// pipeline {
//     agent any // Or specify a dedicated agent with Docker, kubectl, aws-cli

//     environment {
//         AWS_REGION = 'us-east-1' // Your AWS Region
//         EKS_CLUSTER_NAME = 'my-dev-eks-cluster' // Matches your Terraform EKS cluster name
//         DOCKERHUB_USERNAME = 'abayomi2' // Replace with your Docker Hub username
//         DOCKER_IMAGE_NAME = "${env.DOCKERHUB_USERNAME}/my-simple-app" // Your Docker Hub repo: <username>/<imagename>
//         IMAGE_TAG = "v${env.BUILD_NUMBER}"
//     }

//     stages {
//         // stage('Checkout') {
//         //     steps {
//         //         git 'https://github.com/abayomi2/flask-REST-API-CICD.git' // Replace with your Git repo URL
//         //     }
//         // }

//         stage('Build Docker Image') {
//             steps {
//                 dir('application') {
//                     // Tag with latest and with a version (build number)
//                     sh "docker build -t ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} -t ${env.DOCKER_IMAGE_NAME}:latest ."
//                 }
//             }
//         }

//         stage('Login to Docker Hub') {
//             steps {
//                 withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
//                     sh "echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin"
//                 }
//             }
//         }

//         stage('Push Docker Image to Docker Hub') {
//             steps {
//                 sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                 sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
//                 // Clean up local images
//                 sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                 sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
//             }
//         }

//         stage('Update Kubernetes Manifests') {
//             steps {
//                 // Replace the image placeholder in deployment.yaml with the Docker Hub image and specific tag
//                 // Using a unique tag (like the build number) is better for rollbacks and tracking
//                 sh "sed -i 's|image:.*|image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}|g' kubernetes/deployment.yaml"
//                 // If you have imagePullPolicy: Always, Kubernetes will try to pull, even if the tag is the same.
//                 // If imagePullPolicy: IfNotPresent, it will only pull if the image isn't there locally on the node.
//             }
//         }

//         stage('Deploy to EKS') {
//             steps {
//                 script {
//                     sh "aws eks update-kubeconfig --name ${env.EKS_CLUSTER_NAME} --region ${env.AWS_REGION}"
//                     sh "kubectl apply -f kubernetes/deployment.yaml"
//                     sh "kubectl apply -f kubernetes/service.yaml"
//                     sh "kubectl rollout status deployment/my-simple-app-deployment --timeout=120s"
//                 }
//             }
//         }
//     }

//     post {
//         always {
//             echo 'Pipeline finished.'
//             // Logout from Docker Hub
//             sh "docker logout"
//         }
//         success {
//             echo 'Pipeline executed successfully!'
//         }
//         failure {
//             echo 'Pipeline failed!'
//         }
//     }
// }