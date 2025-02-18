import json
import boto3
from os import environ
import uuid

from datetime import timedelta, datetime

ecs = boto3.client('ecs')
ddb = boto3.client('dynamodb')
cloudmap = boto3.client('servicediscovery')
scheduler = boto3.client('scheduler')
cloudwatch_logs = boto3.client('logs')

company_prefix = environ.get("company_prefix")


def lambda_handler(event, context):
    # todo: auth

    if not all(k in event for k in ("pr", "repository", "user", "created_by_user_id")):
        print(event.get(k) for k in ("pr", "repository", "user", "created_by_user_id"))
        return {
            "statusCode": 400,
            "body": json.dumps({
                "message": "missing required parameters"
            })
        }

    service_uuid = str(uuid.uuid4())

    pull_request_number = event["pr"]
    repository_name = event["repository"]
    user = event["user"]
    registry = "gh"
    tld = environ.get("domain")
    full_domain = f"{pull_request_number}-{repository_name}-{user}.{registry}.{tld}"

    # store metadata
    ddb.put_item(
        TableName=environ.get("metadata_ddb_table"),
        Item={
            "uuid": {
                "S": service_uuid
            },
            "created_by_user_id": {
                "N": str(event["created_by_user_id"])
            },
            "pr": {
                "N": str(event["pr"])
            },
            "repository": {
                "S": event["repository"]
            },
            "user": {
                "S": event["user"]
            },
            "task_status": {
                "S": "pending"
            },
            "domain": {
                "S": full_domain
            },
            "registry": {"S": "github"},
            "created_at": {
                "S": datetime.now().isoformat()
            },
            "updated_at": {
                "S": datetime.now().isoformat()
            }
        }
    )

    try:
        cloudmap_service = cloudmap.create_service(
            Name=full_domain,
            NamespaceId=environ.get("cloudmap_namespace_id"),
            # DnsConfig={
            #     "NamespaceId": environ.get("cloudmap_namespace_id"),
            #     "RoutingPolicy": "MULTIVALUE",
            #     "DnsRecords": [
            #         {
            #             "Type": "A",
            #             "TTL": 60
            #         },
            #         {
            #             "Type": "SRV",
            #             "TTL": 60
            #         }
            #     ]
            # }
        )
    except cloudmap.exceptions.ServiceAlreadyExists:
        print("CloudMap already exists")

        cloudmap_service = cloudmap.get_service(
            Id=full_domain
        )

        print(cloudmap_service)


    print(f"{company_prefix}-{service_uuid}")

    ecs_task_definition = ecs.register_task_definition(
        family=f"{company_prefix}-{service_uuid}",
        taskRoleArn=environ.get("ecs_task_role_arn"),
        executionRoleArn=environ.get("ecs_execution_role_arn"),
        networkMode="awsvpc",
        containerDefinitions=[
            {
                "name": "sandbox",
                "image": "nginxdemos/hello",  # todo integrate ECR/github artifcats image
                "cpu": 256,
                "memory": 512,
                "essential": True,
                "portMappings": [  # todo make dynamic port mappings incase user doesnt use port 80
                    {
                        "name": "port80",
                        "containerPort": 80,
                        "hostPort": 80,
                        "protocol": "tcp",
                        "appProtocol": "http"
                    }
                ],
                "environment": [],
                "environmentFiles": [],
                "mountPoints": [],
                "volumesFrom": [],
                "readonlyRootFilesystem": False,  # todo allow readonly,
                "ulimits": [],
                "systemControls": [],
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": environ.get("ecs_log_group_arn"),
                        "awslogs-region": environ.get("ecs_log_group_region"),
                        "awslogs-stream-prefix": "ecs"
                    }
                }
            }
        ],
        runtimePlatform={
            "cpuArchitecture": "X86_64",
            "operatingSystemFamily": "LINUX"
        },
        requiresCompatibilities=[
            "FARGATE"
        ],
        cpu="256",
        memory="512",
        volumes=[],
        placementConstraints=[]
    )

    ddb.update_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        },
        UpdateExpression="SET task_definition_arn = :task_definition_arn, cloudmap_service_arn = :cloudmap_service_arn",
        ExpressionAttributeValues={
            ":task_definition_arn": {
                "S": ecs_task_definition["taskDefinition"]["taskDefinitionArn"]
            },
            ":cloudmap_service_arn": {
                "S": cloudmap_service["Service"]["Arn"]
            }
        }
    )

    ecs_service = ecs.create_service(
        cluster=environ.get("ecs_cluster_arn"),
        serviceName=f"{company_prefix}-{service_uuid}",
        taskDefinition=ecs_task_definition["taskDefinition"]["taskDefinitionArn"],
        desiredCount=1,
        launchType="FARGATE",
        platformVersion="LATEST",
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": environ.get("ecs_subnets").split(","),
                "securityGroups": environ.get("ecs_security_groups").split(","),
                "assignPublicIp": "DISABLED"
            }
        },
        serviceRegistries=[
            {
                "registryArn": cloudmap_service["Service"]["Arn"],
                # "port": 80,  # todo allow port config
                "containerName": "sandbox",
                # "containerPort": 80  # todo allow port config
            }
        ],
        tags=[
            {
                "key": "company_prefix",
                "value": company_prefix
            },
            {
                "key": "pr",
                "value": str(event["pr"])
            },
            {
                "key": "repository",
                "value": event["repository"]
            },
            {
                "key": "user",
                "value": event["user"]
            },
            {
                "key": "created_by_user_id",
                "value": str(event["created_by_user_id"])
            },
            {
                "key": "service_uuid",
                "value": service_uuid
            }
        ]
    )

    # using environ.get("ecs_access_log_group_name")

    cloudwatch_logs.create_log_stream(
        logGroupName=environ.get("ecs_access_log_group_name"),
        logStreamName=f"{service_uuid}"
    )

    # set service arn and desired_tasks to 1 in ddb
    ddb.update_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        },
        UpdateExpression="SET service_arn = :service_arn, desired_tasks = :desired_tasks",
        ExpressionAttributeValues={
            ":service_arn": {
                "S": ecs_service["service"]["serviceArn"]
            },
            ":desired_tasks": {
                "N": "1"
            }
        }
    )

    in_10_mins_datetime = datetime.now() + timedelta(minutes=10)

    scheduler_schedule = scheduler.create_schedule(
        Name=f"{company_prefix}-{service_uuid}",
        GroupName=environ.get("scheduler_group_name"),
        ActionAfterCompletion="NONE",
        FlexibleTimeWindow={
            "Mode": "OFF"
        },
        ScheduleExpression=f"at({in_10_mins_datetime.strftime('%Y-%m-%dT%H:%M:%S')})",
        Target={
            "Arn": environ.get("shutdown_lambda_arn", ""),
            "RoleArn": environ.get("scheduler_role_arn", ""),
            "Input": json.dumps({
                "service_uuid": service_uuid
            })
        }
    )

    ddb.update_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        },
        UpdateExpression="SET shutdown_schedule_arn = :shutdown_schedule_arn, next_shutdown_at = :next_shutdown_at",
        ExpressionAttributeValues={
            ":shutdown_schedule_arn": {
                "S": scheduler_schedule["ScheduleArn"]
            },
            ":next_shutdown_at": {
                "S": in_10_mins_datetime.strftime("%Y-%m-%dT%H:%M:%S")
            }
        }
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "success",
            "service_uuid": service_uuid,
            "domain": full_domain
        })
    }
