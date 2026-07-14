import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

import { FeishuAssistantsPanel } from "./FeishuAssistantsPanel";

const FEISHU_REGION_LABELS = {
  feishu: "Feishu",
  lark: "Lark",
};

export default {
  Panel: FeishuAssistantsPanel,
  aliases: {
    lark: {
      displayName: "Lark",
      initials: "LK",
      logoUrl: "https://www.larksuite.com/favicon.ico",
    },
  },
  presentation: {
    displayName: "Feishu",
    description: "Use nanobot from Feishu chats and groups.",
    requirements: "Feishu app credentials, event subscription, gateway",
    initials: "FS",
    color: "#3370FF",
    logoUrl: "https://www.feishu.cn/favicon.ico",
    setup: {
      mode: "connect",
      primaryActionLabel: "Connect with Feishu",
      command: "nanobot channels login feishu",
      docsUrl: chatAppGuideUrl("feishu"),
      docsLabel: "Open Feishu setup",
      officialLabel: "Open Feishu console",
      tryIt: "Send a DM or mention the Feishu assistant in a group.",
      summary:
        "Connect creates or links a Feishu app by QR code, then saves the app credentials for nanobot.",
      steps: [
        "Click Connect and scan the QR code with Feishu or Lark on your phone.",
        "Approve the app connection. nanobot saves the App ID and Secret automatically.",
        "Send the bot a direct message or mention it in a Feishu group to test it.",
      ],
      manualFields: [
        {
          key: "channels.feishu.appId",
          label: "App ID",
          placeholder: "cli_xxx",
        },
        {
          key: "channels.feishu.appSecret",
          label: "App Secret",
          placeholder: "Leave blank to keep current secret",
          help: "Paste a new App Secret only when rotating credentials.",
        },
        {
          key: "channels.feishu.domain",
          label: "Region",
          choiceLabels: FEISHU_REGION_LABELS,
        },
        {
          key: "channels.feishu.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
        {
          key: "channels.feishu.allowFrom",
          label: "Allowed users",
          placeholder: "User IDs, comma separated",
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
