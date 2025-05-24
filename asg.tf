data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  # demonstrating pulling from secretsmanager
  # should use readonly creds instead of using admin creds to access the db but used here for demo purposes
  secretsmanager_mysql_creds = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)
  mysql = {
    host    = lookup(local.secretsmanager_mysql_creds, "host")
    port    = lookup(local.secretsmanager_mysql_creds, "port")
    user    = lookup(local.secretsmanager_mysql_creds, "username")
    pass    = lookup(local.secretsmanager_mysql_creds, "password")
    db      = lookup(local.secretsmanager_mysql_creds, "db_name")
    timeout = lookup(local.secretsmanager_mysql_creds, "timeout")
  }

  cloud_init = base64encode(<<-CLOUD_INIT
    #cloud-config
    package_update: true
    packages:
      - socat
      - mysql

    runcmd:
      - amazon-linux-extras enable nginx1
      - yum clean metadata
      - yum install -y nginx

      - echo 'export MYSQL_HOST="${local.mysql.host}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_PORT="${local.mysql.port}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_USER="${local.mysql.user}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_PASS="${local.mysql.pass}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_DB="${local.mysql.db}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_TIMEOUT="${local.mysql.timeout}"' >> /etc/profile.d/app_env.sh
      - chmod +x /etc/profile.d/app_env.sh

      - touch /var/log/app1_mysql_error.log /var/log/app2_mysql_error.log
      - chmod 644 /var/log/app1_mysql_error.log /var/log/app2_mysql_error.log

      - |
        cat > /usr/local/bin/app1_handler.sh <<'EOF'
        #!/bin/bash
        source /etc/profile.d/app_env.sh
        ERROR_OUTPUT=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT 1;" --init-command="SET SESSION wait_timeout=$MYSQL_TIMEOUT" --ssl 2>&1)

        if [ $? -eq 0 ]; then
          printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nApp 1: MySQL OK"
        else
          echo "`date` $ERROR_OUTPUT" >> /var/log/app1_mysql_error.log
          printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nApp 1: MySQL: Version `mysql --version` ERROR\n$ERROR_OUTPUT"
        fi
        EOF

      - |
        cat > /usr/local/bin/app2_handler.sh <<'EOF'
        #!/bin/bash
        source /etc/profile.d/app_env.sh
        ERROR_OUTPUT=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT 1;" --init-command="SET SESSION wait_timeout=$MYSQL_TIMEOUT" --ssl 2>&1)

        if [ $? -eq 0 ]; then
          printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nApp 2: MySQL OK"
        else
          echo "`date` $ERROR_OUTPUT" >> /var/log/app2_mysql_error.log
          printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nApp 2: MySQL: Version `mysql --version` ERROR\n$ERROR_OUTPUT"
        fi
        EOF

      - chmod +x /usr/local/bin/app1_handler.sh /usr/local/bin/app2_handler.sh

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
              return 200 "Health: OK: MaD GrEEtz!";
            }
          }
        }
        EOF
      - systemctl enable nginx
      - systemctl restart nginx
  CLOUD_INIT
  )
}

resource "aws_launch_template" "web_lt" {
  name_prefix            = format("%s-%s", var.env_prefix, "web-")
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  user_data              = local.cloud_init

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = format("%s-%s", var.env_prefix, "web-instance")
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name             = format("%s-%s", var.env_prefix, "web-asg")
  min_size         = 2
  max_size         = 6
  desired_capacity = 2
  vpc_zone_identifier = [
    lookup(lookup(module.vpcs, local.vpc_names.app).private_subnet_name_to_subnet_id, "proxy1"),
    lookup(lookup(module.vpcs, local.vpc_names.app).private_subnet_name_to_subnet_id, "proxy2")
  ]
  target_group_arns         = [aws_lb_target_group.tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = format("%s-%s", var.env_prefix, "web-instance")
    propagate_at_launch = true
  }

  # will launch with initial desired_capacity value
  # but need to ignore future values to let cloudwatch control scaling out and in
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# scale out based on cpu
resource "aws_autoscaling_policy" "scale_out" {
  name                   = format("%s-%s", var.env_prefix, "scale-out")
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = format("%s-%s", var.env_prefix, "cpu-high")
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out if CPU > 70% for 2 minutes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

# scale in based on cpu
resource "aws_autoscaling_policy" "scale_in" {
  name                   = format("%s-%s", var.env_prefix, "scale-in")
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = format("%s-%s", var.env_prefix, "cpu-low")
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in if CPU < 30% for 2 minutes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}

