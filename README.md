# Konecta-Project

# Konecta-Graduation-Project

![diagram-export-4-27-2025-11_43_19-PM](https://github.com/user-attachments/assets/007ebf8d-0e74-4a55-9a80-c7d0806fef40)


# ✅ Step 1: Infrastructure Provisioning with Terraform:

Used an existing VPC:

Passed its vpc_id, public_subnet_ids and private_subnet_ids into Terraform.

Provisioned via Terraform:

A private EKS cluster (2 nodes, no public node IPs) using the AWS EKS Terraform module.

A public Jenkins EC2 (for CI/CD), with an SSH key pair, security group, etc.

An S3 bucket to store Terraform state (configured as the backend)

Automated Jenkins bootstrap by having Terraform spin up the EC2 and then trigger a Bash/Ansible workflow (using a null_resource with remote-exec & local-exec).

Enabled cluster access using a kubeconfig file generated on the Terraform EC2 instance via: aws eks update-kubeconfig --region <region> --name <cluster_name>

Verified the cluster and node group creation using: kubectl get nodes

![p1](https://github.com/user-attachments/assets/481fe9f4-671c-4a50-8f3c-774f28513982)

![p2](https://github.com/user-attachments/assets/58acd12d-081e-43d7-b7a6-2cfa3661f666)

![p3](https://github.com/user-attachments/assets/1b78c1b4-7ed5-464d-930e-b2ae84ef9066)


# ✅ Step 2: Automated Jenkins Installation & Configuration with Ansible:

Installed Ansible on the Terraform control host.

Wrote an Ansible playbook (install_jenkins.yml) that:

Updates apt, installs Java

Imports the correct Jenkins GPG key & repo

Installs and starts Jenkins

Opens port 8080 via UFW

Created a Bash wrapper (scripts/run_ansible.sh) that:

Waits for SSH on the new Jenkins EC2’s private IP

Generates a dynamic ansible/inventory.ini from a tpl file

Runs the playbook against the private host

Hooked it all up so that Terraform’s null_resource waits for the EC2, then SSHs into it, and finally invokes the Ansible script—fully hands‑off.


# ✅ Step 3: Containerization of the Python‐Redis Counter App:

Organized the app directory.

Wrote a Dockerfile based on python:3.9-slim that:

Installs system deps (gcc), Python deps, and copies the code

Exposes port 8000 and runs python app.py binding to 0.0.0.0

Built and tested locally (linking to a Redis container), then pushed the image to Docker Hub.

Confirmed the counter UI at: http://44.193.82.246:8000/

And Jenkins is accessible at: http://44.193.82.246:8080/

![p4](https://github.com/user-attachments/assets/fa93c6a5-065e-476d-b2ed-79d36b0b31f4)

![p5](https://github.com/user-attachments/assets/2bc0b66f-95d4-452f-a567-789994097cc8)


# ✅ Step 4: Grant EC2 Instance Access to EKS Cluster:

To allow the Terraform EC2 instance (e.g. a bastion or Jenkins server) to interact with the Amazon EKS cluster via kubectl, I followed these steps:

Created an IAM Role for EC2 with EKS Permissions: AmazonEKSClusterPolicy, AmazonEKSWorkerNodePolicy

Attached IAM Role to EC2 Instance

Ensure EC2 Instance Uses the IAM Role through: aws sts get-caller-identity

Updated kubeconfig and Tested Access through: aws eks update-kubeconfig --region us-east-1 --name devops-grad-eks, kubectl get nodes

![p8](https://github.com/user-attachments/assets/96aa2b63-cd1e-462b-994a-5eea2b28d9db)


# ✅ Step 5: CI/CD Pipeline with Jenkins for EKS Deployment:

✔️ Jenkinsfile Created to Automate the Pipeline:

A Jenkinsfile was written and committed to the application GitHub repository. It automates the following tasks based on branch logic:

1. Build & Push Docker Image to Amazon ECR

Used the docker CLI within the Jenkins pipeline to:

Authenticate with ECR

Build the Docker image using the Dockerfile

Tag the image using the ECR format:

378505040508.dkr.ecr.us-east-1.amazonaws.com/python-redis-counter:<git-commit-hash>

Push the tagged image to ECR

2. Deploy to EKS Based on Branch:
   
The pipeline dynamically determines the branch name:

For test → deploys to test namespace

For prod → deploys to prod namespace

Uses kubectl apply -f k8s/deployment.yaml after dynamically updating:

Namespace

Docker image tag

ENVIRONMENT variable (test or prod)

Response is confirmed using:

curl http://<load-balancer-dns>

Expected result:

"Hello from test" if deployed to test

"Hello from prod" if deployed to prod

![p9](https://github.com/user-attachments/assets/848c19b3-8898-477a-9f52-892563adbbe4)

![p10](https://github.com/user-attachments/assets/1a4aeb9a-8742-40a5-b351-a85d214cb22c)

![p11](https://github.com/user-attachments/assets/bc8389c0-b409-4b68-8b91-fc028e66b244)

![image](https://github.com/user-attachments/assets/7e532695-ac89-4965-be0c-ac1b9eae0943)


3. Environment Variables Passed via ConfigMap/Secret:
REDIS_HOST and ENVIRONMENT are injected through Kubernetes manifests:

Stored in ConfigMap and Secret YAMLs

Applied during deployment using kubectl apply

Redis host address is configurable and retrieved securely from Jenkins credentials.

4. Webhook Trigger Setup from GitHub:
Jenkins is configured to receive webhook events from GitHub:

Webhook configured at the repo level to trigger on:

push to test or prod branches

pull_request merged to test or prod

Jenkins GitHub plugin used to handle webhook events

Jenkins pipeline polling is disabled (webhooks only)

5. Secure Secret Management via Jenkins Credentials Store:
No credentials or secrets are hardcoded in the Jenkinsfile.

Instead, sensitive data (e.g., AWS credentials, Redis host) is retrieved using: withCredentials([usernamePassword(credentialsId: 'aws-creds', ...)])

Credentials added via: Jenkins dashboard → Manage Jenkins → Credentials → Global

Includes: 

AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

REDIS_HOST

ECR login credentials (if needed separately)


# 📊 Step 6: Monitoring and Visualization with Prometheus & Grafana:

1. Install Prometheus and Grafana via Helm

✅ Prometheus will automatically start scraping Kubernetes node and pod metrics.

✅ Grafana will be exposed via a LoadBalancer (get its external IP using kubectl get svc -n monitoring).

2. Access Grafana Dashboard

Access Grafana via browser: http://<EXTERNAL-IP>:80

Configure Data Source in Grafana

Navigate to Configuration → Data Sources

Choose Prometheus

URL: http://prometheus-server.monitoring.svc.cluster.local

Save & Test


4. Import Grafana Dashboards
   
📌 Dashboard 1: EKS Cluster Health and Resource Utilization

Import community dashboard:

Go to Dashboards → Import

Use ID 315 (Kubernetes Cluster Monitoring) or a similar EKS-compatible dashboard

This dashboard shows:

Node/pod health

CPU and memory usage

Pod restart counts

Cluster capacity and load

📌 Dashboard 2: Jenkins EC2 VM Monitoring

Install Node Exporter on Jenkins VM:

_ Update Prometheus config to scrape Jenkins VM

Import Node Exporter Dashboard:

Go to Grafana → Dashboards → Import

Use ID 1860 (Node Exporter Full)

Select data source as Prometheus











