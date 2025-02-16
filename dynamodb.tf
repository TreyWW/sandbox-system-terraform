/* SERVICE METADATA */

resource "aws_dynamodb_table" "metadata_table" {
  name           = "${var.company_prefix}-main-metadata-table"
  billing_mode = "PAY_PER_REQUEST"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "uuid"
    type = "S"
  }

  hash_key = "uuid"
}

# -- FIELDS --
# uuid
# created_by_user_id
# pr
# repository
# user
# registry
# status