"""Mattermost management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import GROUP_POLICIES, field, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "serverUrl": field(),
        "token": field("secret"),
        "teamId": field(),
        "groupPolicy": field("enum", choices=GROUP_POLICIES),
        "allowFrom": field("list"),
    },
    required=required_fields("serverUrl", "token"),
    official_url="https://developers.mattermost.com/integrate/reference/bot-accounts/",
)
