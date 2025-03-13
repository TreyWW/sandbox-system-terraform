resource "aws_sfn_state_machine" "provision_sandbox" {
  name     = "${var.company_prefix}-provision-sandbox"
  role_arn = module.provision_sandbox_lambda.execution_role_arn
  definition = jsonencode({
    "Comment" : "Provision a new sandbox SFN",
    "StartAt" : "CheckRequiredParameters",
    "States" : {
      "CheckRequiredParameters" : {
        "Type" : "Choice",
        "Choices" : [
          {
            "Variable" : "$.pr",
            "IsPresent" : true,
            "Next" : "GenerateFullDomain"
          },
          {
            "Variable" : "$.repository",
            "IsPresent" : true,
            "Next" : "GenerateFullDomain"
          },
          {
            "Variable" : "$.user",
            "IsPresent" : true,
            "Next" : "GenerateFullDomain"
          },
          {
            "Variable" : "$.created_by_user_id",
            "IsPresent" : true,
            "Next" : "GenerateFullDomain"
          }
        ],
        "Default" : "MissingParameters"
      },
      "GenerateFullDomain" : {
        "Type" : "Pass",
        "ResultPath" : "$.full_domain",
        "Parameters" : {
          "full_domain.$" = "States.Format('{}-{}-{}.{}.{}', $.pr, $.repository, $.user, 'github', '${var.domain}')"
        },
        "Next" : "GenerateUUID"
      },
      "GenerateUUID" : {
        "Type" : "Pass",
        "ResultPath" : "$.service_uuid",
        "Parameters" : {
          "service_uuid.$" : "States.UUID()"
        },
        "Next" : "StoreMetadata"
      },
      "StoreMetadata" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::aws-sdk:dynamodb:putItem",
        "ResultPath" : null
        "Parameters" : {
          "TableName" : aws_dynamodb_table.metadata_table.name,
          "Item" : {
            "uuid" : {
              "S.$" : "$.service_uuid.service_uuid"
            },
            "created_by_user_id" : {
              "N.$" : "$.created_by_user_id"
            },
            "pr" : {
              "N.$" : "$.pr"
            },
            "repository" : {
              "S.$" : "$.repository"
            },
            "user" : {
              "S.$" : "$.user"
            },
            "task_status" : {
              "S" : "pending"
            },
            "domain" : {
              "S.$" : "$.full_domain.full_domain"
            },
            "registry" : {
              "S" : "github"
            },
            "created_at" : {
              "S.$" : "$$.State.EnteredTime"
            },
            "updated_at" : {
              "S.$" : "$$.State.EnteredTime"
            }
          }
        },
        "Next" : "CreateServiceInParallel"
      },
      "CreateServiceInParallel" : {
        "Type" : "Parallel",
        "Branches" : [
          {
            "StartAt" : "CreateCloudMapService",
            "States" : {
              "CreateCloudMapService" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::aws-sdk:servicediscovery:createService",
                "ResultPath" : "$.cloudmap_service"
                "Parameters" : {
                  "Name.$" : "$.full_domain.full_domain",
                  "NamespaceId" : aws_service_discovery_http_namespace.main_api_namespace.id
                },
                "Next" : "SaveCloudMapService"
              },
              "SaveCloudMapService" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::aws-sdk:dynamodb:updateItem",
                "ResultPath" : null,
                "Parameters" : {
                  "TableName" : aws_dynamodb_table.metadata_table.name,
                  "Key" : {
                    "uuid" : {
                      "S.$" : "$.service_uuid.service_uuid"
                    }
                  },
                  "UpdateExpression" : "SET cloudmap_service_arn = :cloudmap_service_arn",
                  "ExpressionAttributeValues" : {
                    ":cloudmap_service_arn" : {
                      "S.$" : "$.cloudmap_service.Service.Arn"
                    }
                  }
                },
                "End" : true
              }
            }
          },
          {
            "StartAt" : "CreateEcsTaskDefinition",
            "States" : {
              "CreateEcsTaskDefinition" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::aws-sdk:ecs:registerTaskDefinition",
                "ResultPath" : "$.task_definition"
                "Parameters" : {
                  "Family.$" : "States.Format('{}-{}', '${var.company_prefix}', $.service_uuid.service_uuid)"
                  "TaskRoleArn" : aws_iam_role.ecs_task_role.arn,
                  "ExecutionRoleArn" : aws_iam_role.ecs_execution_role.arn,
                  "NetworkMode" : "awsvpc",
                  "ContainerDefinitions" : [
                    {
                      "Name" : "sandbox",
                      "Image" : "nginxdemos/hello",
                      "Cpu" : 256,
                      "Memory" : 512,
                      "Essential" : true,
                      "PortMappings" : [
                        {
                          "Name" : "port80",
                          "ContainerPort" : 80,
                          "HostPort" : 80,
                          "Protocol" : "tcp",
                          "AppProtocol" : "http"
                        }
                      ],
                      "LogConfiguration" : {
                        "LogDriver" : "awslogs",
                        "Options" : {
                          "awslogs-group" : aws_cloudwatch_log_group.ecs.name,
                          "awslogs-region" : var.region,
                          "awslogs-stream-prefix" : "ecs"
                        }
                      }
                    }
                  ],
                  "RuntimePlatform" : {
                    "CpuArchitecture" : "X86_64",
                    "OperatingSystemFamily" : "LINUX"
                  },
                  "RequiresCompatibilities" : [
                    "FARGATE"
                  ],
                  "Cpu" : "256",
                  "Memory" : "512"
                },
                "Next" : "SaveEcsTaskDefinition"
              },
              "SaveEcsTaskDefinition" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::aws-sdk:dynamodb:updateItem",
                "ResultPath" : null,
                "Parameters" : {
                  "TableName" : aws_dynamodb_table.metadata_table.name,
                  "Key" : {
                    "uuid" : {
                      "S.$" : "$.service_uuid.service_uuid"
                    }
                  },
                  "UpdateExpression" : "SET task_definition_arn = :task_definition_arn",
                  "ExpressionAttributeValues" : {
                    ":task_definition_arn" : {
                      "S.$" : "$.task_definition.TaskDefinition.TaskDefinitionArn"
                    }
                  }
                },
                "End" : true
              }
            }
          }
        ],
        "ResultPath" : "$.cloudmap_and_ecs_td",
        "Next" : "CreateEcsService"
      },
      "CreateEcsService" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::aws-sdk:ecs:createService",
        "ResultPath" : "$.ecs_service",
        "Parameters" : {
          "Cluster" : aws_ecs_cluster.main.arn,
          "ServiceName.$" : "$.service_uuid.service_uuid",
          "TaskDefinition.$" : "$.cloudmap_and_ecs_td[1].task_definition.TaskDefinition.TaskDefinitionArn",
          "DesiredCount" : 1,
          "LaunchType" : "FARGATE",
          "PlatformVersion" : "LATEST",
          "NetworkConfiguration" : {
            "AwsvpcConfiguration" : {
              "Subnets" : [
                aws_subnet.private_1a_with_nat.id, aws_subnet.private_1b_with_nat.id, aws_subnet.private_1c_with_nat.id
              ],
              "SecurityGroups" : [aws_security_group.ecs.id],
              "AssignPublicIp" : "DISABLED"
            }
          },
          "ServiceRegistries" : [
            {
              "RegistryArn.$" : "$.cloudmap_and_ecs_td[0].cloudmap_service.Service.Arn",
              "ContainerName" : "sandbox"
            }
          ],
          "Tags" : [
            {
              "Key" : "service_uuid",
              "Value.$" : "$.service_uuid.service_uuid"
            }
          ]
        },
        "Next" : "CreateLogStream"
      },
      "CreateLogStream" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::aws-sdk:cloudwatchlogs:createLogStream",
        "ResultPath" : null,
        "Parameters" : {
          "LogGroupName" : aws_cloudwatch_log_group.ecs_access_logs.name,
          "LogStreamName.$" : "$.service_uuid.service_uuid"
        },
        "Next" : "CreateSchedulerSchedule"
      }
      "CreateSchedulerSchedule" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::aws-sdk:scheduler:createSchedule",
        "ResultPath" : "$.scheduler_schedule"
        "Parameters" : {
          "Name.$" : "$.service_uuid.service_uuid",
          "GroupName" : aws_scheduler_schedule_group.default.name,
          "ActionAfterCompletion" : "NONE",
          "ScheduleExpression.$" : "$.futureTime"
          "FlexibleTimeWindow" : {
            "Mode" : "OFF"
          },
          "Target" : {
            "Arn" : module.shutdown_sandbox_lambda.lambda_arn,
            "RoleArn" : aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn,
            "Input" : {
              "service_uuid.$" : "$.service_uuid.service_uuid"
            }
          }
        },
        "Next" : "UpdateDynamoDbWithSchedule"
      },
      "UpdateDynamoDbWithSchedule" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::aws-sdk:dynamodb:updateItem",
        "Parameters" : {
          "TableName" : aws_dynamodb_table.metadata_table.name,
          "Key" : {
            "uuid" : {
              "S.$" : "$.service_uuid.service_uuid"
            }
          },
          "UpdateExpression" : "SET shutdown_schedule_arn = :shutdown_schedule_arn",
          "ExpressionAttributeValues" : {
            ":shutdown_schedule_arn" : {
              "S.$" : "$.scheduler_schedule.ScheduleArn"
            }
          }
        },
        "End" : true
      },
      "MissingParameters" : {
        "Type" : "Fail",
        "Error" : "MissingParameters",
        "Cause" : "Required parameters are missing."
      }
    }
  })
}


