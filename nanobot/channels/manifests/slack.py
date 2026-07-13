"""Slack management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import GROUP_POLICIES, field, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "appToken": field("secret"),
        "botToken": field("secret"),
        "groupPolicy": field("enum", choices=GROUP_POLICIES),
    },
    required=required_fields("appToken", "botToken"),
    official_url="https://api.slack.com/apps",
)
