import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "Mattermost",
    description: "Use nanobot from Mattermost channels and DMs.",
    requirements: "Mattermost server URL, bot token, channel access",
    initials: "MM",
    color: "#1C58D9",
    logoUrl: "https://mattermost.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("mattermost"),
      docsLabel: "Open Mattermost setup",
      officialLabel: "Open Mattermost bot guide",
      tryIt: "Mention the bot in a Mattermost channel or send it a direct message.",
      summary:
        "Mattermost connects with a bot account token and listens through the Mattermost WebSocket API.",
      steps: [
        "Create or choose a Mattermost bot account and copy its token.",
        "Add the Mattermost server URL and bot token.",
        "Invite the bot to the channels it should read.",
        "Save and enable Mattermost, then mention the bot or send a direct message.",
      ],
      fields: [
        {
          key: "channels.mattermost.serverUrl",
          label: "Server URL",
          placeholder: "https://mattermost.example.com",
          help: "Use the base URL of your Mattermost workspace.",
        },
        {
          key: "channels.mattermost.token",
          label: "Bot token",
          placeholder: "Mattermost bot token",
          help: "Create this from a Mattermost bot account.",
        },
        { key: "channels.mattermost.teamId", label: "Team ID", placeholder: "Optional team ID" },
        {
          key: "channels.mattermost.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
