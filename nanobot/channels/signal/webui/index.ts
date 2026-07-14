import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "Signal",
    description: "Use nanobot from Signal messages.",
    requirements: "signal-cli HTTP daemon, phone number, allowlist",
    initials: "SG",
    color: "#3A76F0",
    logoUrl: "https://signal.org/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("signal"),
      docsLabel: "Open Signal setup",
      officialLabel: "Open signal-cli guide",
      tryIt: "Send a Signal DM to the linked phone number.",
      summary:
        "Signal connects through a local signal-cli HTTP daemon. Run the daemon first, then point nanobot at it.",
      steps: [
        "Register or link the Signal account in signal-cli.",
        "Start signal-cli in HTTP daemon mode for the same phone number.",
        "Set phoneNumber plus daemon host and port under channels.signal.",
        "Save and enable Signal, then send a direct test message.",
      ],
      fields: [
        {
          key: "channels.signal.phoneNumber",
          label: "Phone number",
          placeholder: "+1234567890",
          help: "Use the Signal number registered with signal-cli.",
        },
        { key: "channels.signal.daemonHost", label: "Daemon host", placeholder: "localhost" },
        { key: "channels.signal.daemonPort", label: "Daemon port", placeholder: "8080" },
        {
          key: "channels.signal.dm.allowFrom",
          label: "Allowed DMs",
          placeholder: "Phone numbers or UUIDs",
        },
        {
          key: "channels.signal.group.allowFrom",
          label: "Allowed groups",
          placeholder: "Group IDs",
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
