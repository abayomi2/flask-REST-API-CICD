# TERRAFORM
aws eks update-kubeconfig --region us-east-1 --name my-dev-eks-cluster
# Example: aws eks update-kubeconfig --region us-east-1 --name my-dev-eks-cluster

## What to install on Jenkins Agent: Jenkins, AWC CLI, Docker, python3, pip, python3.12-venv -y, 

# CI/CD Pipeline for Flask Application on AWS EKS using Jenkins and Terraform

This project demonstrates an end-to-end CI/CD pipeline that automates the deployment of a Python Flask web application to a Kubernetes cluster (AWS EKS). The pipeline uses Jenkins for orchestration, Terraform for Infrastructure as Code (IaC), Docker for containerization, Docker Hub as the image repository, and GitHub for version control with webhook integration for continuous integration.

## Project Overview

The core objective is to showcase a robust DevOps workflow:
1.  **Infrastructure Provisioning:** AWS EKS cluster and supporting resources are provisioned using Terraform.
2.  **CI/CD Server Setup:** A Jenkins server is set up on an AWS EC2 instance with all necessary tools (Java, Docker, AWS CLI, kubectl).
3.  **Application Containerization:** A simple Flask application is containerized using Docker.
4.  **Automated Pipeline:** A Jenkins pipeline (`Jenkinsfile`) defines the CI/CD process:
    * Checkout code from GitHub.
    * Build the Docker image.
    * Push the image to Docker Hub.
    * Configure `kubectl` to connect to the EKS cluster.
    * Update Kubernetes deployment manifests with the new image tag.
    * Deploy the application to EKS.
5.  **Continuous Integration:** A GitHub webhook triggers the Jenkins pipeline automatically on code pushes.

## Prerequisites

Before you begin, ensure you have the following:
* An AWS Account with necessary permissions to create EKS clusters, EC2 instances, IAM roles, etc.
* AWS CLI configured locally (for initial Terraform setup if not running Terraform from an environment with an IAM role).
* Terraform CLI installed locally.
* Git installed locally.
* A GitHub account and a repository for this project.
* A Docker Hub account.
* A text editor or IDE (e.g., VS Code).

## Project Structure

.
├── application/            # Python Flask application code
│   ├── app.py              # Main Flask application with API endpoints and Prometheus metrics
│   ├── requirements.txt    # Python dependencies (Flask, prometheus_flask_exporter, etc.)
│   ├── Dockerfile
│   └── test_app.py         # Unit tests for the Flask application
├── kubernetes/             # Kubernetes manifest files for the application
│   ├── deployment.yaml
│   └── service.yaml
├── monitoring/             # Kubernetes manifest files for monitoring stack
│   ├── prometheus/
│   │   └── prometheus-setup.yaml # (or individual Prometheus manifests)
│   └── grafana/
│       └── grafana-setup.yaml    # (or individual Grafana manifests)
├── terraform/              # Terraform scripts for AWS infrastructure
│   └── main.tf             # (and potentially variables.tf, outputs.tf)
├── Jenkinsfile             # Jenkins declarative pipeline script
├── install_jenkins_docker_ubuntu.sh # (Optional) Script to setup Jenkins server
├── smoke_test.sh           # Script for post-deployment smoke testing
└── README.md               # This file
---

## Stage 1: Infrastructure as Code (IaC) with Terraform on AWS

**Goal:** Provision an AWS EKS cluster and necessary IAM roles using Terraform.

**Steps:**

1.  **Navigate to Terraform Directory:**
    ```bash
    cd terraform
    ```
2.  **Review Terraform Configuration (`main.tf`):**
    * The `main.tf` file defines:
        * AWS provider and region.
        * Data sources to fetch your default VPC and subnets (filtered for EKS compatibility).
        * IAM roles for the EKS cluster and node groups (`eks_cluster_role`, `eks_nodegroup_role`) with necessary policies attached (`AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController`, `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`).
        * The AWS EKS cluster resource (`aws_eks_cluster`).
        * The AWS EKS managed node group resource (`aws_eks_node_group`).
    * Ensure variables like `aws_region`, `cluster_name`, `eks_version`, `node_instance_type`, etc., are set as desired. The script uses `us-east-1` and `my-dev-eks-cluster` as defaults.
