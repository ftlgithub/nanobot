import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "DingTalk",
    description: "Use nanobot from DingTalk groups.",
    requirements: "DingTalk app credentials and gateway",
    initials: "DT",
    color: "#1677FF",
    logoUrl:
      "https://img.alicdn.com/imgextra/i3/O1CN01WMvMRG1ks3Ixc9x1v_!!6000000004738-55-tps-32-32.svg",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("dingtalk"),
      docsLabel: "Open DingTalk setup",
      officialLabel: "Open DingTalk console",
      tryIt: "Send a test message from the DingTalk group where the app is installed.",
      summary: "DingTalk needs app credentials from Stream mode.",
      steps: [
        "Create or choose a DingTalk app with Stream mode enabled.",
        "Add Client ID and Client Secret.",
        "Save and enable DingTalk, then send a test message.",
      ],
      fields: [
        {
          key: "channels.dingtalk.clientId",
          label: "Client ID",
          placeholder: "DingTalk client ID",
          help: "Copy it from DingTalk app credentials.",
        },
        {
          key: "channels.dingtalk.clientSecret",
          label: "Client Secret",
          placeholder: "••••••",
          help: "Copy it from the same DingTalk app credentials page.",
        },
        {
          key: "channels.dingtalk.allowFrom",
          label: "Allowed users",
          placeholder: "User IDs, comma separated",
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
