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
}

# -- FIELDS --
# uuid
# created_by_user_id
# pr
# repository
# user
# status


/* REPOSITORY */

resource "aws_dynamodb_table" "repository_table" {
  name           = "${var.company_prefix}-main-repository-table"
  billing_mode = "PAY_PER_REQUEST"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "uuid"
    type = "S"
  }
}

## -- FIELDS --

# created_by_user_id

/* Subdomain Routes */

resource "aws_dynamodb_table" "subdomain_routes_table" {
  name           = "${var.company_prefix}-main-subdomain-routes-table"
  billing_mode = "PAY_PER_REQUEST"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "subdomain"
    type = "S"
  }
}

## -- FIELDS --

# subdomain
# service_uuid