3.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
4.  **Plan the Deployment:**
    ```bash
    terraform plan
    ```
    Review the plan to understand what resources will be created.
5.  **Apply the Configuration:**
    ```bash
    terraform apply
    ```
    Type `yes` when prompted. This process can take 15-25 minutes.
6.  **Verify EKS Cluster:**
    Once applied, Terraform will output cluster details. You can also check the AWS Management Console.

---

## Stage 2: Jenkins Server Setup on AWS EC2

**Goal:** Set up an EC2 instance to act as the Jenkins CI/CD server, equipped with all necessary tools.

**Steps:**

1.  **Launch an EC2 Instance:**
    * Choose an Ubuntu Server AMI (e.g., Ubuntu 22.04 LTS or 24.04 LTS).
    * Select an instance type (e.g., `t2.medium` or `t3.medium` is a good start).
    * **Security Group:** Ensure inbound rules allow:
        * SSH (port 22) from your IP.
        * HTTP (port 8080) from your IP (or `0.0.0.0/0` for initial setup, then restrict to GitHub IPs for webhooks).
    * **IAM Role (Crucial for AWS CLI):** Attach an IAM Role to this EC2 instance that grants permissions to interact with EKS (e.g., the `JenkinsEKSAccessPolicy` detailed in troubleshooting, allowing at least `eks:DescribeCluster`).
    * Launch the instance and connect via SSH.
2.  **Run Setup Script (Optional but Recommended):**
    * Use the `install_jenkins_docker_ubuntu.sh` script (provided in earlier discussions) or manually install the following:
        * **Update packages:** `sudo apt update -y && sudo apt upgrade -y`
        * **Java (OpenJDK 17):** Jenkins requires Java.
            ```bash
            sudo apt install -y openjdk-17-jdk
            # Set JAVA_HOME (as done in the script)
            ```
        * **Jenkins:** Follow the official Jenkins installation guide for Debian/Ubuntu.
            ```bash
            # Example (key URL might change, refer to current Jenkins docs or the provided script):
            # sudo wget -O /usr/share/keyrings/jenkins-keyring.asc [https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key](https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key)
            # echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] [https://pkg.jenkins.io/debian-stable](https://pkg.jenkins.io/debian-stable) binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            # sudo apt update -y
            # sudo apt install -y jenkins
            # sudo systemctl enable --now jenkins
            ```
        * **Docker:** Install Docker Engine.
            ```bash
            # Follow official Docker installation guide for Ubuntu
            # Add jenkins user to docker group:
            # sudo usermod -aG docker jenkins
            # sudo systemctl restart jenkins
            ```
        * **AWS CLI v2:**
            ```bash
            # curl "[https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip](https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip)" -o "awscliv2.zip"
            # sudo apt install unzip -y
            # unzip awscliv2.zip
            # sudo ./aws/install --update
            ```
        * **kubectl:** Install a version compatible with your EKS cluster (e.g., 1.29.x).
            ```bash
            # curl -LO "[https://dl.k8s.io/release/v1.29.5/bin/linux/amd64/kubectl](https://dl.k8s.io/release/v1.29.5/bin/linux/amd64/kubectl)" # Or latest stable
            # chmod +x ./kubectl
            # sudo mv ./kubectl /usr/local/bin/kubectl
            ```
3.  **Initial Jenkins Setup:**
    * Access Jenkins in your browser: `http://<your_ec2_public_ip>:8080`.
    * Retrieve the initial admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
    * Follow the setup wizard: Install suggested plugins. Create an admin user.
