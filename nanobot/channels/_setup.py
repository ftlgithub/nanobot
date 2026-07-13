"""Built-in channel setup metadata and plugin contract resolution."""

from __future__ import annotations

from typing import Any

from nanobot.channels.contracts import (
    ChannelFieldSpec,
    ChannelSetupSpec,
    FieldKind,
    SetupRequirement,
)
from nanobot.channels.manifests import load_builtin_setup_spec


def _field(
    kind: FieldKind = "string",
    *,
    choices: set[str] | None = None,
    writable: bool = True,
    snapshot: bool = True,
) -> ChannelFieldSpec:
    return ChannelFieldSpec(
        kind=kind,
        choices=frozenset(choices or ()),
        writable=writable,
        snapshot=snapshot,
    )


def _required(field: str) -> SetupRequirement:
    return SetupRequirement.field(field)


def _one_of(*alternatives: tuple[str, ...]) -> SetupRequirement:
    return SetupRequirement.one_of(*alternatives)


_GROUP_POLICIES = {"mention", "open", "allowlist"}
_DIRECT_GROUP_POLICIES = {"mention", "open"}

CHANNEL_SETUP_SPECS: dict[str, ChannelSetupSpec] = {
    "websocket": ChannelSetupSpec(
        fields={},
        official_url="http://127.0.0.1:8765",
    ),
    "telegram": ChannelSetupSpec(
        fields={
            "token": _field("secret"),
            "allowFrom": _field("list"),
            "groupPolicy": _field("enum", choices=_GROUP_POLICIES),
        },
        required=(_required("token"),),
        official_url="https://t.me/BotFather",
    ),
    "slack": ChannelSetupSpec(
        fields={
            "appToken": _field("secret"),
            "botToken": _field("secret"),
            "groupPolicy": _field("enum", choices=_GROUP_POLICIES),
        },
        required=(_required("appToken"), _required("botToken")),
        official_url="https://api.slack.com/apps",
    ),
    "discord": ChannelSetupSpec(
        fields={
            "token": _field("secret"),
            "allowFrom": _field("list", snapshot=False),
            "allowChannels": _field("list"),
            "groupPolicy": _field("enum", choices=_DIRECT_GROUP_POLICIES),
        },
        required=(_required("token"),),
        official_url="https://discord.com/developers/applications",
    ),
    "email": ChannelSetupSpec(
        fields={
            "consentGranted": _field("bool"),
            "imapHost": _field(),
            "imapPort": _field("int"),
            "imapUsername": _field(),
            "imapPassword": _field("secret"),
            "smtpHost": _field(),
            "smtpPort": _field("int"),
            "smtpUsername": _field(),
            "smtpPassword": _field("secret"),
            "fromAddress": _field(),
            "pollIntervalSeconds": _field("int"),
            "allowFrom": _field("list"),
            "verifyDkim": _field("bool"),
            "verifySpf": _field("bool"),
        },
        required=tuple(
            _required(field)
            for field in (
                "consentGranted",
                "imapHost",
                "imapUsername",
                "imapPassword",
                "smtpHost",
                "smtpUsername",
                "smtpPassword",
            )
        ),
        official_url="https://support.google.com/accounts/answer/185833",
    ),
    "matrix": ChannelSetupSpec(
        fields={
            "homeserver": _field(),
            "userId": _field(),
            "password": _field("secret"),
            "accessToken": _field("secret"),
            "deviceId": _field(),
            "groupPolicy": _field("enum", choices=_GROUP_POLICIES),
            "allowFrom": _field("list", writable=False),
        },
        required=(
            _required("homeserver"),
            _required("userId"),
            _one_of(("password",), ("accessToken", "deviceId")),
        ),
        official_url="https://matrix.org/ecosystem/clients/",
    ),
    "mattermost": ChannelSetupSpec(
        fields={
            "serverUrl": _field(),
            "token": _field("secret"),
            "teamId": _field(),
            "groupPolicy": _field("enum", choices=_GROUP_POLICIES),
            "allowFrom": _field("list"),
        },
        required=(_required("serverUrl"), _required("token")),
        official_url="https://developers.mattermost.com/integrate/reference/bot-accounts/",
    ),
    "whatsapp": ChannelSetupSpec(
        fields={
            "allowFrom": _field("list", snapshot=False),
            "groupPolicy": _field("enum", choices=_DIRECT_GROUP_POLICIES, snapshot=False),
            "databasePath": _field(writable=False, snapshot=False),
        },
        official_url="https://faq.whatsapp.com/",
    ),
    "dingtalk": ChannelSetupSpec(
        fields={
            "clientId": _field(),
            "clientSecret": _field("secret"),
            "allowFrom": _field("list"),
        },
        required=(_required("clientId"), _required("clientSecret")),
        official_url="https://open.dingtalk.com/",
    ),
    "wecom": ChannelSetupSpec(
        fields={
            "botId": _field(),
            "secret": _field("secret"),
            "allowFrom": _field("list"),
        },
        required=(_required("botId"), _required("secret")),
        official_url="https://developer.work.weixin.qq.com/",
    ),
    "weixin": ChannelSetupSpec(
        fields={
            "token": _field("secret"),
            "allowFrom": _field("list"),
        },
        required=(_required("token"),),
        official_url="https://weixin.qq.com/",
    ),
    "qq": ChannelSetupSpec(
        fields={
            "appId": _field(),
            "secret": _field("secret"),
            "allowFrom": _field("list"),
            "msgFormat": _field("enum", choices={"plain", "markdown"}),
        },
        required=(_required("appId"), _required("secret")),
        official_url="https://q.qq.com/",
    ),
    "signal": ChannelSetupSpec(
        fields={
            "phoneNumber": _field(),
            "daemonHost": _field(),
            "daemonPort": _field("int"),
            "allowFrom": _field("list", snapshot=False),
            "dm.allowFrom": _field("list"),
            "group.allowFrom": _field("list"),
        },
        required=(_required("phoneNumber"),),
        official_url="https://github.com/bbernhard/signal-cli-rest-api",
    ),
    "msteams": ChannelSetupSpec(
        fields={
            "appId": _field(),
            "appPassword": _field("secret"),
            "tenantId": _field(),
            "path": _field(),
            "allowFrom": _field("list"),
        },
        required=(_required("appId"), _required("appPassword")),
        official_url="https://dev.teams.microsoft.com/apps",
    ),
    "napcat": ChannelSetupSpec(
        fields={
            "wsUrl": _field(),
            "accessToken": _field("secret"),
            "allowFrom": _field("list"),
            "groupPolicy": _field("enum", choices=_DIRECT_GROUP_POLICIES),
        },
        required=(_required("wsUrl"),),
        official_url="https://napneko.github.io/",
    ),
}


def channel_setup_spec(
    name: str,
    channel_cls: type[Any] | None = None,
) -> ChannelSetupSpec | None:
    """Return a channel-owned setup contract, falling back to built-in metadata.

    External plugins provide ``setup_spec`` on ``BaseChannel``. Built-ins use
    dependency-free manifest modules so settings discovery never imports an
    optional platform SDK. The table remains only as a migration fallback.
    """
    if channel_cls is not None:
        spec = channel_cls.setup_spec()
        if spec is not None:
            if not isinstance(spec, ChannelSetupSpec):
                raise TypeError(
                    f"{channel_cls.__name__}.setup_spec() must return ChannelSetupSpec or None"
                )
            return spec
    if spec := load_builtin_setup_spec(name):
        return spec
    return CHANNEL_SETUP_SPECS.get(name)
