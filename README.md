# Konecta-Project

# Konecta-Graduation-Project

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








