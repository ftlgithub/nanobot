from nanobot.channels._setup import CHANNEL_SETUP_SPECS, channel_setup_spec


def test_channel_setup_spec_derives_route_and_secret_metadata() -> None:
    slack = channel_setup_spec("slack")

    assert slack is not None
    assert slack.secrets == {"appToken", "botToken"}
    assert slack.route_field_types == {
        "appToken": "secret",
        "botToken": "secret",
        "groupPolicy": ("enum", {"mention", "open", "allowlist"}),
    }
    assert slack.simple_required_fields == ("appToken", "botToken")


def test_matrix_setup_requires_one_complete_login_method() -> None:
    matrix = channel_setup_spec("matrix")

    assert matrix is not None
    base = {
        "homeserver": "https://matrix.example",
        "userId": "@nanobot:matrix.example",
    }
    assert matrix.is_configured(base | {"password": "secret"})
    assert matrix.is_configured(base | {"accessToken": "token", "deviceId": "DEVICE"})
    assert not matrix.is_configured(base | {"accessToken": "token"})


def test_channel_setup_spec_separates_writable_and_snapshot_fields() -> None:
    matrix = channel_setup_spec("matrix")
    discord = channel_setup_spec("discord")

    assert matrix is not None
    assert discord is not None
    assert "allowFrom" not in matrix.route_field_types
    assert "allowFrom" in matrix.snapshot_fields
    assert "allowFrom" in discord.route_field_types
    assert "allowFrom" not in discord.snapshot_fields


def test_webui_forms_have_writable_mattermost_and_whatsapp_contracts() -> None:
    mattermost = channel_setup_spec("mattermost")
    whatsapp = channel_setup_spec("whatsapp")

    assert mattermost is not None
    assert whatsapp is not None
    assert mattermost.route_field_types["serverUrl"] == "string"
    assert mattermost.route_field_types["token"] == "secret"
    assert whatsapp.route_field_types["allowFrom"] == "list"
    assert whatsapp.route_field_types["groupPolicy"] == (
        "enum",
        {"mention", "open"},
    )


def test_feishu_setup_is_owned_by_dependency_free_manifest() -> None:
    feishu = channel_setup_spec("feishu")

    assert "feishu" not in CHANNEL_SETUP_SPECS
    assert feishu is not None
    assert feishu.multi_instance is True
    assert feishu.simple_required_fields == ("appId", "appSecret")
