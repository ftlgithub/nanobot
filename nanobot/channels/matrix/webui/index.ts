import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  GROUP_BEHAVIOR_LABELS,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "Matrix",
    description: "Use nanobot from Matrix rooms.",
    requirements: "Homeserver, account token, room access",
    initials: "MX",
    color: "#0DBD8B",
    logoUrl: "https://matrix.org/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("matrix"),
      docsLabel: "Open Matrix setup",
      officialLabel: "Open Matrix clients",
      tryIt: "Invite the Matrix account into a room and send a test message.",
      summary: "Matrix needs a homeserver account and either password login or an access token.",
      steps: [
        "Create or choose a Matrix account for nanobot.",
        "Add homeserver and login credentials under channels.matrix.",
        "Invite the account into the rooms nanobot should read, then restart nanobot.",
      ],
      fields: [
        { key: "channels.matrix.homeserver", label: "Homeserver", placeholder: "https://matrix.org" },
        { key: "channels.matrix.userId", label: "User ID", placeholder: "@nanobot:matrix.org" },
        {
          key: "channels.matrix.password",
          label: "Password",
          placeholder: "••••••",
          help: "Use either password login or access token login.",
        },
        {
          key: "channels.matrix.accessToken",
          label: "Access token",
          placeholder: "Optional token login",
          help: "Preferred when your Matrix client exposes an access token.",
        },
        {
          key: "channels.matrix.deviceId",
          label: "Device ID",
          placeholder: "Required with an access token",
          help: "Copy the device ID associated with the access token. Password login does not need it.",
        },
        {
          key: "channels.matrix.groupPolicy",
          label: "Group behavior",
          choiceLabels: GROUP_BEHAVIOR_LABELS,
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
