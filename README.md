# TERRAFORM
aws eks update-kubeconfig --region us-east-1 --name my-dev-eks-cluster
# Example: aws eks update-kubeconfig --region us-east-1 --name my-dev-eks-cluster

# Talking Points for Your Interview:
Choice of Tools: Explain why Jenkins, Terraform, Docker, Kubernetes, and AWS were chosen (align with job description and your experience).
The "Why" of Each Step:
"I started with a simple Flask app to have a deployable artifact."
"Dockerized it to ensure consistency across environments."
"Used Terraform to manage AWS infrastructure (ECR, EKS) as code, making it repeatable and version-controlled."
"The Jenkins pipeline automates the entire process: checkout, build, push to ECR, and deploy to EKS."
"Kubernetes was chosen for orchestration, enabling scalability and resilience."
Challenges & Solutions: "Setting up the IAM roles for EKS in Terraform required careful attention to permissions." or "Integrating Jenkins with kubectl for EKS deployment involved configuring the kubeconfig correctly on the agent."
Improvements/Next Steps: "For a production system, I'd add more robust health checks, secrets management (e.g., HashiCorp Vault or AWS Secrets Manager), more sophisticated monitoring with Prometheus/Grafana, blue/green deployments, and more comprehensive testing stages in the pipeline."