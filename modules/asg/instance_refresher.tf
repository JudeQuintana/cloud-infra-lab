locals {
  instance_refresh = { for this in [var.asg.instance_refresh] : this => this if var.asg.instance_refresh }
}

### try changing this to inline on the asg instead of CLI, compare behavior
resource "terraform_data" "this_instance_refresher" {
  for_each = local.instance_refresh

  # trigger on launch template user_data or image_id changes
  # using sha1 for unique string
  triggers_replace = [
    sha1(aws_launch_template.this.user_data),
    aws_launch_template.this.image_id
  ]

  # Automatically uses latest launch template version.
  # Must wait until it finishes before starting a new one (10min+ depending on config) otherwise the command will error.
  # - An error occurred (InstanceRefreshInProgress) when calling the StartInstanceRefresh operation: An Instance Refresh is already in progress and blocks the execution of this Instance Refresh.
  # It won't run instance refresh command on first version of the launch template (unnecessary) but will run on subsequent changes to user_data in the launch template.
  # MinHealthyPercentage = 100 ensures new instances are brought up before any old ones are taken down
  provisioner "local-exec" {
    command = <<-EOT
      # fetch the LT’s latest version number
      VERSION=$(aws ec2 describe-launch-templates \
        --launch-template-ids ${aws_launch_template.this.id} \
        --query 'LaunchTemplates[0].LatestVersionNumber' --output text \
        --region ${local.region})

      if [ "$VERSION" != "1" ]; then
        aws autoscaling start-instance-refresh \
          --auto-scaling-group-name ${aws_autoscaling_group.this.name} \
          --preferences '${jsonencode({ InstanceWarmup = 300, MinHealthyPercentage = 100 })}' \
          --region ${local.region}
      fi
    EOT
  }
}

