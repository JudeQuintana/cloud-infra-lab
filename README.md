# Cloud Infra Lab
```
     ____.             ________        ________
    |    |____  ___.__.\_____  \       \_____  \   ____   ____
    |    \__  \<   |  | /  / \  \       /   |   \ /    \_/ __ \
/\__|    |/ __ \\___  |/   \_/.  \     /    |    \   |  \  ___/
\________(____  / ____|\_____\ \_/_____\_______  /___|  /\___  >
              \/\/            \__>_____/       \/     \/     \/

--=[ PrEsENtZ ]=--

--=[ 🚀 Cloud Infra Lab: Scalable ALB + ASG + NGINX + RDS Setup ]=--

--=[ Provision a complete AWS stack using Terraform ]=--

--=[ #StayUp ]=--
```

First time using ChatGPT to assist my AWS and Terraform knowledge in building and troubleshooting a small, scalable yet extendable, cloud project for learning purposes.

![cloud-infra-lab](https://jq1-io.s3.us-east-1.amazonaws.com/projects/cloud-infra-lab.png)

### Build
- `terraform init`
- `terraform apply`
- profit!

Tear Down:
- `terraform destroy`
- `aws secretsmanager delete-secret --region us-west-2 --secret-id
  rds/mysql/app  --force-delete-without-recovery`
- `aws rds delete-db-snapshot --db-snapshot-identifier app-mysql-final-snapshot`


### Endpoints
- Health Check:
  - `https://cloud.jq1.io/` -> `Health: OK: MaD GrEEtz!`

- RDS Connectivity Checks:
  - `https://cloud.jq1.io/app1` -> `App1: MySQL OK (or MySQL Error)`
  - `https://cloud.jq1.io/app2` -> `App2: MySQL OK (or MySQL Error)`

- Change `dns_zone` and `domain_name` local variables in `alb.tf` accordingly.

### Components
- Application Load Balancer (ALB)
  - HTTPS (TLS 1.2 & 1.3) with ACM
  - Path-based routing: /app1, /app2

- Auto Scaling Group (ASG)
  - EC2 instances with cloud-init & socat health endpoints
  - Scales based on CPU utilization
  - Deployed across multiple AZs

- NGINX reverse proxy + Socat Health Checks
  - /app1 and /app2 return MySQL health
  - Uses socat for reliable TCP responses
  - Lightweight bash scripts to simulate apps
  - mysql -e "SELECT 1" run with credentials pulled from Secrets Manager

- Amazon RDS (MySQL)
  - Multi-AZ with encryption via custom KMS key
  - Access controlled by SGs (only from ASG instances)

- Security Groups
  - Fine-grained rules for ALB ↔ EC2 ↔ RDS
  - Outbound rules configured for necessary security groups

- Scaling Behavior
  - Scale Out: if average CPU > 70% for 2 minutes
  - Scale In: if average CPU < 30% for 2 minutes
  - Policies managed via CloudWatch alarms + ASG

- Secure Practices
  - Secrets (MySQL creds) stored in AWS Secrets Manager
  - TLS via ACM + ELBSecurityPolicy-TLS13-1-2-2021-06
  - RDS encrypted with custom KMS CMK

- VPC S3 Endpoint
  - S3 Gateway for sending s3 traffic direct to s3 instead of traversing
    IGW or NATGW.

### TODO
- add IPAM and VPC configuration
- modularize:
  - `alb.tf`
  - `asg.tf`
  - `rds.tf`
