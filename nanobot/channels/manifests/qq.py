"""QQ management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import field, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "appId": field(),
        "secret": field("secret"),
        "allowFrom": field("list"),
        "msgFormat": field("enum", choices={"plain", "markdown"}),
    },
    required=required_fields("appId", "secret"),
    official_url="https://q.qq.com/",
)
