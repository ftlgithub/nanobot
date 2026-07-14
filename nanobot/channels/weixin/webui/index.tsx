import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

import { WeixinConnectFlow } from "./WeixinConnectFlow";

export default {
  ConnectFlow: WeixinConnectFlow,
  canConnectBeforeConfigured: true,
  aliases: {
    wechat: {},
  },
  presentation: {
    displayName: "WeChat",
    description: "Use nanobot from WeChat conversations.",
    requirements: "WeChat channel setup and gateway",
    initials: "WX",
    color: "#07C160",
    logoUrl: "https://weixin.qq.com/favicon.ico",
    setup: {
      mode: "connect",
      primaryActionLabel: "Connect WeChat",
      command: "nanobot channels login weixin",
      docsUrl: chatAppGuideUrl("wechat"),
      docsLabel: "Open WeChat setup",
      tryIt: "After the QR login finishes, send a WeChat DM to the connected account.",
      summary: "WeChat signs in with a QR code and saves the account state locally.",
      steps: [
        "Click Connect and scan the QR code with WeChat.",
        "Keep the local gateway running while WeChat receives messages.",
        "Send a direct test message to confirm the account is connected.",
      ],
      manualFields: [
        {
          key: "channels.weixin.allowFrom",
          label: "Allowed users",
          placeholder: "User IDs, comma separated",
        },
        {
          key: "channels.weixin.token",
          label: "Token",
          placeholder: "Saved by QR login",
        },
      ],
    },
  },
} satisfies ChannelUiContribution;
