"""Dependency-free Feishu/Lark management contract."""

from nanobot.channels.contracts import ChannelFieldSpec, ChannelSetupSpec, SetupRequirement

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "appId": ChannelFieldSpec(snapshot=False),
        "appSecret": ChannelFieldSpec(kind="secret", snapshot=False),
        "domain": ChannelFieldSpec(
            kind="enum",
            choices=frozenset({"feishu", "lark"}),
            snapshot=False,
        ),
        "groupPolicy": ChannelFieldSpec(
            kind="enum",
            choices=frozenset({"mention", "open"}),
            snapshot=False,
        ),
        "allowFrom": ChannelFieldSpec(kind="list", snapshot=False),
        "topicIsolation": ChannelFieldSpec(kind="bool", snapshot=False),
    },
    required=(
        SetupRequirement.field("appId"),
        SetupRequirement.field("appSecret"),
    ),
    official_url="https://open.feishu.cn/app",
    multi_instance=True,
)
