import boto3
import pytest
from moto import mock_aws

import utils

TABLE_NAME = "links-test"


@pytest.fixture(autouse=True)
def aws_env(monkeypatch):
    # Fake credentials so tests can never touch your real AWS account
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-west-1")
    monkeypatch.setenv("TABLE_NAME", TABLE_NAME)
    monkeypatch.delenv("BASE_URL", raising=False)
    utils._table = None
    yield
    utils._table = None


@pytest.fixture
def table():
    with mock_aws():
        yield boto3.resource("dynamodb").create_table(
            TableName=TABLE_NAME,
            KeySchema=[{"AttributeName": "code", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "code", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )