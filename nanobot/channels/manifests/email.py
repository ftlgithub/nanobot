"""Email management contract."""

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests._shared import field, required_fields

SETUP_SPEC = ChannelSetupSpec(
    fields={
        "consentGranted": field("bool"),
        "imapHost": field(),
        "imapPort": field("int"),
        "imapUsername": field(),
        "imapPassword": field("secret"),
        "smtpHost": field(),
        "smtpPort": field("int"),
        "smtpUsername": field(),
        "smtpPassword": field("secret"),
        "fromAddress": field(),
        "pollIntervalSeconds": field("int"),
        "allowFrom": field("list"),
        "verifyDkim": field("bool"),
        "verifySpf": field("bool"),
    },
    required=required_fields(
        "consentGranted",
        "imapHost",
        "imapUsername",
        "imapPassword",
        "smtpHost",
        "smtpUsername",
        "smtpPassword",
    ),
    official_url="https://support.google.com/accounts/answer/185833",
)
