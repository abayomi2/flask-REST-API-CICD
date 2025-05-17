pipeline {
    agent any // Ensure this agent has git, docker, aws-cli, kubectl, python, and trivy installed

    environment {
        AWS_REGION         = 'us-east-1'
        EKS_CLUSTER_NAME   = 'my-dev-eks-cluster' // Ensure this matches your Terraform cluster name
        DOCKERHUB_USERNAME = 'abayomi2'           // Your Docker Hub username
        APP_NAME           = 'my-simple-app'      // Your application name
        
        IMAGE_TAG          = "v${env.BUILD_NUMBER}"
        DOCKER_IMAGE_NAME  = "${env.DOCKERHUB_USERNAME}/${env.APP_NAME}"
        // Define APP_SERVICE_NAME and APP_NAMESPACE for easier reference in smoke test
        APP_SERVICE_NAME   = 'my-simple-app-service'
        APP_NAMESPACE      = 'default' // Assuming your app is deployed to the default namespace
    }

    stages {
        // ... [Previous stages: Run Unit Tests, Build Docker Image, Scan Docker Image, Login, Push, Configure Kubectl, Update K8s Manifests] ...

        stage('Run Unit Tests') {
            steps {
                dir('application') { 
                    sh '''
                        python3 -m venv .venv 
                        ./.venv/bin/pip install -r requirements.txt
                        ./.venv/bin/python -m unittest discover -v
                    '''
                }
                echo "Unit tests completed successfully!"
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('application') {
                    script {
                        print "INFO: Build Docker Image Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
                        print "INFO: Build Docker Image Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
                        if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
                            sh "docker build -t ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} -t ${env.DOCKER_IMAGE_NAME}:latest ."
                        } else {
                            error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting build."
                        }
                    }
                }
            }
        }

        stage('Scan Docker Image with Trivy') {
            steps {
                script {
                    print "INFO: Security Scan Stage - Scanning image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                    sh "trivy image --exit-code 0 --severity HIGH,CRITICAL --ignore-unfixed --no-progress ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                }
                echo "Docker image security scan completed."
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
                script {
                    print "INFO: Push Docker Image Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
                    print "INFO: Push Docker Image Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
                    if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
                        sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                        sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
                        sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                        sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
                    } else {
                        error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting push."
                    }
                }
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
                script {
                    print "INFO: Update K8s Manifests Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
                    print "INFO: Update K8s Manifests Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
                    if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
                        sh "sed -i 's|image:.*|image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}|g' kubernetes/deployment.yaml"
                        sh "cat kubernetes/deployment.yaml"
                    } else {
                        error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting manifest update."
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script { 
                    sh "kubectl apply -f kubernetes/deployment.yaml"
                    sh "kubectl apply -f kubernetes/service.yaml"
                    sh "kubectl rollout status deployment/my-simple-app-deployment --namespace ${env.APP_NAMESPACE} --timeout=3m" // Increased timeout slightly
                }
            }
        }

        stage('Smoke Test Application') { // <<<< NEW STAGE
            steps {
                script {
                    echo "INFO: Starting Smoke Test..."
                    // Give the LoadBalancer a bit more time to be fully ready and DNS to propagate
                    echo "INFO: Waiting for 60 seconds for LoadBalancer and DNS to stabilize..."
                    sleep 60 

                    // Get the LoadBalancer hostname
                    // This command might need a few retries if the LB isn't immediately available
                    def serviceUrl = ''
                    for (int i = 0; i < 5; i++) { // Retry up to 5 times
                        serviceUrl = sh(script: "kubectl get service ${env.APP_SERVICE_NAME} -n ${env.APP_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
                        if (serviceUrl) {
                            print "INFO: Found LoadBalancer URL: ${serviceUrl}"
                            break
                        }
                        print "WARN: LoadBalancer URL not yet available. Retrying in 20 seconds... (Attempt ${i + 1}/5)"
                        sleep 20
                    }

                    if (!serviceUrl) {
                        error "ERROR: Could not retrieve LoadBalancer URL for smoke test after multiple attempts."
                    } else {
                        // Ensure the smoke_test.sh script is executable
                        sh "chmod +x ./smoke_test.sh"
                        // Execute the smoke test script
                        sh "./smoke_test.sh ${serviceUrl}"
                        echo "INFO: Smoke Test completed."
                    }
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
            echo "Successfully tested, scanned, built, deployed, and smoke-tested ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} to EKS."
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}





// pipeline {
//     agent any // Ensure this agent has git, docker, aws-cli, kubectl, python, and trivy installed

//     environment {
//         AWS_REGION         = 'us-east-1'
//         EKS_CLUSTER_NAME   = 'my-dev-eks-cluster' // Ensure this matches your Terraform cluster name
//         DOCKERHUB_USERNAME = 'abayomi2'           // Your Docker Hub username
//         APP_NAME           = 'my-simple-app'      // Your application name
        
//         IMAGE_TAG          = "v${env.BUILD_NUMBER}"
//         DOCKER_IMAGE_NAME  = "${env.DOCKERHUB_USERNAME}/${env.APP_NAME}"
//     }

//     stages {
//         // Implicit SCM checkout by Jenkins happens before any stages execute

//         stage('Run Unit Tests') {
//             steps {
//                 dir('application') { 
//                     sh '''
//                         python3 -m venv .venv 
//                         ./.venv/bin/pip install -r requirements.txt
//                         ./.venv/bin/python -m unittest discover -v
//                     '''
//                 }
//                 echo "Unit tests completed successfully!"
//             }
//         }

//         stage('Build Docker Image') {
//             steps {
//                 dir('application') {
//                     script {
//                         print "INFO: Build Docker Image Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
//                         print "INFO: Build Docker Image Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
                        
//                         if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
//                             sh "docker build -t ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} -t ${env.DOCKER_IMAGE_NAME}:latest ."
//                         } else {
//                             error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting build."
//                         }
//                     }
//                 }
//             }
//         }

//         stage('Scan Docker Image with Trivy') { // <<<< NEW STAGE
//             steps {
//                 script {
//                     print "INFO: Security Scan Stage - Scanning image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                     // Ensure the image is available locally for Trivy to scan (it should be after the build stage)
                    
//                     // Option 1: Report HIGH and CRITICAL vulnerabilities, but don't fail the build based on findings (for now).
//                     // This allows you to see the vulnerabilities without immediately blocking your pipeline.
//                     // You can adjust --exit-code and --severity later to enforce failure.
//                     sh "trivy image --exit-code 0 --severity HIGH,CRITICAL --ignore-unfixed --no-progress ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
                    
//                     // Example of how you might fail the build if CRITICAL vulnerabilities are found:
//                     // try {
//                     //     sh "trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed --no-progress ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                     // } catch (Exception e) {
//                     //     currentBuild.result = 'FAILURE'
//                     //     error("Trivy scan found CRITICAL vulnerabilities. Failing build. ${e.getMessage()}")
//                     // }
                    
//                     // To output to a file and archive it (optional):
//                     // sh "trivy image --format json --output trivy-report-${env.BUILD_NUMBER}.json --ignore-unfixed ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                     // archiveArtifacts artifacts: "trivy-report-${env.BUILD_NUMBER}.json", fingerprint: true
//                 }
//                 echo "Docker image security scan completed."
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
//                 script {
//                     print "INFO: Push Docker Image Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
//                     print "INFO: Push Docker Image Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
//                     if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
//                         sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                         sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
//                         sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                         sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
//                     } else {
//                         error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting push."
//                     }
//                 }
//             }
//         }

//         stage('Configure Kubectl') {
//             steps {
//                 sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER_NAME}"
//                 sh "kubectl config get-contexts"
//                 sh "kubectl cluster-info"
//             }
//         }

//         stage('Update Kubernetes Manifests') {
//             steps {
//                 script {
//                     print "INFO: Update K8s Manifests Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
//                     print "INFO: Update K8s Manifests Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
//                     if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
//                         sh "sed -i 's|image:.*|image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}|g' kubernetes/deployment.yaml"
//                         sh "cat kubernetes/deployment.yaml"
//                     } else {
//                         error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting manifest update."
//                     }
//                 }
//             }
//         }
        
//         stage('Deploy to EKS') {
//             steps {
//                 script { 
//                     sh "kubectl apply -f kubernetes/deployment.yaml"
//                     sh "kubectl apply -f kubernetes/service.yaml"
//                     sh "kubectl rollout status deployment/my-simple-app-deployment --namespace default --timeout=2m"
//                 }
//             }
//         }
//     }

//     post {
//         always {
//             echo 'Pipeline finished.'
//             sh "command -v docker && docker logout || echo 'Docker command not found, skipping logout'"
//         }
//         success {
//             echo "Successfully tested, scanned, built, and deployed ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} to EKS."
//         }
//         failure {
//             echo 'Pipeline failed.'
//         }
//     }
// }





// pipeline {
//     agent any // Ensure this agent has git, docker, aws-cli, kubectl, and python installed

//     environment {
//         AWS_REGION         = 'us-east-1'
//         EKS_CLUSTER_NAME   = 'my-dev-eks-cluster' // Ensure this matches your Terraform cluster name
//         DOCKERHUB_USERNAME = 'abayomi2'           // Your Docker Hub username
//         APP_NAME           = 'my-simple-app'      // Your application name
        
//         // Define DOCKER_IMAGE_NAME and IMAGE_TAG directly using other env variables
//         // This approach is often more reliable for immediate availability across stages
//         IMAGE_TAG          = "v${env.BUILD_NUMBER}"
//         DOCKER_IMAGE_NAME  = "${env.DOCKERHUB_USERNAME}/${env.APP_NAME}"
//     }

//     stages {
//         // The 'Initialize' stage has been removed as variables are set globally above.

//         // Implicit SCM checkout by Jenkins happens before any stages execute when using "Pipeline script from SCM"

//         stage('Run Unit Tests') {
//             steps {
//                 dir('application') { // Navigate into the application directory
//                     sh '''
//                         # Create a virtual environment
//                         python3 -m venv .venv 
//                         # Use the virtual environment's pip to install dependencies
//                         ./.venv/bin/pip install -r requirements.txt
//                         # Run tests using the virtual environment's python
//                         ./.venv/bin/python -m unittest discover -v
//                     '''
//                 }
//                 echo "Unit tests completed successfully!"
//             }
//         }

//         stage('Build Docker Image') {
//             steps {
//                 dir('application') {
//                     script {
//                         print "INFO: Build Docker Image Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
//                         print "INFO: Build Docker Image Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
                        
//                         // More explicit check for null or empty strings
//                         if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
//                             sh "docker build -t ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} -t ${env.DOCKER_IMAGE_NAME}:latest ."
//                         } else {
//                             error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting build."
//                         }
//                     }
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
//                 script {
//                     print "INFO: Push Docker Image Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
//                     print "INFO: Push Docker Image Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
//                     if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
//                         sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                         sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
//                         // Clean up local images
//                         sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}"
//                         sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
//                     } else {
//                         error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting push."
//                     }
//                 }
//             }
//         }

//         stage('Configure Kubectl') {
//             steps {
//                 sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER_NAME}"
//                 sh "kubectl config get-contexts"
//                 sh "kubectl cluster-info"
//             }
//         }

//         stage('Update Kubernetes Manifests') {
//             steps {
//                 script {
//                     print "INFO: Update K8s Manifests Stage - Current DOCKER_IMAGE_NAME: '${env.DOCKER_IMAGE_NAME}'"
//                     print "INFO: Update K8s Manifests Stage - Current IMAGE_TAG: '${env.IMAGE_TAG}'"
//                     if (env.DOCKER_IMAGE_NAME != null && env.DOCKER_IMAGE_NAME.trim() != "" && env.IMAGE_TAG != null && env.IMAGE_TAG.trim() != "") {
//                         sh "sed -i 's|image:.*|image: ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG}|g' kubernetes/deployment.yaml"
//                         sh "cat kubernetes/deployment.yaml"
//                     } else {
//                         error "ERROR: DOCKER_IMAGE_NAME ('${env.DOCKER_IMAGE_NAME}') or IMAGE_TAG ('${env.IMAGE_TAG}') is not properly set. Halting manifest update."
//                     }
//                 }
//             }
//         }
        
//         stage('Deploy to EKS') {
//             steps {
//                 script { 
//                     sh "kubectl apply -f kubernetes/deployment.yaml"
//                     sh "kubectl apply -f kubernetes/service.yaml"
//                     sh "kubectl rollout status deployment/my-simple-app-deployment --namespace default --timeout=2m"
//                 }
//             }
//         }
//     }

//     post {
//         always {
//             echo 'Pipeline finished.'
//             sh "command -v docker && docker logout || echo 'Docker command not found, skipping logout'"
//         }
//         success {
//             echo "Successfully tested, built, and deployed ${env.DOCKER_IMAGE_NAME}:${env.IMAGE_TAG} to EKS."
//         }
//         failure {
//             echo 'Pipeline failed.'
//         }
//     }
// }






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