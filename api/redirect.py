import logging
import time

from botocore.exceptions import ClientError

from utils import get_table, is_valid_code, response

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    code = (event.get("pathParameters") or {}).get("code", "")
    if not is_valid_code(code):
        return response(404, {"error": "Link not found"})

    table = get_table()
    item = table.get_item(Key={"code": code}).get("Item")

    # DynamoDB TTL deletes lazily (can lag by hours), so check expiry ourselves
    if not item or int(item.get("expires_at", 0)) < time.time():
        return response(404, {"error": "Link not found"})

    try:
        table.update_item(
            Key={"code": code},
            UpdateExpression="ADD clicks :one",
            ExpressionAttributeValues={":one": 1},
        )
    except ClientError:
        # A failed counter must never block the redirect
        logger.exception("Could not increment click counter for %s", code)

    return {
        "statusCode": 302,
        "headers": {"Location": item["long_url"], "Cache-Control": "no-store"},
        "body": "",
    }