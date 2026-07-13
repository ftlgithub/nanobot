import ast
import pkgutil
from pathlib import Path

import nanobot.channels._setup as channel_setup_module
import nanobot.channels.manifests as manifest_package
from nanobot.channels._setup import channel_setup_spec

EXPECTED_SETUP_CHANNELS = {
    "dingtalk",
    "discord",
    "email",
    "feishu",
    "matrix",
    "mattermost",
    "msteams",
    "napcat",
    "qq",
    "signal",
    "slack",
    "telegram",
    "websocket",
    "wecom",
    "weixin",
    "whatsapp",
}


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


def test_all_builtin_setup_contracts_are_dependency_free_manifests() -> None:
    manifest_names = {
        name
        for _, name, ispkg in pkgutil.iter_modules(
            [str(Path(manifest_package.__file__).parent)]
        )
        if not name.startswith("_") and not ispkg
    }

    assert not hasattr(channel_setup_module, "CHANNEL_SETUP_SPECS")
    assert manifest_names == EXPECTED_SETUP_CHANNELS
    assert all(channel_setup_spec(name) is not None for name in manifest_names)

    feishu = channel_setup_spec("feishu")
    assert feishu is not None and feishu.multi_instance is True
    assert feishu.simple_required_fields == ("appId", "appSecret")


def test_builtin_setup_manifests_only_import_contract_modules() -> None:
    manifest_dir = Path(manifest_package.__file__).parent
    allowed_imports = {
        "nanobot.channels.contracts",
        "nanobot.channels.manifests._shared",
    }

    for name in EXPECTED_SETUP_CHANNELS:
        tree = ast.parse((manifest_dir / f"{name}.py").read_text(encoding="utf-8"))
        imports: set[str] = set()
        for node in tree.body:
            if isinstance(node, ast.Import):
                imports.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imports.add(node.module)
        assert imports <= allowed_imports, f"{name} imports runtime dependencies: {imports}"
