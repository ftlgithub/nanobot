import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

const QQ_MESSAGE_FORMAT_LABELS = {
  plain: "Plain text",
  markdown: "Markdown",
};

export default {
  presentation: {
    displayName: "QQ",
    description: "Use nanobot from QQ chats.",
    requirements: "QQ bot credentials and gateway",
    initials: "QQ",
    color: "#12B7F5",
    logoUrl: "https://im.qq.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("qq"),
      docsLabel: "Open QQ setup",
      officialLabel: "Open QQ bot console",
      tryIt: "Send a direct or group test message from QQ.",
      summary: "QQ uses the official bot credentials and a long WebSocket connection.",
      steps: [
        "Create or choose a QQ bot application and copy its App ID and Secret.",
        "Add appId and secret under channels.qq.",
        "Save and enable QQ, then send a direct or group test message.",
      ],
      fields: [
        {
          key: "channels.qq.appId",
          label: "App ID",
          placeholder: "QQ bot app ID",
          help: "Copy it from QQ Open Platform.",
        },
        {
          key: "channels.qq.secret",
          label: "Secret",
          placeholder: "••••••",
          help: "Save this before leaving the QQ credentials page.",
        },
        { key: "channels.qq.allowFrom", label: "Allowed users", placeholder: "Open IDs, comma separated" },
        {
          key: "channels.qq.msgFormat",
          label: "Message format",
          choiceLabels: QQ_MESSAGE_FORMAT_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
