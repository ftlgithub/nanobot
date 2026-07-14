import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "WhatsApp",
    description: "Use nanobot from WhatsApp conversations.",
    requirements: "WhatsApp connection setup and gateway",
    initials: "WA",
    color: "#25D366",
    logoUrl: "https://www.whatsapp.com/favicon.ico",
    setup: {
      mode: "connect",
      primaryActionLabel: "Connect WhatsApp",
      command: "nanobot channels login whatsapp",
      docsUrl: chatAppGuideUrl("whatsapp"),
      docsLabel: "Open WhatsApp setup",
      tryIt: "After terminal login finishes, send a WhatsApp DM to the connected account.",
      summary: "WhatsApp is connected by scanning a QR code from the account that should run the bot.",
      steps: [
        "Start the WhatsApp login flow.",
        "Scan the QR code with WhatsApp on your phone.",
        "Return here after login, enable WhatsApp, then send a direct test message.",
      ],
      manualFields: [
        {
          key: "channels.whatsapp.allowFrom",
          label: "Allowed contacts",
          placeholder: "Phone numbers or WhatsApp IDs",
        },
        {
          key: "channels.whatsapp.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
