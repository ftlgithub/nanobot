import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "WeCom",
    description: "Use nanobot from WeCom work chats.",
    requirements: "WeCom app credentials and callback settings",
    initials: "WC",
    color: "#2F7DFF",
    logoUrl: "https://work.weixin.qq.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("wecom"),
      docsLabel: "Open WeCom setup",
      officialLabel: "Open WeCom console",
      tryIt: "Send a test message to the WeCom bot.",
      summary: "WeCom needs an AI bot ID and secret from the WeCom admin console.",
      steps: [
        "Create or choose a WeCom AI Bot.",
        "Add Bot ID and Secret.",
        "Save and enable WeCom, then send a test message.",
      ],
      fields: [
        {
          key: "channels.wecom.botId",
          label: "Bot ID",
          placeholder: "WeCom bot ID",
          help: "Copy it from the WeCom AI Bot API mode page.",
        },
        {
          key: "channels.wecom.secret",
          label: "Secret",
          placeholder: "••••••",
          help: "Keep the WeCom bot secret private.",
        },
        {
          key: "channels.wecom.allowFrom",
          label: "Allowed users",
          placeholder: "User IDs, comma separated",
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
