# Terraform Book Review App on AWS

This project provisions and deploys a three-tier Book Review application on AWS using Terraform. The stack is designed to mirror a production-style layout rather than a single-VM demo: the frontend is exposed through a public Application Load Balancer, the backend is isolated behind an internal Application Load Balancer, and MySQL runs on Amazon RDS in private database subnets.

The goal of this project is not just to create AWS resources, but to practice thinking through network boundaries, service-to-service connectivity, bootstrapping, and troubleshooting across the full deployment path.

## What This Project Builds

Terraform in this folder creates:

- A custom VPC with CIDR `10.0.0.0/16`
- Two public subnets for the web tier across two Availability Zones
- Two private subnets for the app tier across two Availability Zones
- Two private subnets for the database tier across two Availability Zones
- An Internet Gateway and public routing for the web tier
- Two NAT Gateways so private app instances can install dependencies and reach external package registries
- A public ALB for the frontend
- An internal ALB for the backend API
- Auto Scaling Groups for both frontend and backend tiers
- Amazon RDS for MySQL with Multi-AZ enabled
- A read replica for the database tier
- Security groups that restrict traffic by tier
- A Terraform-generated SSH key for optional web-tier administration

## Architecture Overview

Traffic flows through the environment like this:

1. A user opens the public frontend ALB DNS in the browser.
2. The ALB forwards traffic to frontend EC2 instances in the public subnets.
3. Nginx on the frontend instances serves the Next.js app and proxies `/api/*` requests to the internal backend ALB on port `3001`.
4. The internal backend ALB forwards requests only to backend EC2 instances in private subnets.
5. The backend connects to the RDS primary instance in private database subnets.
6. A read replica is provisioned for database scalability and architecture practice.

This separation keeps the backend and database off the public internet while still making the application accessible through a single public entrypoint.
<img width="1536" height="1024" alt="ChatGPT Image Mar 27, 2026, 02_42_00 AM" src="https://github.com/user-attachments/assets/c421e5b5-460e-409e-ae54-5e0f587b3276" />


## Folder Layout

The repository layout for this project is:

- `README.md` - project overview, usage, validation, and troubleshooting guidance
- `REPORT.md` - short submission-oriented project report
- `bookreview-web-key.pem` - generated SSH key written locally after apply
- `terraform/versions.tf` - Terraform and provider version constraints
- `terraform/variables.tf` - input variables for networking, compute, database, and secrets
- `terraform/main.tf` - core AWS infrastructure and deployment resources
- `terraform/outputs.tf` - important output values such as the frontend ALB DNS and RDS endpoints
- `terraform/frontend_user_data.sh.tpl` - frontend bootstrap script, Next.js build, Nginx config, and systemd service setup
- `terraform/backend_user_data.sh.tpl` - backend bootstrap script, environment file creation, and systemd service setup
- `terraform/terraform.tfvars.example` - sample variable values you can copy into `terraform.tfvars`

Important: the Book Review application source is not stored in this folder. During instance bootstrap, both web and app tier instances clone the application from the GitHub repository defined by `repo_url`.

## Networking and Security Design

This stack intentionally uses tier-based network isolation:

- The web tier is public because it receives traffic from the internet through the frontend ALB.
- The app tier is private and only accepts port `3001` traffic from the internal backend ALB.
- The database tier is private and only accepts port `3306` traffic from the app tier.
- SSH access is limited by `admin_cidr_blocks`, which should be set to your own public IP range rather than `0.0.0.0/0`.

Security groups are defined to make the traffic path explicit:

- Frontend ALB SG: allows public HTTP
- Web SG: allows HTTP only from the frontend ALB and SSH only from admin CIDRs
- Backend ALB SG: allows port `3001` only from the web tier
- App SG: allows port `3001` only from the backend ALB
- DB SG: allows MySQL only from the app tier

## Deployment Behavior

The EC2 instances configure themselves with `user_data`.

Frontend instances:

- install Node.js, Git, Nginx, and build tools
- clone the Book Review repository into `/opt/book-review-app`
- build the Next.js frontend
- run the frontend with a `systemd` service on port `3000`
- use Nginx on port `80` as the public entrypoint
- proxy `/api/` requests to the internal backend ALB on port `3001`

Backend instances:

- install Node.js, Git, and build tools
- clone the same application repository into `/opt/book-review-app`
- write a `.env` file with the RDS and JWT configuration
- run the backend with a `systemd` service on port `3001`

This approach keeps the infrastructure declarative while still automating most of the application bootstrap.

## Prerequisites

Before running Terraform, make sure you have:

