"""Matrix management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import GROUP_POLICIES, field, one_of, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "homeserver": field(),
        "userId": field(),
        "password": field("secret"),
        "accessToken": field("secret"),
        "deviceId": field(),
        "groupPolicy": field("enum", choices=GROUP_POLICIES),
        "allowFrom": field("list", writable=False),
    },
    required=(
        *required_fields("homeserver", "userId"),
        one_of(("password",), ("accessToken", "deviceId")),
    ),
    official_url="https://matrix.org/ecosystem/clients/",
)
