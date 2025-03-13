import json
import time

import boto3
from botocore.exceptions import ClientError
from os import environ
from datetime import timedelta, datetime

import logging

ecs = boto3.client('ecs')
ddb = boto3.client('dynamodb')
scheduler = boto3.client('scheduler')

company_prefix = environ.get("company_prefix")

logger = logging.getLogger()


def update_schedule(schedule_name: str, new_properties: dict):
    existing_schedule = scheduler.get_schedule(
        GroupName=environ.get("scheduler_group_name", ""),
        Name=schedule_name
    )

    filtered_resp = {
        k: v
        for k, v in existing_schedule.items()
        if k not in ["ResponseMetadata", "Arn", "CreationDate", "LastModificationDate"]

    }

    merged_response = filtered_resp | new_properties

    scheduler_schedule = scheduler.update_schedule(**merged_response)

    return scheduler_schedule

def create_schedule(schedule_name: str, at, service_uuid):
    return scheduler.create_schedule(
        Name=schedule_name,
        GroupName=environ.get("scheduler_group_name"),
        ActionAfterCompletion="NONE",
        FlexibleTimeWindow={
            "Mode": "OFF"
        },
        ScheduleExpression=at,
        Target={
            "Arn": environ.get("shutdown_lambda_arn", ""),
            "RoleArn": environ.get("scheduler_role_arn", ""),
            "Input": json.dumps({
                "service_uuid": service_uuid
            })
        }
    )

def lambda_handler(event, context):
    service_uuid = event.get("service_uuid")

    if not service_uuid:
        return {
            "statusCode": 400,
            "body": json.dumps({
                "message": "service_uuid not provided"
            })
        }

    logger.debug(f"service_uuid: {service_uuid}")

    dynamo_row = ddb.get_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        }
    )

    if not dynamo_row.get("Item"):
        logger.debug(f"No metadata found for {service_uuid}")
        return {
            "statusCode": 404,
            "body": json.dumps({
                "message": "No metadata found for service_uuid"
            })
        }

    service_arn = dynamo_row["Item"].get("service_arn", {}).get("S", None)

    if not service_arn:
        ...  # todo: re-create ecs
        return

    ecs.update_service(
        cluster=environ.get("ecs_cluster_arn"),
        service=service_arn,
        desiredCount=1
    )

    in_10_mins_datetime = datetime.now() + timedelta(minutes=10)
    new_schedule = None

    if dynamo_row["Item"].get("shutdown_schedule_arn"):
        logger.debug("Existing schedule found, updating")
        try:
            existing_schedule = scheduler.get_schedule(
                GroupName=environ.get("scheduler_group_name"),
                Name=f"{company_prefix}-{service_uuid}"
            )

            filtered_resp = {
                k: v
                for k, v in existing_schedule.items()
                if k not in ["ResponseMetadata", "Arn", "CreationDate", "LastModificationDate"]
            }

            merged_response = filtered_resp | {
                "State": "ENABLED",
                "ScheduleExpression": f"at({in_10_mins_datetime.strftime('%Y-%m-%dT%H:%M:%S')})"
            }

            scheduler.update_schedule(**merged_response)
        except ClientError as err:
            logger.debug(f"Error updating schedule: {err}")
            if err.response['Error']['Code'] == 'ResourceNotFoundError':
                logger.debug("Schedule not found, creating new one")
                new_schedule = create_schedule(
                    f"{company_prefix}-{service_uuid}",
                    f"at({in_10_mins_datetime.strftime('%Y-%m-%dT%H:%M:%S')})",
                    service_uuid
                )
    else:
        logger.debug("No existing schedule found, creating new one")
        new_schedule = create_schedule(
            f"{company_prefix}-{service_uuid}",
            f"at({in_10_mins_datetime.strftime('%Y-%m-%dT%H:%M:%S')})",
            service_uuid
        )

    ddb.update_item(
        TableName=environ.get("metadata_ddb_table"),
        Key={
            "uuid": {
                "S": service_uuid
            }
        },
        UpdateExpression=(
            "SET desired_tasks = :desired_tasks, updated_at = :updated_at, task_status = :task_status"
            + (", next_shutdown_at = :next_shutdown_at" if not new_schedule else "")
        ),
        ExpressionAttributeValues={
            ":desired_tasks": {"N": "1"},
            ":updated_at": {"S": datetime.now().isoformat()},
            ":task_status": {"S": "STARTING"},
            **(
                {":next_shutdown_at": {"S": in_10_mins_datetime.strftime("%Y-%m-%dT%H:%M:%S")}}
                if not new_schedule else {}
            )
        }
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Service started up successfully"
        })
    }
