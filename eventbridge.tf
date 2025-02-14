resource "aws_scheduler_schedule_group" "default" {
  name = "${var.company_prefix}-scheduler-group"
}