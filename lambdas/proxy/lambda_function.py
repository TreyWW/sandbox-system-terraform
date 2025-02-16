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

ddb = boto3.client('dynamodb')

# In-memory cache with TTL of 60 seconds for service resolution
# cache = TTLCache(maxsize=1000, ttl=60)

def get_service_for_subdomain(service_name):
    # if service_name in cache:
    # return cache[service_name]

    try:
        print(f"getting cloudmap instance for {cloudmap_namespace} name {service_name}")
        response = cloudmap_client.discover_instances(
            NamespaceName=cloudmap_namespace,
            ServiceName=service_name
        )
        instances = response.get('Instances', [])
        if not instances:
            # todo add the ability to send user to static page that wakes
            raise Exception(f"No sandbox found for {service_name}")

        # Assume the first instance is the correct one as there should only ever be 1
        service_endpoint = instances[0]['Attributes'].get('AWS_INSTANCE_IPV4', '')
        if not service_endpoint:
            raise Exception(f"No valid endpoint found for {service_name}")

        # Cache the result
        # cache[service_name] = service_endpoint

        return service_endpoint
    except Exception as e:
        raise Exception(f"Failed to find sandbox: {str(e)}")


def lambda_handler(event, context):
    try:
        # Extract PR, repo, user from subdomain in the 'Host' header
        print(event['requestContext']['domainName'])
        host = event['requestContext']['domainName']
        parts = host.split('.')

        # Assume the structure is pr1234-strelix-org.gh.example.com | todo: support .co.uk etc
        if len(parts) < 4:
            raise Exception("Invalid subdomain format")

        service_name = parts[0]
        registry = parts[1]

        # Get the service endpoint from CloudMap or cache
        service_endpoint = get_service_for_subdomain(f"{service_name}.{registry}.{parts[2]}.{parts[3]}")  # todo handle TLDs like .co.uk

        dynamo_row = ddb.query(
            TableName=environ.get("metadata_ddb_table_name"),
            IndexName="DomainIndex",
            KeyConditionExpression="#d = :d",
            ExpressionAttributeNames={"#d": "domain"},
            ExpressionAttributeValues={":d": {"S": host}}
        )

        if dynamo_row.get("Items"):
            log_timestamp = int(time.time() * 1000)
            log_event = {
                "logEvents": [{
                        "timestamp": log_timestamp,
                        "message": f"Request at {log_timestamp} for {host}"
                    }],
                "logGroupName": environ.get("ecs_access_log_group_name"),
                "logStreamName": dynamo_row["Items"][0]["uuid"]["S"]
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
        elif event["httpMethod"] ==  "PUT":
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
