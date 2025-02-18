/* SERVICE METADATA */

resource "aws_dynamodb_table" "metadata_table" {
  name           = "${var.company_prefix}-main-metadata-table"
  billing_mode   = "PAY_PER_REQUEST"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "uuid"
    type = "S"
  }

  attribute {
    name = "domain"
    type = "S"
  }

  hash_key = "uuid"

  global_secondary_index {
    name            = "DomainIndex"
    hash_key        = "domain"
    projection_type = "INCLUDE"
    non_key_attributes = ["uuid"]
  }

  tags = {
    "Hello" = "Test"
  }
}


output "my_dynamodb_output_arn" {
  value = aws_dynamodb_table.metadata_table.arn
}


# -- FIELDS --
# uuid
# created_by_user_id
# pr
# repository
# user
# registry
# task_status = ["ACTIVE", "STOPPED", "STARTING"]
# desired_tasks
# domain
# created_at
# updated_at
# task_definition_arn
# cloudmap_service_arn
# shutdown_schedule_arn
# next_shutdown_at