4.  **Configure Jenkins Credentials:**
    * Go to "Manage Jenkins" -> "Credentials" -> "System" -> "Global credentials".
    * Add your Docker Hub credentials:
        * Kind: Username with password
        * Username: Your Docker Hub username
        * Password: Your Docker Hub password or Access Token
        * ID: `dockerhub-credentials` (or as referenced in `Jenkinsfile`)

---

## Stage 3: Application Development & Containerization

**Goal:** Create a simple Flask web application and a `Dockerfile` to containerize it.

**Steps:**

1.  **Flask Application (`application/app.py`):**
    * A basic Python Flask app that returns a greeting. (Code provided in previous discussions).
2.  **Python Dependencies (`application/requirements.txt`):**
    * Lists `Flask`.
3.  **Dockerfile (`application/Dockerfile`):**
    * Uses a Python base image (e.g., `python:3.9-slim`).
    * Copies application code and installs dependencies.
    * Exposes the application port (e.g., 5000).
    * Sets the `CMD` to run the Flask application.
    * (Corrected `ENV APP_VERSION="1.0"` format).

---

## Stage 4: Kubernetes Manifests

**Goal:** Define Kubernetes resources to deploy and expose the application.

**Steps:**

1.  **Deployment Manifest (`kubernetes/deployment.yaml`):**
    * Defines a `Deployment` to manage application replicas.
    * Specifies the Docker image to use (placeholder `your-dockerhub-username/my-simple-app:latest`, which Jenkins will update).
    * Sets container ports and labels.
    * Includes optional environment variables and probes.
2.  **Service Manifest (`kubernetes/service.yaml`):**
    * Defines a `Service` of type `LoadBalancer` to expose the application externally via an AWS Load Balancer.
    * Maps the service port (e.g., 80) to the container's target port (e.g., 5000).
    * Uses a selector to link to the pods created by the Deployment.

---

## Stage 5: Jenkins CI/CD Pipeline (`Jenkinsfile`)

**Goal:** Automate the build, test (not implemented in this basic version), and deployment process.

**Steps:**

1.  **Create `Jenkinsfile`:**
    * A declarative pipeline script located in the root of your Git repository.
2.  **Define Environment Variables:**
    * `AWS_REGION`, `EKS_CLUSTER_NAME` (ensure this matches your Terraform output, e.g., `my-dev-eks-cluster`), `DOCKERHUB_USERNAME`, `APP_NAME`.
3.  **Pipeline Stages:**
    * **Initialize:** Sets dynamic environment variables like `IMAGE_TAG` and `DOCKER_IMAGE_NAME`.
    * **(Implicit Checkout):** Jenkins automatically checks out the repository containing the `Jenkinsfile` when "Pipeline script from SCM" is used.
    * **Build Docker Image:** Builds the Docker image using the `Dockerfile` in the `application/` directory and tags it.
    * **Login to Docker Hub:** Uses stored credentials to log in to Docker Hub.
    * **Push Docker Image to Docker Hub:** Pushes the tagged image and a `latest` tag.
    * **Configure Kubectl:** Runs `aws eks update-kubeconfig` to allow `kubectl` to communicate with the EKS cluster. (This relies on the EC2 instance IAM role for AWS credentials).
    * **Update Kubernetes Manifests:** Uses `sed` to replace the image placeholder in `kubernetes/deployment.yaml` with the newly built image tag.
    * **Deploy to EKS:** Uses `kubectl apply` to deploy the `deployment.yaml` and `service.yaml`. Includes `kubectl rollout status` to monitor deployment.
4.  **Post Actions:**
    * Logs out of Docker Hub.
    * Provides success/failure messages.
5.  **Jenkins Job Configuration:**
    * Create a new "Pipeline" job in Jenkins.
    * Configure "Pipeline script from SCM".
    * Point to your Git repository URL and specify the branch (e.g., `main`).
    * Script Path: `Jenkinsfile`.

---

## Stage 6: GitHub Webhook for Continuous Integration