module "restart_sandbox_iam_role" {
  source = "./modules/iam_role"

  prefix = var.company_prefix
  name   = "restart-sandbox-sfn-role"

  inline_iam_policies = [
    {
      name = "sfn-inline-policy"
      policy_json = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "DynamoDB",
            "Effect" : "Allow",
            "Action" : [
              "dynamodb:*Item"
            ],
            "Resource" : [
              aws_dynamodb_table.metadata_table.arn
            ]
          },
          {
            "Sid" : "CloudwatchLogs",
            "Effect" : "Allow",
            "Action" : [
              "logs:CreateLogDelivery",
              "logs:GetLogDelivery",
              "logs:UpdateLogDelivery",
              "logs:DeleteLogDelivery",
              "logs:ListLogDeliveries",
              "logs:PutResourcePolicy",
              "logs:DescribeResourcePolicies",
              "logs:DescribeLogGroups"
            ],
            "Resource" : [
              "*"
            ]
          },
          {
            "Sid" : "XRay",
            "Effect" : "Allow",
            "Action" : [
              "xray:PutTraceSegments",
              "xray:PutTelemetryRecords",
              "xray:GetSamplingRules",
              "xray:GetSamplingTargets"
            ],
            "Resource" : "*"
          }
        ]
      })
    }
  ]
  principal_services = ["states.amazonaws.com"]
}

