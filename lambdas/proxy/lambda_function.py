import json
import time

import boto3
from boto3 import resource
from botocore.config import Config
import requests
from os import environ

# from cachetools import TTLCache

config = Config(
    connect_timeout=2,
    read_timeout=2,
    retries={'max_attempts': 5}
)

# Initialize CloudMap client
cloudmap_client = boto3.client('servicediscovery', config=config)
cloudmap_namespace = environ.get("cloudmap_namespace")
cloudwatch_client = boto3.client('logs')
lambda_client = boto3.client('lambda')

ddb = boto3.client('dynamodb')

env_full_domain = environ.get("full_domain")
env_startup_task_lambda_arn = environ.get("startup_task_lambda_arn")


# In-memory cache with TTL of 60 seconds for service resolution
# cache = TTLCache(maxsize=1000, ttl=60)

def handle_no_active_instances(service_name, registry, full_domain, host) -> dict:
    service_uuid = get_uuid_from_dynamodb_domain(host)

    print(f"No active instances found for {service_name}.{registry}.{full_domain}. Service UUID found: {service_uuid} from host {host}")

    dynamo_row = ddb.query(
        TableName=environ.get("metadata_ddb_table_name", ""),
        KeyConditionExpression="#d = :d",
        ExpressionAttributeNames={"#d": "uuid"},
        ExpressionAttributeValues={":d": {"S": service_uuid}}
    )

    if dynamo_row.get("Items") and dynamo_row["Items"][0].get("desired_tasks"):
        current_desired_tasks = dynamo_row["Items"][0]["desired_tasks"]["N"]
        current_task_status = dynamo_row["Items"][0]["task_status"]["S"]

        if current_desired_tasks == "0" or current_task_status == "STOPPED":
            lambda_client.invoke(
                FunctionName=env_startup_task_lambda_arn,
                InvocationType='Event',
                Payload=json.dumps({
                    "service_uuid": service_uuid
                })
            )

    return {
        "statusCode": 302,
        "headers": {
            "Location": f"https://sb.{full_domain}/starting/{registry}/{service_name}"
        }
    }


def get_service_for_subdomain(service_name, registry, full_domain, host) -> str | dict:
    full_service_name = f"{service_name}.{registry}.{full_domain}"
    # if service_name in cache:
    # return cache[service_name]

    try:
        print(f"getting cloudmap instance for {cloudmap_namespace} name {full_service_name}")
        response = cloudmap_client.discover_instances(
            NamespaceName=cloudmap_namespace,
            ServiceName=full_service_name
        )
        instances = response.get('Instances', [])

        if not instances:
            return handle_no_active_instances(service_name, registry, full_domain, host)

        # Assume the first instance is the correct one as there should only ever be 1
        service_endpoint = instances[0]['Attributes'].get('AWS_INSTANCE_IPV4', None)
        if not service_endpoint:
            print(f"No valid endpoint found for {full_service_name}")

        # Cache the result
        # cache[service_name] = service_endpoint

        return service_endpoint
    except Exception as e:
        print(e)
        return {
            "statusCode": 500,
            "body": "Internal Server Error"
        }


def get_uuid_from_dynamodb_domain(domain) -> str | None:
    dynamo_row = ddb.query(
        TableName=environ.get("metadata_ddb_table_name", ""),
        IndexName="DomainIndex",
        KeyConditionExpression="#d = :d",
        ExpressionAttributeNames={"#d": "domain"},
        ExpressionAttributeValues={":d": {"S": domain}}
    )

    if dynamo_row.get("Items"):
        return dynamo_row["Items"][0]["uuid"]["S"]
    return None

def lambda_handler(event, context):
    try:
        print(event['requestContext']['domainName'])
        host = event['requestContext']['domainName']
        parts = host.split('.')

        # Assume the structure is pr-repo-user.registry.example.com (or multi-tld like .co.uk)
        if not 4 <= len(parts) <= 5:
            raise Exception("Invalid subdomain format")

        service_name = parts[0]
        registry = parts[1]
        full_domain = ".".join(parts[2:])

        if env_full_domain != full_domain:
            print(f"Full domain mismatch: {full_domain} != {env_full_domain}")
            return {
                "statusCode": 404,
                "body": "Not Found"
            }

        service_endpoint = get_service_for_subdomain(
            service_name,
            registry,
            full_domain,
            host
        )

        # No active instances
        if isinstance(service_endpoint, dict):
            return service_endpoint

        service_uuid = get_uuid_from_dynamodb_domain(host)

        if service_uuid:
            log_timestamp = int(time.time() * 1000)
            log_event = {
                "logEvents": [{
                    "timestamp": log_timestamp,
                    "message": f"Request at {log_timestamp} for {host}"
                }],
                "logGroupName": environ.get("ecs_access_log_group_name"),
                "logStreamName": service_uuid
            }

            cloudwatch_client.put_log_events(
                **log_event
            )

        path = event.get('path', "")

        # Forward the request to the resolved service
        url = f"http://{service_endpoint}{path}"  # todo: support https

        # todo add async call to reset eventbridge schedule

        if event["httpMethod"] == "GET":
            response = requests.get(url, headers=event['headers'], data=event['body'], timeout=10)  # todo add multiple timeout options
        elif event["httpMethod"] == "POST":
            response = requests.post(url, headers=event['headers'], data=event['body'], timeout=10)
        elif event["httpMethod"] == "PUT":
            response = requests.put(url, headers=event['headers'], data=event['body'], timeout=10)
        elif event["httpMethod"] == "DELETE":
            response = requests.delete(url, headers=event['headers'], data=event['body'], timeout=10)
        elif event["httpMethod"] == "PATCH":
            response = requests.patch(url, headers=event['headers'], data=event['body'], timeout=10)
        else:
            raise Exception(f"Unsupported HTTP method: {event['httpMethod']}")

        return {
            'statusCode': response.status_code,
            'body': response.text,
            'headers': {
                'Content-Type': response.headers.get('Content-Type', 'application/json'),
            }
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