**Goal:** Automatically trigger the Jenkins pipeline on code pushes to GitHub.

**Steps:**

1.  **Jenkins Job Configuration:**
    * In your Jenkins pipeline job, go to "Configure".
    * Under "Build Triggers", check **"GitHub hook trigger for GITScm polling"**.
    * Save the configuration.
2.  **GitHub Repository Webhook Setup:**
    * Go to your GitHub repository -> Settings -> Webhooks -> Add webhook.
    * **Payload URL:** `http://<YOUR_JENKINS_EC2_PUBLIC_IP>:8080/github-webhook/` (ensure Jenkins is accessible from the internet on this port).
    * **Content type:** `application/json`.
    * **Secret:** (Optional) A secret token for verification.
    * **Events:** Select "Just the push event."
    * Ensure "Active" is checked.
    * Add the webhook.
3.  **Test Webhook:**
    * GitHub will send a ping. Check "Recent Deliveries" for a successful response (200 OK).
    * Make a code change to your repository, commit, and push to the configured branch.
    * Verify that the Jenkins job automatically starts.

---

## Running the Project (Summary)

1.  Clone this repository.
2.  Provision AWS infrastructure using Terraform (`terraform apply`).
3.  Set up the Jenkins server on an EC2 instance with all tools and IAM role.
4.  Configure the Jenkins pipeline job, pointing to this Git repository.
5.  (Optional but recommended) Configure the GitHub webhook.
6.  Push a code change (if webhook is set up) or manually trigger the Jenkins job.

## Accessing the Application

1.  Once the Jenkins pipeline successfully completes the "Deploy to EKS" stage:
2.  Wait a few minutes for the AWS Load Balancer to be provisioned.
3.  Get the external DNS name of the LoadBalancer:
    ```bash
    kubectl get service my-simple-app-service -o wide
    ```
    (Look for the `EXTERNAL-IP` value).
4.  Open this DNS name in your web browser. You should see your Flask application's greeting.

---

## Cleaning Up

**Crucial to avoid ongoing AWS charges!**

1.  **Destroy Terraform Infrastructure:**
    ```bash
    cd terraform
    terraform destroy
    ```
    Type `yes` when prompted. This will delete the EKS cluster, node groups, and associated IAM roles.
2.  **Terminate Jenkins EC2 Instance:** Go to the AWS EC2 console and terminate the instance running Jenkins.
3.  **Delete Docker Hub Images (Optional):** Log in to Docker Hub and delete the images if desired.
4.  **Remove GitHub Webhook (Optional).**

---------------------------------------------------------------------------------------------------
                                  ** ENHANCEMENT **
---------------------------------------------------------------------------------------------------

## Stage 1: Infrastructure as Code (IaC) with Terraform on AWS

**Goal:** Provision an AWS EKS cluster and necessary IAM roles using Terraform.

**(Steps remain the same as previous README: Navigate to `terraform/`, `terraform init`, `terraform plan`, `terraform apply`)**

---

## Stage 2: Jenkins Server Setup on AWS EC2

**Goal:** Set up an EC2 instance to act as the Jenkins CI/CD server, equipped with all necessary tools.

**Steps:**

1.  **Launch an EC2 Instance:** (Details same as previous README, ensure IAM Role for EKS access).
2.  **Run Setup Script or Manually Install:**
    * Tools to install: Java (OpenJDK 17), Jenkins, Docker, AWS CLI v2, kubectl, and **Trivy**.
    * (Refer to `install_jenkins_docker_ubuntu.sh` or previous instructions for installing these tools).
    * Ensure the `jenkins` user is added to the `docker` group.
3.  **Initial Jenkins Setup:** (Access Jenkins, initial password, install suggested plugins, create admin user).
4.  **Configure Jenkins Credentials:** (Add Docker Hub credentials with ID `dockerhub-credentials`).

---

## Stage 3: Application Development & Containerization

