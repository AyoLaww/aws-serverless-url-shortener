import json
import time

import create_link

DOMAIN = "abc123.execute-api.eu-west-1.amazonaws.com"


def make_event(body):
    raw = body if isinstance(body, str) or body is None else json.dumps(body)
    return {"body": raw, "requestContext": {"domainName": DOMAIN}}


def test_creates_short_link(table):
    result = create_link.handler(make_event({"url": "https://example.com/some/long/path"}), None)

    assert result["statusCode"] == 201
    data = json.loads(result["body"])
    assert data["short_url"] == f"https://{DOMAIN}/{data['code']}"

    item = table.get_item(Key={"code": data["code"]})["Item"]
    assert item["long_url"] == "https://example.com/some/long/path"
    assert item["clicks"] == 0
    assert item["expires_at"] > time.time()


def test_uses_base_url_env_when_set(table, monkeypatch):
    monkeypatch.setenv("BASE_URL", "https://short.example.com/")
    result = create_link.handler(make_event({"url": "https://example.com"}), None)
    data = json.loads(result["body"])
    assert data["short_url"] == f"https://short.example.com/{data['code']}"


def test_rejects_invalid_url(table):
    result = create_link.handler(make_event({"url": "javascript:alert(1)"}), None)
    assert result["statusCode"] == 400


def test_rejects_missing_body(table):
    assert create_link.handler(make_event(None), None)["statusCode"] == 400


def test_rejects_bad_json(table):
    assert create_link.handler(make_event("{not json"), None)["statusCode"] == 400


def test_rejects_non_object_json(table):
    assert create_link.handler(make_event("[1, 2, 3]"), None)["statusCode"] == 400


def test_returns_500_when_codes_keep_colliding(table, monkeypatch):
    table.put_item(Item={"code": "AAAAAAA", "long_url": "https://x.com", "expires_at": 9999999999, "clicks": 0})
    monkeypatch.setattr(create_link, "generate_code", lambda: "AAAAAAA")

    result = create_link.handler(make_event({"url": "https://example.com"}), None)

    assert result["statusCode"] == 500