resource "aws_sfn_state_machine" "restart_sandbox" {
  name     = "${var.company_prefix}-restart-sandbox"
  role_arn = module.restart_sandbox_iam_role.arn
  definition = jsonencode({
    "Comment" : "A description of my state machine",
    "StartAt" : "Choice (1)",
    "States" : {
      "Choice (1)" : {
        "Type" : "Choice",
        "Choices" : [
          {
            "Next" : "DynamoDB GetItem",
            "Condition" : "{% $exists($states.input.service_uuid) %}"
          }
        ],
        "Default" : "Fail"
      },
      "DynamoDB GetItem" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::dynamodb:getItem",
        "Arguments" : {
          "TableName" : aws_dynamodb_table.metadata_table.name,
          "Key" : {
            "uuid" : {
              "S" : "{% $states.input.service_uuid %}"
            }
          }
        },
        "Next" : "Choice",
        "Assign" : {
          "dynamo_row" : "{% $states.result.Item %}"
        }
      },
      "Choice" : {
        "Type" : "Choice",
        "Choices" : [
          {
            "Next" : "Set ECS service_arn variable",
            "Condition" : "{% $exists($dynamo_row) %}"
          }
        ],
        "Default" : "Fail (1)"
      },
      "Set ECS service_arn variable" : {
        "Type" : "Pass",
        "Assign" : {
          "service_arn" : "{% $dynamo_row.service_arn.S %}"
        },
        "Next" : "UpdateService"
      },
      "UpdateService" : {
        "Type" : "Task",
        "Arguments" : {
          "Cluster" : aws_ecs_cluster.main.name,
          "Service" : "{% $service_arn %}",
          "DesiredCount" : 1
        },
        "Resource" : "arn:aws:states:::aws-sdk:ecs:updateService",
        "End" : true
      },
      "Fail (1)" : {
        "Type" : "Fail"
      },
      "Fail" : {
        "Type" : "Fail"
      }
    },
    "QueryLanguage" : "JSONata"
  })

  logging_configuration {
    log_destination = "${aws_cloudwatch_log_group.restart_sandbox_sfn.arn}:*"
    level           = "ALL"
  }

  tracing_configuration {
    enabled = true
  }
}