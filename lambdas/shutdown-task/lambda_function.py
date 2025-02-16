import json
import time

import boto3
from os import environ
from datetime import timedelta, datetime

ecs = boto3.client('ecs')
ddb = boto3.client('dynamodb')
cloudmap = boto3.client('servicediscovery')
scheduler = boto3.client('scheduler')
cloudwatch_logs = boto3.client('logs')

company_prefix = environ.get("company_prefix")


def lambda_handler(event, context):
    service_uuid = event["service_uuid"]

    dynamo_row = ddb.get_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        }
    )

    if not dynamo_row.get("Item"):
        print("No metadata found for service_uuid")
        return {
            "statusCode": 404,
            "body": json.dumps({
                "message": "No metadata found for service_uuid"
            })
        }

    now = int(time.time() * 1000)  # Current time in milliseconds
    ten_minutes_ago = now - 600000  # 10 minutes in milliseconds

    # Query CloudWatch logs
    response = cloudwatch_logs.filter_log_events(
        logGroupName=environ.get("ecs_access_log_group_name"),
        logStreamNames=[service_uuid],
        startTime=ten_minutes_ago,
        endTime=now,
        limit=1
    )

    print(response)

    # Check if there are events
    if response.get("events") and not event.get("force_shutdown"):
        print("Service is still being used")
        return {
            "statusCode": 400,
            "body": json.dumps({
                "message": "Service is still being used so is not shutting down"
            })
        }

    service_arn = dynamo_row["Item"]["service_arn"]["S"]

    update_response = ecs.update_service(
        cluster=environ.get("ecs_cluster_arn"),
        service=service_arn,
        desiredCount=0
    )

    ddb.update_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        },
        UpdateExpression="SET desired_tasks = :desired_tasks",
        ExpressionAttributeValues={
            ":desired_tasks": {
                "N": "0"
            }
        }
    )


    if dynamo_row["Item"].get("shutdown_schedule_arn"):
        existing_schedule = scheduler.get_schedule(
            GroupName=environ.get("scheduler_group_name"),
            Name=f"{company_prefix}-{service_uuid}"
        )

        filtered_resp = {
            k: v
            for k, v in existing_schedule.items()
            if k not in ["ResponseMetadata", "Arn", "CreationDate", "LastModificationDate"]

        }

        merged_response = filtered_resp | {"State": "DISABLED"}

        scheduler_schedule = scheduler.update_schedule(**merged_response)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Service shutdown successfully"
        })
    }