- Terraform installed
- AWS CLI configured with credentials that can create VPC, EC2, ALB, Auto Scaling, IAM-related dependencies, and RDS resources
- Access to an AWS region with enough quota for EC2, NAT gateways, ALBs, and RDS
- A safe value ready for `db_password`
- A safe value ready for `jwt_secret`

## How To Use

From the project root:

```bash
cd Week-10/terraform-bookreview/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update at least:

- `db_password`
- `jwt_secret`
- `admin_cidr_blocks`
- any instance sizing or CIDR values you want to change

Then run:

```bash
terraform init
terraform plan
terraform apply
```

After deployment, inspect the most useful outputs:

```bash
terraform output frontend_alb_dns
terraform output frontend_url
terraform output backend_alb_dns
terraform output rds_primary_endpoint
terraform output rds_replica_endpoint
terraform output web_ssh_private_key_path
```

## Recommended Variable Guidance

A few variables deserve extra attention:

- `admin_cidr_blocks`
  Use your own public IP with `/32`, for example `["203.0.113.10/32"]`, instead of opening SSH to the whole internet.
- `db_password`
  This should be a strong password because it becomes the RDS master password.
- `jwt_secret`
  Use a long random string, not a sample value.
- `repo_url`
  By default this points to the Book Review GitHub repository used for bootstrap.

## Verification Checklist

After `terraform apply` succeeds, validate the deployment in layers:

Infrastructure:

- `terraform output frontend_url`
- confirm the frontend ALB is reachable in the browser
- confirm the target groups show healthy instances in AWS
- confirm the RDS primary and replica are available

Frontend:

- homepage loads through the public ALB
- static assets load correctly
- Nginx serves on port `80`

Backend:

- API traffic is proxied through `/api/*`
- registration and login work from the frontend
- the backend is reachable only through the internal ALB, not from the public internet

Database:

- backend successfully connects to RDS
- reviews and user data persist in MySQL
- app behavior remains functional after instance restarts because services are managed by `systemd`

## Operational Notes

This project creates real cloud resources and can become expensive quickly. The main cost drivers are:

- NAT gateways
- Multi-AZ RDS
- the read replica
- ALBs
- multiple EC2 instances across both tiers

If you are running this as a learning environment, destroy resources as soon as you are done:

```bash
cd Week-10/terraform-bookreview/terraform
terraform destroy
```

Also remember that these files may contain sensitive local artifacts:

- `terraform/terraform.tfstate`
- `terraform/terraform.tfvars`
- `bookreview-web-key.pem`

Treat them as sensitive and avoid committing secrets into version control.

## Troubleshooting Notes

A few issues were important in this project and are worth documenting because they are the kinds of problems you run into in real deployments.

### 1. Read Replica Creation Error

When using `db_subnet_group_name` on the replica, AWS expects `replicate_source_db` to use the primary database ARN rather than the DB identifier.

### 2. Free Tier or Account Plan Restrictions

Some AWS account plans reject higher RDS backup retention settings. Lowering `backup_retention_period` to `1` allowed the primary DB to remain replica-compatible while fitting the account restriction.

### 3. Frontend Loads but Login Fails

A particularly instructive issue was when the frontend rendered correctly, but login and review actions failed. The root cause was not the backend code first, but the proxy path:

- Nginx on the frontend instances was forwarding `/api/` to the internal backend ALB without port `3001`
- the browser saw `504 Gateway Time-out`
- the fix was to proxy to `http://<internal-backend-alb>:3001`

This was a useful reminder that application issues often sit at the boundary between tiers rather than inside one service alone.

### 4. Healthy UI Does Not Guarantee Healthy Auth

Even when the homepage loads, authentication and review workflows still depend on:

- correct frontend API routing
- backend health checks passing
- RDS connectivity
- valid environment variables on the backend

The best debugging path was to verify one layer at a time instead of guessing from the browser alone.

## Submission Notes

If you are using this project for an assignment or portfolio submission, include:

- the cloud platform used: AWS
- your Terraform structure overview
- an architecture diagram
- the public frontend ALB DNS
- EC2 screenshots for web and app tiers
- RDS screenshots for primary and replica
- screenshots of the UI, login flow, and review flow

`REPORT.md` can be used as the starting point for that submission.

## Useful Commands

```bash
cd Week-10/terraform-bookreview/terraform
terraform fmt
terraform validate
terraform output frontend_url
terraform output backend_alb_dns
terraform output rds_primary_endpoint
```

If you need to inspect the generated SSH key path:

```bash
terraform output web_ssh_private_key_path
```

## Why This Project Matters

This project is valuable because it goes beyond provisioning isolated AWS resources. It ties together networking, bootstrapping, reverse proxying, internal load balancing, managed databases, service persistence, and debugging across tiers. That makes it much closer to a real deployment exercise than a single-instance infrastructure lab.
