import pytest

import utils


def test_generate_code_length_and_alphabet():
    code = utils.generate_code()
    assert len(code) == utils.CODE_LENGTH
    assert set(code) <= set(utils.ALPHABET)


def test_generate_code_is_not_constant():
    assert len({utils.generate_code() for _ in range(100)}) == 100


@pytest.mark.parametrize("code", ["abc1234", "ABCdef9"])
def test_is_valid_code_accepts(code):
    assert utils.is_valid_code(code)


@pytest.mark.parametrize("code", [None, "", "short", "waytoolong", "abc 123", "abc123!", "abc123\n"])
def test_is_valid_code_rejects(code):
    assert not utils.is_valid_code(code)


@pytest.mark.parametrize(
    "url",
    [
        "https://example.com",
        "http://example.com/path?q=1#frag",
        "https://sub.example.co.ke/a/b",
    ],
)
def test_validate_url_accepts(url):
    assert utils.validate_url(url) is None


@pytest.mark.parametrize(
    "url",
    [
        None,
        "",
        "   ",
        123,
        "example.com",
        "ftp://example.com",
        "javascript:alert(1)",
        "http://",
        "http://localhost:3000",
        "http://127.0.0.1",
        "http://10.0.0.5/admin",
        "http://169.254.169.254/latest/meta-data",
        "https://example.com/" + "a" * 2100,
    ],
)
def test_validate_url_rejects(url):
    assert utils.validate_url(url) is not None