**Goal:** Develop the Flask web application with enhanced API, HTML homepage, Prometheus metrics, and a `Dockerfile`.

**Steps:**

1.  **Flask Application (`application/app.py`):**
    * Develop a Python Flask app with:
        * An informative HTML homepage at the root (`/`).
        * REST API endpoints (e.g., `/api/v1/health`, `/api/v1/devices/...`).
        * Instrumentation using `prometheus_flask_exporter` to expose a `/metrics` endpoint.
2.  **Python Dependencies (`application/requirements.txt`):**
    * Include `Flask`, `Werkzeug` (pinned to a compatible version like `2.3.8`), and `prometheus_flask_exporter`.
3.  **Unit Tests (`application/test_app.py`):**
    * Write unit tests using Python's `unittest` module to cover the API endpoints.
4.  **Dockerfile (`application/Dockerfile`):**
    * Standard Dockerfile to containerize the Flask application.

---

## Stage 4: Kubernetes Manifests (Application & Monitoring)

**Goal:** Define Kubernetes resources to deploy the application and the monitoring stack.

**Steps:**

1.  **Application Manifests (`kubernetes/`):**
    * **`deployment.yaml`**: Defines the Deployment for the Flask application. Ensure it has appropriate labels (e.g., `app: my-simple-app`) for service discovery and Prometheus scraping.
    * **`service.yaml`**: Defines the Service (e.g., type `LoadBalancer`) to expose the Flask application.
2.  **Monitoring Stack Manifests (`monitoring/`):**
    * **Prometheus (`monitoring/prometheus/prometheus-setup.yaml`):**
        * Includes Namespace, ServiceAccount, ClusterRole, ClusterRoleBinding for Prometheus.
        * ConfigMap for `prometheus.yml` defining scrape jobs (including one to scrape the Flask app based on labels/annotations and the `/metrics` endpoint on port 5000).
        * Deployment for the Prometheus server.
        * Service (e.g., type `NodePort`) to expose Prometheus.
    * **Grafana (`monitoring/grafana/grafana-setup.yaml`):**
        * Deployment for the Grafana server.
        * Service (e.g., type `NodePort`) to expose Grafana.
        * Uses `emptyDir` for Grafana storage in this project (for persistence, a PVC would be used).
3.  **Apply Monitoring Manifests (Manual Step after EKS is up):**
    ```bash
    kubectl apply -f monitoring/prometheus/prometheus-setup.yaml
    kubectl apply -f monitoring/grafana/grafana-setup.yaml
    ```
    Verify pods in the `monitoring` namespace are running.

---

## Stage 5: Jenkins CI/CD Pipeline (`Jenkinsfile`)

**Goal:** Automate the build, test, security scan, deployment, and smoke test process.

**Steps:**

