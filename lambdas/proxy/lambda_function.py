import json
import boto3
import requests
from os import environ

# from cachetools import TTLCache

# Initialize CloudMap client
cloudmap_client = boto3.client('servicediscovery')
cloudmap_namespace = environ.get("cloudmap_namespace")

# In-memory cache with TTL of 60 seconds for service resolution
# cache = TTLCache(maxsize=1000, ttl=60)

def get_service_for_subdomain(service_name):
    # if service_name in cache:
    # return cache[service_name]

    try:
        response = cloudmap_client.discover_instances(
            NamespaceName=cloudmap_namespace,
            ServiceName=service_name
        )
        instances = response.get('Instances', [])
        if not instances:
            # todo add the ability to send user to static page that wakes
            raise Exception(f"Service not found for {service_name}")

        # Assume the first instance is the correct one as there should only ever be 1
        service_endpoint = instances[0]['Attributes'].get('AWS_INSTANCE_IPV4', '')
        if not service_endpoint:
            raise Exception(f"No valid endpoint found for {service_name}")

        # Cache the result
        # cache[service_name] = service_endpoint

        return service_endpoint
    except Exception as e:
        raise Exception(f"Failed to discover service: {str(e)}")


def lambda_handler(event, context):
    try:
        # Extract PR, repo, user from subdomain in the 'Host' header
        host = event['headers']['Host']
        parts = host.split('.')

        # Assume the structure is pr1234-strelix-org.gh.example.com
        if len(parts) < 4:
            raise Exception("Invalid subdomain format")

        service_name = parts[0]
        registry = parts[1]

        # Get the service endpoint from CloudMap or cache
        service_endpoint = get_service_for_subdomain(f"{service_name}.{registry}.{parts[3]}.{parts[4]}")  # todo handle TLDs like .co.uk where it

        print(service_endpoint)

        # Forward the request to the resolved service
        url = f"http://{service_endpoint}"  # todo: support https


        # todo add async call to reset eventbridge schedule

        response = requests.get(url, headers=event['headers'], data=event['body'], timeout=10)  # todo add multiple timeout options

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
