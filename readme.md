# DevOps Graduation Project

## Docker & Docker Compose

The app is containerized using **Docker** and configured for local development with **Docker Compose**.

### Project Structure

```
iVolveGraduationProject/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   ├── static/
│   └── templates/
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### Dockerfile (Multi-Stage)

```dockerfile
# Build dependencies
FROM python:3.11-slim AS builder
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --upgrade pip && pip install --user -r requirements.txt

# Runtime image
FROM python:3.11-slim
WORKDIR /app
COPY app/ .
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
EXPOSE 5000
CMD ["python", "app.py"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  flask-app:
    build:
      context: .
      dockerfile: Dockerfile
    image: mnagy156/flask-app:latest
    ports:
      - "5000:5000"
    volumes:
      - ./app:/app
    environment:
      - FLASK_ENV=development
      - FLASK_APP=app.py
    command: python app.py
```

### Run Locally

```bash
docker-compose up --build
```

Access: [http://localhost:5000](http://localhost:5000)

### Docker Hub

To publish the image:

```bash
docker login
docker-compose build
docker push zhdmra/flask-app:latest
```

## Kubernetes Deployment

The app is deployed on a local Kubernetes cluster (Minikube) with custom YAML manifests.

### Manifests Location

```
k8s/
├── namespace.yaml
├── deployment.yaml
└── service.yaml
```

### Deployment Steps

1. **Start Minikube**

```bash
minikube start
```

2. **Use Minikube’s Docker & Build Image**

```bash
eval $(minikube docker-env)
docker build -t ivolve-app:latest .
```

3. **Apply Kubernetes Manifests**

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/ -n ivolve
```

4. **Access the App**

```bash
minikube service ivolve-service -n ivolve
```

**Output example:**

```
http://192.168.49.2:30007
```

### Notes

- `imagePullPolicy: Never` is used to run locally built images in Minikube.
- Pod and service are deployed in the custom namespace `ivolve`.

## Infrastructure Provisioning with Terraform

The project includes Terraform scripts to provision AWS infrastructure needed to run the Jenkins CI server and related network resources.

### Terraform Directory Structure

```
terraform/
├── backend.tf                # S3 backend configuration
├── main.tf                   # Root module calling child modules
├── variables.tf              # Root variables file
├── outputs.tf                # Root outputs for key resource data
├── modules/
│   ├── network/              # VPC, Subnet, Internet Gateway, Network ACL
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── server/               # EC2 instance, Security Group
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

### Features

- Modular design separating network and server resources
- VPC with a public subnet, internet gateway, and network ACL configured to allow inbound SSH and ports 80, 443, 8080, 4000, 5000
- EC2 instance for Jenkins with security group allowing required ports
- State management using S3 backend (no DynamoDB locking to stay within AWS free tier)
- CloudWatch monitoring enabled on EC2 instance
- Resource tagging and variable-driven customization

### Usage

1. Update `terraform/terraform.tfvars` with your AWS region, key pair name, AMI ID, and CIDR blocks.

2. Initialize Terraform:

```bash
terraform init -reconfigure -var-file="terraform.tfvars"
```

3. Preview planned changes:

```bash
terraform plan -var-file="terraform.tfvars"
```

4. Apply infrastructure provisioning:

```bash
terraform apply -var-file="terraform.tfvars"
```

5. Get Jenkins EC2 public IP after apply:

```bash
terraform output jenkins_public_ip
```

6. SSH to Jenkins server using the output IP and your private key.

### Notes

- DynamoDB state locking is disabled to avoid AWS costs; avoid concurrent Terraform runs.
- Tested on a non-production AWS account.
- Tags applied to all resources for better management.

## Configuration Management with Ansible

Ansible is used for provisioning and configuring the Jenkins server.

### Task Objectives

- Deliver Ansible playbooks for EC2 instance configuration:
  - Install required packages (Git, Docker, Java).
  - Install Jenkins.
  - Use Ansible roles.
  - Support both static and dynamic inventory.
- Commit Ansible configuration and modules to the repository.

### Approach

1. **Inventory Configuration**

   - Start with static inventory (`static_hosts.ini`).
   - Transition to dynamic inventory with AWS EC2 plugin (`aws_ec2.yaml`).

2. **Role Structure**

```
ansible/
├── inventory/
│   ├── static_hosts.ini
│   └── aws_ec2.yaml
├── roles/
│   ├── base-setup/               # Installs git, curl, unzip, etc.
│   ├── docker-installation/      # Installs Docker engine
│   └── jenkins-installation/     # Installs and configures Jenkins
└── site.yml                      # Main playbook including all roles
```

3. **Playbook Execution**

```bash
ansible-playbook -i inventory/static_hosts.ini site.yml --check
ansible-playbook -i inventory/static_hosts.ini site.yml
```

4. **Verify Installation**

After running the playbook, SSH into the EC2 instance and verify that everything is installed correctly:

```bash
ssh -i ~/<Your-key-location> ec2-user@<EC2_PUBLIC_IP>
java -version && docker --version && docker-compose --version && systemctl status jenkins --no-pager
```

5. **Best Practices & Optimizations**
   - Roles initialized using `ansible-galaxy init`.
   - Tags used for selective execution: `--tags base,docker,jenkins`.
   - Handlers implemented to restart services when needed.

---


## 6. Continuous Deployment with ArgoCD (GitOps)

### Task

Implement GitOps practices using **ArgoCD** to automate application deployment directly from the Git repository.

### How It Works

- **Continuous Monitoring:** ArgoCD continuously monitors the Git repository for any changes to Kubernetes manifests (YAML files).
- **Automated Sync:** On detecting a change (new commit or PR merge), ArgoCD automatically syncs the updated configuration into the Kubernetes cluster.
- **State Consistency:** Ensures the live cluster state always matches the declared state in Git.
- **Visibility & Control:** Provides a web UI and CLI for monitoring application health, sync status, and performing rollbacks.

### How to Apply

Deploy the ArgoCD Application manifest:

```bash
kubectl apply -f argocd/app-argocd.yaml
```

### Outcome

- **Fully automated Git-driven deployments** without manual `kubectl apply`.
- **Version-controlled deployments** — rollbacks can be done by reverting Git commits.
- **Real-time visibility** of application health and sync status via the ArgoCD dashboard.
- **Git as the single source of truth** for Kubernetes workloads.

---

## Technologies Used

- **Terraform:** Provisioned AWS infrastructure (VPC, Subnets, EC2, IAM, S3, DynamoDB, CloudWatch).
- **Ansible:** Automated server configuration using dynamic inventory and playbooks.
- **Jenkins:** Continuous Integration pipeline with Master/Agent architecture and Groovy Shared Libraries.
- **Docker:** Containerized microservices for consistent runtime environments.
- **Kubernetes (EKS/Local):** Orchestration for scaling, service discovery, and self-healing workloads.
- **ArgoCD:** Continuous Deployment via GitOps, enabling automated sync and rollback from Git.
- **AWS:** Cloud provider for compute, networking, monitoring, and storage services.

---
**Maintained by Mohamed Nagy**

