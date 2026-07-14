import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "Microsoft Teams",
    description: "Use nanobot from Microsoft Teams chats.",
    requirements: "Azure bot app credentials, public callback endpoint",
    initials: "MS",
    color: "#6264A7",
    logoUrl: "https://www.microsoft.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("msteams"),
      docsLabel: "Open Teams setup",
      officialLabel: "Open Teams developer portal",
      tryIt: "Install the Teams app and send a test message.",
      summary:
        "Teams receives messages through the Bot Framework callback URL. It needs a reachable HTTPS endpoint in production.",
      steps: [
        "Create an Azure Bot / Teams app and copy the Microsoft App ID and client secret.",
        "Set the bot messaging endpoint to the nanobot Teams callback path.",
        "Add appId and appPassword under channels.msteams.",
        "Save and enable Teams, then install the app and send a test message.",
      ],
      fields: [
        {
          key: "channels.msteams.appId",
          label: "App ID",
          placeholder: "Microsoft App ID",
          help: "Copy it from the Azure Bot or Teams app registration.",
        },
        {
          key: "channels.msteams.appPassword",
          label: "Client secret",
          placeholder: "••••••",
          help: "Create a client secret for the Microsoft app.",
        },
        { key: "channels.msteams.tenantId", label: "Tenant ID", placeholder: "Optional tenant ID" },
        { key: "channels.msteams.path", label: "Callback path", placeholder: "/api/messages" },
        {
          key: "channels.msteams.allowFrom",
          label: "Allowed users",
          placeholder: "Teams user IDs, comma separated",
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
