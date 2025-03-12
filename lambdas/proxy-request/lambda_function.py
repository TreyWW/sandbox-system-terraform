import json
import time
import boto3
import requests
from os import environ
from botocore.config import Config

# AWS Client Configuration
AWS_CONFIG = Config(connect_timeout=2, read_timeout=2, retries={'max_attempts': 5})

# Initialize AWS Clients
cloudmap_client = boto3.client('servicediscovery', config=AWS_CONFIG)
cloudwatch_client = boto3.client('logs')
lambda_client = boto3.client('lambda')
dynamodb_client = boto3.client('dynamodb')

# Environment Variables
env_full_domain = environ.get("full_domain")
env_startup_task_lambda_arn = environ.get("startup_task_lambda_arn")
cloudmap_namespace = environ.get("cloudmap_namespace")
metadata_ddb_table_name = environ.get("metadata_ddb_table_name", "")
ecs_access_log_group_name = environ.get("ecs_access_log_group_name")


def log_execution_time(start_time, operation):
    elapsed_time_ms = round((time.time() - start_time) * 1000)
    print(f"{operation} completed in {elapsed_time_ms}ms")


def fetch_service_instance(service_name, registry, full_domain, host):
    full_service_name = f"{service_name}.{registry}.{full_domain}"
    print(f"Fetching CloudMap instance for {cloudmap_namespace} name {full_service_name}")

    start_time = time.time()
    try:
        response = cloudmap_client.discover_instances(NamespaceName=cloudmap_namespace, ServiceName=full_service_name)
        log_execution_time(start_time, "CloudMap instance discovery")

        instances = response.get('Instances', [])
        if not instances:
            return handle_no_active_instances(service_name, registry, full_domain, host)

        return instances[0]['Attributes'].get('AWS_INSTANCE_IPV4')
    except Exception as e:
        print(f"Error fetching service instance: {e}")
        return {"statusCode": 500, "body": "Internal Server Error"}


def handle_no_active_instances(service_name, registry, full_domain, host):
    service_uuid = get_service_uuid_from_domain(host)
    print(f"No active instances found for {service_name}.{registry}.{full_domain}. Service UUID: {service_uuid}")

    start_time = time.time()
    dynamo_response = dynamodb_client.query(
        TableName=metadata_ddb_table_name,
        KeyConditionExpression="#d = :d",
        ExpressionAttributeNames={"#d": "uuid"},
        ExpressionAttributeValues={":d": {"S": service_uuid}}
    )
    log_execution_time(start_time, "DynamoDB query for metadata")

    if dynamo_response.get("Items"):
        item = dynamo_response["Items"][0]
        desired_tasks = item.get("desired_tasks", {}).get("N")
        task_status = item.get("task_status", {}).get("S")

        if desired_tasks == "0" or task_status == "STOPPED":
            invoke_lambda_for_service_startup(service_uuid)

    return {
        "statusCode": 302,
        "headers": {"Location": f"https://sb.{full_domain}/starting/{registry}/{service_name}"}
    }


def invoke_lambda_for_service_startup(service_uuid):
    print(f"Invoking startup Lambda for service UUID: {service_uuid}")

    start_time = time.time()
    lambda_client.invoke(
        FunctionName=env_startup_task_lambda_arn,
        InvocationType='Event',
        Payload=json.dumps({"service_uuid": service_uuid})
    )
    log_execution_time(start_time, "Lambda invocation for startup")


def get_service_uuid_from_domain(domain):
    start_time = time.time()
    response = dynamodb_client.query(
        TableName=metadata_ddb_table_name,
        IndexName="DomainIndex",
        KeyConditionExpression="#d = :d",
        ExpressionAttributeNames={"#d": "domain"},
        ExpressionAttributeValues={":d": {"S": domain}}
    )
    log_execution_time(start_time, "DynamoDB query for service UUID")

    if response.get("Items"):
        return response["Items"][0]["uuid"]["S"]
    return None


def lambda_handler(event, context):
    try:
        host = event['requestContext']['domainName']
        print(f"Received request for host: {host}")

        parts = host.split('.')
        if not 4 <= len(parts) <= 5:
            raise Exception("Invalid subdomain format")

        service_name, registry, *domain_parts = parts
        full_domain = ".".join(domain_parts)

        if env_full_domain != full_domain:
            print(f"Domain mismatch: {full_domain} != {env_full_domain}")
            return {"statusCode": 404, "body": "Not Found"}

        service_endpoint = fetch_service_instance(service_name, registry, full_domain, host)
        if isinstance(service_endpoint, dict):
            return service_endpoint

        service_uuid = get_service_uuid_from_domain(host)
        if service_uuid:
            log_request_to_cloudwatch(service_uuid, host)

        return forward_request(event, service_endpoint)
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({'error': str(e)})}


def log_request_to_cloudwatch(service_uuid, host):
    log_timestamp = int(time.time() * 1000)
    log_event = {
        "logEvents": [{
            "timestamp": log_timestamp,
            "message": f"Request at {log_timestamp} for {host}"
        }],
        "logGroupName": ecs_access_log_group_name,
        "logStreamName": service_uuid
    }

    start_time = time.time()
    cloudwatch_client.put_log_events(**log_event)
    log_execution_time(start_time, "CloudWatch log entry")


def forward_request(event, service_endpoint):
    path = event.get('path', "")
    url = f"http://{service_endpoint}{path}"  # TODO: Support HTTPS

    print(f"Forwarding request to {url}")
    method = event["httpMethod"]

    request_functions = {
        "GET": requests.get,
        "POST": requests.post,
        "PUT": requests.put,
        "DELETE": requests.delete,
        "PATCH": requests.patch,
    }

    if method not in request_functions:
        raise Exception(f"Unsupported HTTP method: {method}")

    start_time = time.time()
    response = request_functions[method](url, headers=event['headers'], data=event['body'], timeout=10)
    log_execution_time(start_time, "HTTP request forwarding")

    return {
        'statusCode': response.status_code,
        'body': response.text,
        'headers': {'Content-Type': response.headers.get('Content-Type', 'application/json')},
    }