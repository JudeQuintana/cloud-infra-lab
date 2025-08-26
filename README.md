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
Without RDS Proxy (default)
  - If you're getting the following error for both `/app1` and `/app2` after applying, then something went wrong on the AWS side (I think).
    - Try the destroy process and re-build (terraform apply again).
    - This happens rarely but it does come up.
```
ERROR 1045 (28000): Access denied for user 'admin'@'10.0.8.147' (using password: YES)
```

![cloud-infra-lab-without-rds-proxy](https://jq1-io.s3.us-east-1.amazonaws.com/projects/cloud-infra-lab-without-rds-proxy.png)

With RDS PROXY
  - To experiment with RDS Proxy change `var.enable_rds_proxy` ([variables.tf](https://github.com/JudeQuintana/cloud-infra-lab/blob/main/variables.tf#L27) to `true`.
  - If you're getting the following error for `/app1` when RDS Proxy is enabled it's because AWS is waiting until the proxy default target group's status becomes "Available".
    - It will eventually (3-5min+) come online by itself.
```
ERROR 2013 (HY000): Lost connection to MySQL server at 'handshake: reading initial communication packet', system error: 11
```

![cloud-infra-lab-with-rds-proxy](https://jq1-io.s3.us-east-1.amazonaws.com/projects/cloud-infra-lab-with-rds-proxy.png)

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
  - `aws rds modify-db-instance --db-instance-identifier test-app-primary --no-deletion-protection --apply-immediately --region us-west-2`
- Destroy resources:
  - `terraform destroy`
  - note: vpcs will take 10-15min to destroy due to IPAM taking a long
    time to release the IP.
- Force delete the secrets manager path instead of waiting for scheduled deletion:
  - `aws secretsmanager delete-secret --region us-west-2 --secret-id rds/test/mysql/app --force-delete-without-recovery --region us-west-2`
- Delete snapshot that was created when destroying the DB.
  - `aws rds delete-db-snapshot --db-snapshot-identifier test-app-primary-final-snapshot --region us-west-2`

## Endpoints
Health Check:
- `https://cloud.some.domain/` -> `NGINX Health: OK: MaD GrEEtz! #End2EndBurner`

RDS Connectivity Checks:
- `https://cloud.some.domain/app1` -> `App1: MySQL Primary OK (via RDS Proxy: false) or MySQL Primary ERROR`
- `https://cloud.some.domain/app2` -> `App2: MySQL Read Replica OK (bypassing RDS Proxy) or MySQL Read Replica ERROR`

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
- The boolean to auto deploy instance refresh using latest launch template version after the launch template is modified (default is `true`).
  - The config prioritizes availability (launch before terminate) over cost control (terminate before launch).
  - Only one instance refresh can be run at a time but will cancel any.
    in progress instance refresh if another instance refresh is started.
  - View in progress instance refreshes with `aws autoscaling describe-instance-refreshes --auto-scaling-group-name test-web-asg --region us-west-2`.
  - Current demo configuration will take up to 10min for a refresh to finish, manually cancel or start another instance refresh (auto cancel).

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
- RDS Proxy: is for scaling connections and managing failover smoother.
  - A `db.t3.micro` RDS DB instance itself costs only about $15–20/month (depending on region, reserved vs. on-demand).
    - RDS Proxy billing is per vCPU-hour of the underlying DB instance(s)
    - Rate: $0.015 per vCPU-hour (us-west-2) -> 2 vCPUs × $0.015 × 730 hrs ≈ $21.90 / month.
    - That means the proxy can actually cost as much as, or more than, the tiny database itself.
  - Using RDS Proxy in front of a `db.t3.micro` is usually overkill unless you absolutely need connection pooling (ie you’re hitting it with Lambdas). For small/steady workloads with a few long-lived connections (ie web apps on EC2s).
    It’s better to skip proxy. The cost/benefit only makes sense once you’re on larger instance sizes or serverless-heavy patterns.
  - The RDS proxy can be toggled via `var.enable_rds_proxy` ([variables.tf](https://github.com/JudeQuintana/cloud-infra-lab/blob/main/variables.tf#L27) boolean value (default is `false`).
    - This will demonstrate easily spinning up or spinning up an RDS proxy when scaling connections is needed or for experimenting with RDS Proxy
  - Module Implemention:
    - IAM roles and policies for access to Secrets Manager MYSQL secrets.
    - Access to the primary is through the RDS Proxy to take advantage of DB pooling and failover benefits.
    - Access to the read replica bypasses the RDS Proxy.
      - RDS proxy doesnt support read only endpoints for DB instances (cheap HA), only RDS clusters (more expensive) and therefore read replica instance access bypasses the RDS proxy with nodb pooling and failover benefits.

Security Groups:
- Fine-grained rules for ALB ↔ EC2 ↔ RDS Proxy ↔ RDS.
  - And ALB ↔ EC2 ↔ RDS Proxy ↔ RDS for the rds bypass to read replica.
- Outbound rules configured for necessary security groups.

Scaling Behavior:
- Scale Out: if average CPU > 70% for 2 minutes.
- Scale In: if average CPU < 30% for 2 minutes.
- Policies managed via CloudWatch alarms + ASG.

VPC:
- Requires IPAM.
- Uses Tiered VPC-NG module.
- Currenlty utilizing 2 AZs but more can be added.
- Has a VPC Endpoint for sending s3 traffic direct to s3 instead of traversing IGW or NATGW.
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

