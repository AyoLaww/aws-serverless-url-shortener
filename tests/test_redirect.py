import time

import redirect


def make_event(code):
    return {"pathParameters": {"code": code}}


def put_link(table, code="abc1234", url="https://example.com", expires_at=None):
    table.put_item(
        Item={
            "code": code,
            "long_url": url,
            "clicks": 0,
            "expires_at": expires_at if expires_at is not None else int(time.time()) + 3600,
        }
    )


def test_redirects_to_long_url(table):
    put_link(table)
    result = redirect.handler(make_event("abc1234"), None)
    assert result["statusCode"] == 302
    assert result["headers"]["Location"] == "https://example.com"


def test_increments_click_counter(table):
    put_link(table)
    redirect.handler(make_event("abc1234"), None)
    redirect.handler(make_event("abc1234"), None)
    assert table.get_item(Key={"code": "abc1234"})["Item"]["clicks"] == 2


def test_unknown_code_returns_404(table):
    assert redirect.handler(make_event("zzzzzzz"), None)["statusCode"] == 404


def test_expired_link_returns_404(table):
    put_link(table, expires_at=int(time.time()) - 10)
    assert redirect.handler(make_event("abc1234"), None)["statusCode"] == 404


def test_malformed_code_returns_404(table):
    assert redirect.handler(make_event("bad!"), None)["statusCode"] == 404


def test_missing_path_parameters_returns_404(table):
    assert redirect.handler({}, None)["statusCode"] == 404