# Book Review App AWS Deployment Report

## Cloud Platform Used

AWS

## Terraform Code Structure

- `versions.tf`: Terraform and provider declarations
- `variables.tf`: Input variables for network, compute, database, and secrets
- `main.tf`: VPC, subnets, route tables, NAT, ALBs, Auto Scaling Groups, and RDS resources
- `outputs.tf`: Public frontend ALB DNS and important service endpoints
- `frontend_user_data.sh.tpl`: Frontend bootstrap and Nginx reverse proxy setup
- `backend_user_data.sh.tpl`: Backend bootstrap and systemd setup

## Architecture Diagram

```mermaid
flowchart TB
  Internet --> PublicALB[Public ALB]
  PublicALB --> Web1[Frontend EC2 AZ1]
  PublicALB --> Web2[Frontend EC2 AZ2]
  Web1 --> InternalALB[Internal ALB]
  Web2 --> InternalALB
  InternalALB --> App1[Backend EC2 AZ1]
  InternalALB --> App2[Backend EC2 AZ2]
  App1 --> RDSPrimary[(RDS MySQL Primary Multi-AZ)]
  App2 --> RDSPrimary
  RDSPrimary --> RDSReplica[(RDS Read Replica)]
```

## Public Load Balancer DNS

Run:

```bash
terraform output frontend_alb_dns
```

## Submission Evidence Checklist

- EC2 dashboard showing frontend and backend instances
- RDS dashboard showing primary plus read replica
- Browser screenshot of the frontend via the public ALB DNS
- Working login/review flow screenshot
- Optional logs from frontend/backend systemd services