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

## Intro
First time using ChatGPT to assist my AWS and Terraform knowledge in building and troubleshooting a small, cheap yet scalable, cloud project end-to-end for learning purposes.

Beginner to intermediate level.

Enjoy!

## Architecture
![cloud-infra-lab](https://jq1-io.s3.us-east-1.amazonaws.com/projects/cloud-infra-lab-rds-proxy.png)

## Prerequisites
AWS:
- `aws` cli installed and configured with an AWS account.

Zone and Domain:
- AWS Route53 zone resource should already exist (either manually or in Terraform).
  - Must own the DNS zone via some domain registrar with the DNS servers pointed to the Route53 zone name servers.
  - Demo will look up the zone resource by name.
- Change the `zone_name` variable in [variables.tf](https://github.com/JudeQuintana/cloud-infra-lab/blob/main/variables.tf#L21) to your own zone.
  - The `cloud.some.domain` DNS record will be created from the `var.zone_name` (ie. `var.zone_name = "jq1.io"` -> `output.url = "https://cloud.jq1.io"`)
  - Demo is not configured for an apex domain at this time.

IPAM Configuration:
- There are many ways to configure IPAM so I manually created IPAM pools (advanced tier) in the AWS UI.
- You'll need to configure your own IPv4 pools/subpools in IPAM.
  - Demo will look up the IPAM pools via filter on description and ipv4 type.
- Advanced Tier IPAM in `us-west-2` operating reigons.
  - No IPv4 regional pools at the moment.
  - `us-west-2` (ipam locale)
    - IPv4 Pool (private scope)
      - Description: `ipv4-test-usw2`
      - Provisioned CIDRs:
        - `10.0.0.0/18`

## Begin Demo
Build:
- `terraform init`
- `terraform apply` (takes a few minutes for asg instances to finish spinning up once apply is complete)
- profit!

Tear Down:
- Remove RDS deletion protection:
  - `aws rds modify-db-instance --db-instance-identifier test-app-mysql --no-deletion-protection --apply-immediately --region us-west-2`
- Destroy resources:
  - `terraform destroy`
  - note: vpcs will take 10-15min to destroy due to IPAM taking a long
    time to release the IP.
- Force delete the secrets manager path instead of waiting for scheduled deletion:
  - `aws secretsmanager delete-secret --region us-west-2 --secret-id rds/test/mysql/app --force-delete-without-recovery --region us-west-2`
- Delete snapshot that was created when destroying the DB.
  - `aws rds delete-db-snapshot --db-snapshot-identifier test-app-mysql-final-snapshot --region us-west-2`

## Endpoints
Health Check:
- `https://cloud.some.domain/` -> `NGINX Health: OK: MaD GrEEtz! #End2EndBurner`

RDS Connectivity Checks:
- `https://cloud.some.domain/app1` -> `App1: MySQL Primary OK (via RDS Proxy) or MySQL Primary Error`
- `https://cloud.some.domain/app2` -> `App2: MySQL Read Replica OK (bypassing RDS Proxy) or MySQL Read Replica Error`

Modularize (OO style):
- `alb.tf`
- `asg.tf`
- `rds.tf`
- `rds_proxy.tf`

## Components
Application Load Balancer (ALB):
- HTTPS (TLS 1.2 & 1.3 termination).
- ACM + ELBSecurityPolicy-TLS13-1-2-2021-06.
- HTTP to HTTPS Redirects.

Auto Scaling Group (ASG):
- EC2 instances with cloud-init & socat health endpoints.
  - using Mariadb as the MYSQL client.
- Scales based on CPU utilization.
- Deployed across multiple AZs.
- Instances can spin up without a NATGW because there's an S3 gateway.
  - This is because Amazon Linux 2023 AMI uses S3 for the yum repo.
  - If you plan on using NATGWs for the ASG instances when modifying the cloud-init script then set `natgw = true` (on public subnet per Az) and you'll need to add an egress security group rule to the instances security group.
- It's difficult to test scale-out with no load testing scripts (at the moment) but you can test the scale-in by selecting a desired capacity of 6 and watch the asg terminate unneeded instance capacity down back to 2.
- Boolean to auto deploy instance refresh using latest launch template version after the launch template user_data or image_id is modified.
  - The config prioritizes availability (launch before terminate) over cost control (terminate before launch).
  - Only one instance refresh can be run at a time or it will error.
  - View in progress instance refreshes with `aws autoscaling describe-instance-refreshes --auto-scaling-group-name test-web-asg --region us-west-2`.
  - Current demo configuration will take up to 10min for a refresh to finish or manually cancel.

NGINX reverse proxy + Socat Health Checks:
- Path-based routing: /app1, /app2.
- /app1 returns primary db health.
- /app2 returns read replica db health.
- Uses socat for reliable TCP responses.
- Lightweight bash scripts to simulate apps.
- mysql -e "SELECT 1" run with credentials pulled from Secrets Manager.

Amazon RDS (MySQL):
- Primary DB Instance with Multi-AZ and encryption via KMS.
- Read Replica DB Instance (Intra-region and Multi-AZ).
- Access controlled by SGs (only from ASG instances to RDS Proxy, and
  ASG instances to RDS directly).
- Secrets (MySQL creds) stored in AWS Secrets Manager.
- RDS Proxy: acts like a smart middle layer between your app and RDS, helping with scalability, availability, and security without your app having to change how it queries the database.
  - IAM roles and policies for access to Secrets Manager MYSQL secrets.
  - Access to the primary is through the RDS Proxy to take advantage of DB pooling and failover benefits.
  - Access to the read replica bypasses the RDS Proxy.
    - RDS proxy doesnt support read only endpoints for DB instances (cheap), only RDS clusters (more expensive) and therefore read replica instance access bypasses the RDS proxy with nodb pooling and failover benefits.

Security Groups:
- Fine-grained rules for ALB ↔ EC2 ↔ RDS Proxy ↔ RDS.
  - And ALB ↔ EC2 ↔ RDS Proxy ↔ RDS for the rds bypass to read replica.
- Outbound rules configured for necessary security groups.

Scaling Behavior:
- Scale Out: if average CPU > 70% for 2 minutes.
- Scale In: if average CPU < 30% for 2 minutes.
- Policies managed via CloudWatch alarms + ASG.

VPC:
- Uses Tiered VPC-NG module.
- Requires IPAM.
- VPC Endpoint for sending s3 traffic direct to s3 instead of traversing IGW or NATGW.
- Using isolated subnets for db subnets for future use when scaling VPCs in a Centralized Router (TGW hub and spoke).
  - It will make it easier for db connections to be same VPC only so other intra region VPCs cant connect when full mesh TGW routes exist.
  - example: [Centralized Egress Demo](https://github.com/JudeQuintana/terraform-main/tree/main/centralized_egress_dual_stack_full_mesh_trio_demo)

## ✅ Pros and ❌ Cons of using a reverse proxy to access MySQL (according to ChatGPT)
Advantages:
- Horizontal scalability.
  - ASG lets you scale NGINX nodes based on CPU, connections, etc.
- Managed ingress.
  - ALB handles TLS termination, health checks, and routing to NGINX instances cleanly.
- Separation of concerns.
  - NGINX handles HTTP logic (e.g., authentication, load balancing), MySQL stays private.
- Custom routing logic.
  - You can implement advanced logic like conditional proxying, auth, throttling, etc.
- Can front many apps.
  - One NGINX can proxy to multiple backends, including MySQL-checking microservices.

Limitations:
- NGINX is not a MySQL proxy.
  - NGINX is built for HTTP, not stateful MySQL TCP connections.
  - You cannot proxy raw MySQL traffic through NGINX.
- Unnecessary complexity.
  - If just connecting to MySQL from backend apps, NGINX is likely overkill.
- Extra latency.
  - Adds a hop: ALB → NGINX → app → MySQL.
  - This could slightly slow down reads/writes if not designed carefully.
- Scaling not tied to DB load
  - Scaling NGINX does not help with MySQL bottlenecks unless your NGINX is doing significant compute (auth, caching, etc.).
- Maintains state poorly.
  - MySQL connections are long-lived and stateful, not ideal for stateless NGINX workers.
- Not resilient to MySQL issues.
  - If MySQL becomes slow/unavailable, NGINX becomes a bottleneck or fails with 5xx unless you explicitly handle those errors.

