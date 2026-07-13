"""NapCat management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import DIRECT_GROUP_POLICIES, field, required

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "wsUrl": field(),
        "accessToken": field("secret"),
        "allowFrom": field("list"),
        "groupPolicy": field("enum", choices=DIRECT_GROUP_POLICIES),
    },
    required=(required("wsUrl"),),
    official_url="https://napneko.github.io/",
)
