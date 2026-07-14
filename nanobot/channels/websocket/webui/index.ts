import { Network } from "lucide-react";

import type { ChannelUiContribution } from "@/channel-plugins/types";
import { chatAppGuideUrl } from "@/components/settings/channels/catalog";

export default {
  presentation: {
    displayName: "WebSocket",
    description: "Use nanobot from the local browser workbench.",
    requirements: "Local gateway, WebSocket token",
    initials: "WS",
    color: "#111827",
    icon: Network,
    setup: {
      mode: "webui",
      docsUrl: chatAppGuideUrl("websocket"),
      docsLabel: "Open WebSocket setup",
      tryIt: "Open the WebUI and send a short message.",
      summary: "WebSocket is required by the browser workbench and is prepared by the nanobot webui command.",
      steps: [
        "Start the workbench with nanobot webui so the local gateway and WebSocket channel are enabled together.",
        "Keep this channel enabled while using the WebUI.",
        "Change host, port, or token only from config.json when you need a custom local setup.",
      ],
    },
  },
} satisfies ChannelUiContribution;
