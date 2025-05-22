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

--=[ #StayUp | #End2EndBurner ]=--
```

### Intro
First time using ChatGPT to assist my AWS and Terraform knowledge in building and troubleshooting a small, scalable yet extendable, cloud project end-to-end for learning purposes. ENJOY!

### Architecture
![cloud-infra-lab](https://jq1-io.s3.us-east-1.amazonaws.com/projects/cloud-infra-lab.png)

### Pre-reqs
AWS:
- `aws` cli installed and configured.

Zone and Domain:
- Must own the zone via domain registrar.
  - AWS zone resource should already exist (either manually or in Terraform).
  - Demo looks up the zone resource.
- Change the `zone_name` local variable in [alb.tf](https://github.com/JudeQuintana/cloud-infra-lab/blob/daca206af682d7cd9216eefbf9281c1c4cacec5e/alb.tf#L2) to your own zone.

IPAM Configuration:
- There are many ways to configure IPAM so I manually created IPAM pools (advanced tier) in the AWS UI.
- You'll need to configure your own IPv4 pools/subpools in IPAM.
- Advanced Tier IPAM in `us-west-2` operating reigons.
  - In this demo, ipam pools for all locales are managed in the `us-west-2` region.
  - No IPv4 regional pools at the moment.
  - `us-west-2` (ipam locale)
    - IPv4 Pool (private scope)
      - Description: `ipv4-test-usw2`
      - Provisioned CIDRs:
        - `10.0.0.0/18`

### Begin Demo
Build:
- `terraform init`
- `terraform apply`
- profit!

Tear Down:
- Remove RDS deletion protection:
  - `aws rds modify-db-instance --db-instance-identifier app-mysql --no-deletion-protection --apply-immediately --region us-west-2`
- Destroy resources:
  - `terraform destroy`
  - note: vpcs will take 10-15min to destroy due to IPAM taking a long
    time to release the IP.
- Force delete the secrets manager path instead of waiting for scheduled deletion:
  - `aws secretsmanager delete-secret --region us-west-2 --secret-id rds/test/mysql/app --force-delete-without-recovery --region us-west-2`
- Delete snapshot that was created when destroying the DB.
  - `aws rds delete-db-snapshot --db-snapshot-identifier app-mysql-final-snapshot --region us-west-2`

### Endpoints
Health Check:
- `https://cloud.some.domain/` -> `Health: OK: MaD GrEEtz!`

RDS Connectivity Checks:
- `https://cloud.some.domain/app1` -> `App1: MySQL OK (or MySQL Error)`
- `https://cloud.some.domain/app2` -> `App2: MySQL OK (or MySQL Error)`

### TODO
Modularize (OO style):
- `alb.tf`
- `asg.tf`
- `rds.tf`

### Components
Application Load Balancer (ALB):
- HTTPS (TLS 1.2 & 1.3) with ACM.
- Path-based routing: /app1, /app2.

Auto Scaling Group (ASG):
- EC2 instances with cloud-init & socat health endpoints.
- Scales based on CPU utilization.
- Deployed across multiple AZs.

NGINX reverse proxy + Socat Health Checks:
- /app1 and /app2 return MySQL health.
- Uses socat for reliable TCP responses.
- Lightweight bash scripts to simulate apps.
- mysql -e "SELECT 1" run with credentials pulled from Secrets Manager.

Amazon RDS (MySQL):
- Multi-AZ with encryption via custom KMS key.
- Access controlled by SGs (only from ASG instances).

Security Groups:
- Fine-grained rules for ALB ↔ EC2 ↔ RDS.
- Outbound rules configured for necessary security groups.

Scaling Behavior:
- Scale Out: if average CPU > 70% for 2 minutes.
- Scale In: if average CPU < 30% for 2 minutes.
- Policies managed via CloudWatch alarms + ASG.

Secure Practices:
- Secrets (MySQL creds) stored in AWS Secrets Manager.
- TLS via ACM + ELBSecurityPolicy-TLS13-1-2-2021-06.
- RDS encrypted with custom KMS CMK.

VPC:
- Uses Tiered VPC-NG module.
- Requires IPAM.
- VPC Endpoint for sending s3 traffic direct to s3 instead of traversing IGW or NATGW.

