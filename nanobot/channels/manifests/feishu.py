"""Dependency-free Feishu/Lark management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import DIRECT_GROUP_POLICIES, field, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "appId": field(snapshot=False),
        "appSecret": field("secret", snapshot=False),
        "domain": field(
            "enum",
            choices={"feishu", "lark"},
            snapshot=False,
        ),
        "groupPolicy": field(
            "enum",
            choices=DIRECT_GROUP_POLICIES,
            snapshot=False,
        ),
        "allowFrom": field("list", snapshot=False),
        "topicIsolation": field("bool", snapshot=False),
    },
    required=required_fields("appId", "appSecret"),
    official_url="https://open.feishu.cn/app",
    multi_instance=True,
)
