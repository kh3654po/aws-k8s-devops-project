output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "worker_private_ips" {
  value = aws_instance.worker[*].private_ip
}

output "worker_launch_template_id" {
  value = aws_launch_template.worker.id
}

output "worker_launch_template_latest_version" {
  value = aws_launch_template.worker.latest_version
}

output "worker_asg_instance_profile_name" {
  value = aws_iam_instance_profile.worker_asg.name
}

output "worker_asg_name" {
  value = aws_autoscaling_group.worker.name
}

output "worker_asg_min_size" {
  value = aws_autoscaling_group.worker.min_size
}

output "worker_asg_desired_capacity" {
  value = aws_autoscaling_group.worker.desired_capacity
}

output "worker_asg_max_size" {
  value = aws_autoscaling_group.worker.max_size
}

output "vpc_id" {
  value = module.vpc.vpc_id
}