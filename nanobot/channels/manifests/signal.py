"""Signal management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import field, required

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "phoneNumber": field(),
        "daemonHost": field(),
        "daemonPort": field("int"),
        "allowFrom": field("list", snapshot=False),
        "dm.allowFrom": field("list"),
        "group.allowFrom": field("list"),
    },
    required=(required("phoneNumber"),),
    official_url="https://github.com/bbernhard/signal-cli-rest-api",
)
