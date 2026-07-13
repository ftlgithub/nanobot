"""Telegram management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import GROUP_POLICIES, field, required

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "token": field("secret"),
        "allowFrom": field("list"),
        "groupPolicy": field("enum", choices=GROUP_POLICIES),
    },
    required=(required("token"),),
    official_url="https://t.me/BotFather",
)
