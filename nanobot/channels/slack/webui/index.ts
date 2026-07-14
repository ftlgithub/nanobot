import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

const SLACK_SOCKET_MODE_MANIFEST = `display_information:
  name: nanobot
features:
  app_home:
    home_tab_enabled: false
    messages_tab_enabled: true
    messages_tab_read_only_enabled: false
  bot_user:
    display_name: nanobot
oauth_config:
  scopes:
    bot:
      - app_mentions:read
      - channels:history
      - channels:read
      - chat:write
      - files:read
      - files:write
      - groups:history
      - groups:read
      - im:history
      - im:write
      - mpim:history
      - reactions:write
      - users:read
settings:
  event_subscriptions:
    bot_events:
      - app_mention
      - message.channels
      - message.groups
      - message.im
      - message.mpim
  socket_mode_enabled: true
  interactivity:
    is_enabled: true`;

export default {
  presentation: {
    displayName: "Slack",
    description: "Use nanobot from Slack workspaces.",
    requirements: "Slack app token, bot token, workspace install",
    initials: "SL",
    color: "#4A154B",
    logoUrl: "https://slack.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("slack"),
      docsLabel: "Open Slack setup",
      officialLabel: "Open Slack apps",
      tryIt: "Mention the Slack app or send it a direct message.",
      actions: [
        {
          id: "slack-manifest",
          label: "Copy manifest",
          copyText: SLACK_SOCKET_MODE_MANIFEST,
          logoUrl: "https://slack.com/favicon.ico",
        },
      ],
      summary: "Slack uses Socket Mode by default, so it needs both app-level and bot-level tokens.",
      steps: [
        "Create a Slack app, enable Socket Mode, and install it into the workspace.",
        "Add the app token and bot token under channels.slack.",
        "Save and enable Slack, then mention the app or send it a direct message.",
      ],
      fields: [
        {
          key: "channels.slack.appToken",
          label: "App token",
          placeholder: "xapp-...",
          help: "Create this from Slack Socket Mode.",
        },
        {
          key: "channels.slack.botToken",
          label: "Bot token",
          placeholder: "xoxb-...",
          help: "Use the bot token after installing the Slack app.",
        },
        {
          key: "channels.slack.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
