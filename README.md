# Terraform Book Review App on AWS

This project provisions a three-tier AWS deployment for the Book Review application using Terraform.

## Architecture

- Custom VPC: `10.0.0.0/16`
- 2 public subnets for the web tier
- 2 private subnets for the app tier
- 2 private subnets for the database tier
- Public Application Load Balancer for the Next.js frontend
- Internal Application Load Balancer for the Node.js backend
- Auto Scaling Groups for both tiers (2 instances each)
- Amazon RDS for MySQL with Multi-AZ enabled
- Read replica for the database tier
- NAT gateways for private app-tier outbound access

## Folder Structure

- `versions.tf`
- `variables.tf`
- `main.tf`
- `outputs.tf`
- `frontend_user_data.sh.tpl`
- `backend_user_data.sh.tpl`
- `terraform.tfvars.example`
- `REPORT.md`
- `book-review-app/` cloned application source

## Usage

```bash
cd Week-10/terraform-bookreview
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

After apply, use:

```bash
terraform output frontend_alb_dns
terraform output frontend_url
terraform output rds_primary_endpoint
```

## Notes

- This stack creates real AWS resources and can incur significant cost, especially NAT gateways, Multi-AZ RDS, and a read replica.
- The web tier instances have a generated PEM key for optional administration. The app tier instances remain private.
- The frontend is exposed through the public ALB. The backend is only reachable internally through the internal ALB.