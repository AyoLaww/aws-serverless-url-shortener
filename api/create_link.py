import json
import logging
import os
import time
from datetime import datetime, timezone

from botocore.exceptions import ClientError

from utils import generate_code, get_table, response, validate_url

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TTL_DAYS = int(os.environ.get("LINK_TTL_DAYS", "90"))
MAX_ATTEMPTS = 5


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "Request body must be valid JSON"})
    if not isinstance(body, dict):
        return response(400, {"error": "Request body must be a JSON object"})

    long_url = body.get("url")
    if isinstance(long_url, str):
        long_url = long_url.strip()
    error = validate_url(long_url)
    if error:
        return response(400, {"error": error})

    now = int(time.time())
    table = get_table()

    for _ in range(MAX_ATTEMPTS):
        code = generate_code()
        try:
            table.put_item(
                Item={
                    "code": code,
                    "long_url": long_url,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "expires_at": now + TTL_DAYS * 86400,
                    "clicks": 0,
                },
                # Never overwrite an existing code
                ConditionExpression="attribute_not_exists(code)",
            )
            break
        except ClientError as err:
            if err.response["Error"]["Code"] != "ConditionalCheckFailedException":
                raise
            logger.warning("Code collision, retrying")
    else:
        return response(500, {"error": "Could not generate a unique code, try again"})

    base_url = os.environ.get("BASE_URL") or "https://" + event["requestContext"]["domainName"]
    base_url = base_url.rstrip("/")
    logger.info("Created link %s", code)
    return response(201, {"code": code, "short_url": f"{base_url}/{code}", "long_url": long_url})