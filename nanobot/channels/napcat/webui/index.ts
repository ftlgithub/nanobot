import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "NapCat",
    description: "Connect nanobot through a NapCat gateway.",
    requirements: "NapCat WebSocket endpoint, optional access token",
    initials: "NC",
    color: "#F97316",
    logoUrl: "https://napneko.github.io/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("napcat"),
      docsLabel: "Open NapCat setup",
      officialLabel: "Open NapCat docs",
      tryIt: "Send a QQ test message through NapCat.",
      summary: "NapCat connects nanobot to QQ through a local or remote OneBot WebSocket endpoint.",
      steps: [
        "Start NapCat and enable its OneBot WebSocket server.",
        "Set wsUrl to the NapCat WebSocket endpoint; add accessToken if NapCat requires one.",
        "Save and enable NapCat, then send a QQ test message.",
      ],
      fields: [
        {
          key: "channels.napcat.wsUrl",
          label: "WebSocket URL",
          placeholder: "ws://127.0.0.1:3001",
          help: "Use the Forward WebSocket URL from NapCat.",
        },
        { key: "channels.napcat.accessToken", label: "Access token", placeholder: "Optional token" },
        {
          key: "channels.napcat.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
        { key: "channels.napcat.allowFrom", label: "Allowed users", placeholder: "QQ IDs, comma separated" },
      ],
    },
  },
} satisfies ChannelUiContribution;