1.  **Create `Jenkinsfile`:** (Declarative pipeline script in the project root).
2.  **Define Environment Variables:** (`AWS_REGION`, `EKS_CLUSTER_NAME`, `DOCKERHUB_USERNAME`, `APP_NAME`, `IMAGE_TAG`, `DOCKER_IMAGE_NAME`, `APP_SERVICE_NAME`, `APP_NAMESPACE`).
3.  **Pipeline Stages:**
    * **(Implicit Checkout):** Code is checked out from Git.
    * **Run Unit Tests:** Executes `python3 -m unittest discover` within a virtual environment in the `application` directory. Installs dependencies from `requirements.txt` into the venv first.
    * **Build Docker Image:** Builds the Docker image and tags it.
    * **Scan Docker Image with Trivy:** Scans the built image for `HIGH,CRITICAL` vulnerabilities using `trivy image --exit-code 0 ...`. (Currently reports, doesn't fail build).
    * **Login to Docker Hub:** Logs in using stored credentials.
    * **Push Docker Image to Docker Hub:** Pushes the tagged image.
    * **Configure Kubectl:** Runs `aws eks update-kubeconfig`.
    * **Update Kubernetes Manifests:** Uses `sed` to update `kubernetes/deployment.yaml` with the new image tag.
    * **Deploy to EKS:** Applies `kubernetes/deployment.yaml` and `kubernetes/service.yaml`. Waits for rollout.
    * **Smoke Test Application:** After a delay, retrieves the LoadBalancer URL and executes `smoke_test.sh` against the live application.
4.  **Jenkins Job Configuration:** (Create "Pipeline" job, configure "Pipeline script from SCM").

---

## Stage 6: GitHub Webhook for Continuous Integration

**Goal:** Automatically trigger the Jenkins pipeline on code pushes.

**(Steps remain the same as previous README: Configure "GitHub hook trigger" in Jenkins job, Add webhook in GitHub repo settings pointing to `http://<JENKINS_IP>:8080/github-webhook/`)**

---

## Running the Project (Summary)

1.  Clone this repository.
2.  Provision AWS infrastructure using Terraform (`terraform/terraform apply`).
3.  Set up the Jenkins server on an EC2 instance with all tools (Java, Jenkins, Docker, AWS CLI, kubectl, Trivy) and the necessary IAM role.
4.  Apply Kubernetes manifests for Prometheus and Grafana:
    ```bash
    kubectl apply -f monitoring/prometheus/prometheus-setup.yaml
    kubectl apply -f monitoring/grafana/grafana-setup.yaml
    ```
5.  Configure the Jenkins pipeline job, pointing to this Git repository.
6.  Configure the GitHub webhook.
7.  Push a code change or manually trigger the Jenkins job.

## Accessing Services

* **Application:**
    * Get the LoadBalancer DNS: `kubectl get service my-simple-app-service -n <your-app-namespace> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
    * Access via browser: `http://<LOADBALANCER_DNS>/`
    * Metrics endpoint: `http://<LOADBALANCER_DNS>/metrics`
* **Prometheus UI:**
    * Get NodePort: `kubectl get svc prometheus-service -n monitoring`
    * Access via browser: `http://<EKS_NODE_IP>:<PROMETHEUS_NODE_PORT>`
* **Grafana UI:**
    * Get NodePort: `kubectl get svc grafana-service -n monitoring`
    * Access via browser: `http://<EKS_NODE_IP>:<GRAFANA_NODE_PORT>` (Default login: admin/admin, then change password).
    * Configure Prometheus as a data source in Grafana: `http://prometheus-service.monitoring.svc.cluster.local:9090`.

---

## Cleaning Up

**Crucial to avoid ongoing AWS charges!**

1.  **Delete Application and Monitoring Resources from EKS:**
    ```bash
    kubectl delete -f kubernetes/ # Deletes app deployment and service
    kubectl delete -f monitoring/grafana/grafana-setup.yaml
    kubectl delete -f monitoring/prometheus/prometheus-setup.yaml
    kubectl delete namespace monitoring # If it's empty
    ```
2.  **Destroy Terraform Infrastructure:**
    ```bash
    cd terraform
    terraform destroy
    ```
3.  **Terminate Jenkins EC2 Instance.**
4.  **Delete Docker Hub Images (Optional).**
5.  **Remove GitHub Webhook (Optional).**

---

## Future Enhancements

* Implement more sophisticated testing (integration, end-to-end).
* Configure Trivy to fail the pipeline based on vulnerability severity.
* Use a more robust solution for updating Kubernetes manifests (e.g., Kustomize, Helm).
* Implement robust secrets management (e.g., HashiCorp Vault, AWS Secrets Manager).
* Create more detailed Grafana dashboards.
* Use PersistentVolumeClaims for Prometheus and Grafana data.
* Automate deployment of Prometheus/Grafana via Jenkins or GitOps.
* Implement more advanced deployment strategies (blue/green, canary).
* Use a dedicated container registry like AWS ECR.
* Parameterize the Jenkins pipeline.
* Secure Jenkins (e.g., SSL, matrix-based security).

