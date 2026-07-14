import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "Discord",
    description: "Use nanobot from Discord servers and DMs.",
    requirements: "Discord bot token, permissions, gateway",
    initials: "DC",
    color: "#5865F2",
    logoUrl: "https://discord.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("discord"),
      docsLabel: "Open Discord setup",
      officialLabel: "Open Discord portal",
      tryIt: "Mention the bot in a server or send it a direct message.",
      summary: "Enable turns on Discord support. Discord still needs a bot token and server permissions.",
      steps: [
        "Create an application and bot in the Discord Developer Portal, then copy the bot token.",
        "Invite the bot to your server with message read/send and slash command permissions.",
        "Add the token under channels.discord.token; optionally restrict allowFrom and allowChannels.",
        "Save and enable Discord, then mention the bot or use its slash command.",
      ],
      fields: [
        {
          key: "channels.discord.token",
          label: "Bot token",
          placeholder: "Discord bot token",
          help: "Create it from the Bot page in Discord Developer Portal.",
        },
        {
          key: "channels.discord.allowChannels",
          label: "Allowed channels",
          placeholder: "Channel IDs, comma separated",
          help: "Leave empty to allow any channel the bot can read.",
        },
        {
          key: "channels.discord.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
