import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "Telegram",
    description: "Chat with nanobot from Telegram chats.",
    requirements: "Bot token, allowed users, gateway",
    initials: "TG",
    color: "#229ED9",
    logoUrl: "https://telegram.org/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("telegram"),
      docsLabel: "Open Telegram setup",
      officialLabel: "Open BotFather",
      tryIt: "Send /start or a short DM to your Telegram bot.",
      summary: "Enable turns on Telegram support. Telegram still needs a BotFather token before messages can flow.",
      steps: [
        "Create a bot with BotFather and copy the bot token.",
        "Add the token under channels.telegram.token; optionally restrict allowFrom and groupPolicy.",
        "Save and enable Telegram, then send the bot a direct message or mention it in a group.",
      ],
      fields: [
        {
          key: "channels.telegram.token",
          label: "Bot token",
          placeholder: "123456:ABC...",
          help: "Create it with BotFather.",
        },
        {
          key: "channels.telegram.allowFrom",
          label: "Allowed users",
          placeholder: "* or Telegram user IDs",
          help: "Leave empty to use pairing codes.",
        },
        {
          key: "channels.telegram.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
