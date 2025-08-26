data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  # demonstrating pulling from secretsmanager
  # should use readonly creds instead of using admin creds to access the primary and read replica db's but used here for demo purposes
  secretsmanager_mysql = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)

  cloud_init = base64encode(<<-CLOUD_INIT
    #cloud-config
    package_update: true
    packages:
      - mariadb105
      - nginx
      - socat

    runcmd:
      - echo 'export MYSQL_PRIMARY_HOST="${local.secretsmanager_mysql.primary_host}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_READ_REPLICA_HOST="${local.secretsmanager_mysql.read_replica_host}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_PORT="${local.secretsmanager_mysql.port}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_USERNAME="${local.secretsmanager_mysql.username}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_PASSWORD="${local.secretsmanager_mysql.password}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_DB_NAME="${local.secretsmanager_mysql.db_name}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_TIMEOUT="${local.secretsmanager_mysql.timeout}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_RDS_PROXY="${var.enable_rds_proxy}"' >> /etc/profile.d/app_env.sh

      - |
        cat > /usr/local/bin/app1_handler.sh <<'EOF'
        #!/bin/bash
        source /etc/profile.d/app_env.sh
        ERROR_OUTPUT=$(mysql -h "$MYSQL_PRIMARY_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" -e "SELECT 1;" --init-command="SET SESSION wait_timeout=$MYSQL_TIMEOUT" --ssl "$MYSQL_DB_NAME" 2>&1)

        if [ $? -eq 0 ]; then
        printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nApp 1: MySQL Primary OK (via RDS Proxy: $MYSQL_RDS_PROXY)"
        else
          printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nApp 1: MySQL Primary (via RDS Proxy: $MYSQL_RDS_PROXY) ERROR:\n$ERROR_OUTPUT"
        fi
        EOF

      - |
        cat > /usr/local/bin/app2_handler.sh <<'EOF'
        #!/bin/bash
        source /etc/profile.d/app_env.sh
        ERROR_OUTPUT=$(mysql -h "$MYSQL_READ_REPLICA_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" -e "SELECT 1;" --init-command="SET SESSION wait_timeout=$MYSQL_TIMEOUT" --ssl "$MYSQL_DB_NAME" 2>&1)

        if [ $? -eq 0 ]; then
          printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nApp 2: MySQL Read Replica OK"
        else
          printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nApp 2: MySQL Read Replica ERROR:\n$ERROR_OUTPUT"
        fi
        EOF

      - |
        cat > /usr/local/bin/app1.sh <<'EOF'
        #!/bin/bash
        socat TCP-LISTEN:8081,reuseaddr,fork EXEC:"/usr/local/bin/app1_handler.sh"
        EOF

      - |
        cat > /usr/local/bin/app2.sh <<'EOF'
        #!/bin/bash
        socat TCP-LISTEN:8082,reuseaddr,fork EXEC:"/usr/local/bin/app2_handler.sh"
        EOF

      - chmod +x /usr/local/bin/app1_handler.sh /usr/local/bin/app2_handler.sh
      - chmod +x /usr/local/bin/app1.sh /usr/local/bin/app2.sh
      - nohup /usr/local/bin/app1.sh > /var/log/app1.log 2>&1 &
      - nohup /usr/local/bin/app2.sh > /var/log/app2.log 2>&1 &

      - |
        cat > /etc/nginx/nginx.conf <<'EOF'
        user nginx;
        worker_processes auto;
        error_log /var/log/nginx/error.log;
        pid /run/nginx.pid;

        events {
          worker_connections 1024;
        }

        http {
          include       /etc/nginx/mime.types;
          default_type  text/plain;
          keepalive_timeout  60;

          server {
            listen 0.0.0.0:80;

            location /app1 {
              proxy_pass http://localhost:8081;
            }

            location /app2 {
              proxy_pass http://localhost:8082;
            }

            location / {
              return 200 "NGINX Health: OK: MaD GrEEtz! #End2EndBurner";
            }
          }
        }
        EOF
      - systemctl enable nginx
      - systemctl restart nginx
  CLOUD_INIT
  )
}

# It's difficult to test scale-out with no load testing scripts (at the moment) but you can test the scale-in by selecting a desired capacity of 6 and watch the asg terminate unneeded instance capacity down back to 2.
# will launch with initial desired_capacity value but any updates will be ignored so that the sale in and scale out alarms takeover
# uncomment lifecyle ignore changes for desired_capacity in the asg resource in the asg module.
module "asg" {
  source = "./modules/asg"

  env_prefix = var.env_prefix
  asg = {
    name               = "web"
    min_size           = 2
    max_size           = 8
    desired_capacity   = 2
    ami                = data.aws_ami.al2023
    instance_type      = "t2.micro"
    user_data          = local.cloud_init
    alb                = module.alb
    security_group_ids = [aws_security_group.instance_sg.id]
    subnet_ids = [
      lookup(local.app_vpc.private_subnet_name_to_subnet_id, "proxy1"),
      lookup(local.app_vpc.private_subnet_name_to_subnet_id, "proxy2")
    ]
  }
}

