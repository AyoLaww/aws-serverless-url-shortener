import ipaddress
import json
import os
import re
import secrets
import string
from urllib.parse import urlparse

import boto3

ALPHABET = string.ascii_letters + string.digits
CODE_LENGTH = 7
CODE_PATTERN = re.compile("[0-9A-Za-z]{%d}" % CODE_LENGTH)
MAX_URL_LENGTH = 2048

_table = None


def get_table():
    """Create the DynamoDB table handle once per Lambda container and reuse it."""
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    return _table


def generate_code(length=CODE_LENGTH):
    """Random base62 code. secrets (not random) so codes can't be predicted."""
    return "".join(secrets.choice(ALPHABET) for _ in range(length))


def is_valid_code(code):
    return bool(CODE_PATTERN.fullmatch(code or ""))


def validate_url(url):
    """Return an error message if the URL is unacceptable, otherwise None."""
    if not isinstance(url, str) or not url.strip():
        return "A 'url' field is required"
    if len(url) > MAX_URL_LENGTH:
        return f"URL must be at most {MAX_URL_LENGTH} characters"
    try:
        parsed = urlparse(url)
        host = parsed.hostname
    except ValueError:
        return "URL is malformed"
    if parsed.scheme not in ("http", "https"):
        return "URL must start with http:// or https://"
    if not host:
        return "URL must include a hostname"
    if host == "localhost" or host.endswith(".localhost"):
        return "URL points to a local address"
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return None  # a normal domain name
    if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
        return "URL points to a private address"
    return None


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }