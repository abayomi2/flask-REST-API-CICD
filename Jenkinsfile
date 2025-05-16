pipeline {
    agent any // Or specify a dedicated agent with Docker, kubectl, aws-cli

    environment {
        AWS_REGION = 'us-east-1' // Your AWS Region
        EKS_CLUSTER_NAME = 'my-simple-app-cluster' // Matches your Terraform EKS cluster name
        DOCKERHUB_USERNAME = 'abayomi2' // Replace with your Docker Hub username
        DOCKER_IMAGE_NAME = "${env.DOCKERHUB_USERNAME}/my-simple-app" // Your Docker Hub repo: <username>/<imagename>
        IMAGE_TAG = "v${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/abayomi2/flask-REST-API-CICD.git' // Replace with your Git repo URL
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('application') {
                    // Tag with latest and with a version (build number)
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
                // Clean up local images
                sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                // Replace the image placeholder in deployment.yaml with the Docker Hub image and specific tag
                // Using a unique tag (like the build number) is better for rollbacks and tracking
                sh "sed -i 's|image:.*|image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}|g' kubernetes/deployment.yaml"
                // If you have imagePullPolicy: Always, Kubernetes will try to pull, even if the tag is the same.
                // If imagePullPolicy: IfNotPresent, it will only pull if the image isn't there locally on the node.
            }
        }

        stage('Deploy to EKS') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${env.EKS_CLUSTER_NAME} --region ${env.AWS_REGION}"
                    sh "kubectl apply -f kubernetes/deployment.yaml"
                    sh "kubectl apply -f kubernetes/service.yaml"
                    sh "kubectl rollout status deployment/my-simple-app-deployment --timeout=120s"
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            // Logout from Docker Hub
            sh "docker logout"
        }
        success {
            echo 'Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}