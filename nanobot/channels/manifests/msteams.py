"""Microsoft Teams management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import field, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "appId": field(),
        "appPassword": field("secret"),
        "tenantId": field(),
        "path": field(),
        "allowFrom": field("list"),
    },
    required=required_fields("appId", "appPassword"),
    official_url="https://dev.teams.microsoft.com/apps",
)
