import type { LucideIcon } from "lucide-react";

export type ChannelPresentation = {
  displayName: string;
  description: string;
  requirements: string;
  initials: string;
  color: string;
  icon?: LucideIcon;
  logoUrl?: string;
  setup?: ChannelCatalogSetupPresentation;
};

export type ChannelSetupPresentation = {
  mode?: "webui" | "credentials" | "connect";
  primaryActionLabel?: string;
  command?: string;
  docsUrl?: string;
  docsLabel?: string;
  docsLogoUrl?: string;
  officialUrl?: string;
  officialLabel?: string;
  summary?: string;
  tryIt?: string;
  steps: string[];
  fields?: ChannelConfigField[];
  manualFields?: ChannelConfigField[];
  actions?: ChannelSetupAction[];
  presets?: ChannelProviderPreset[];
};

type ChannelCatalogSetupPresentation = Omit<
  ChannelSetupPresentation,
  "officialUrl" | "fields" | "manualFields"
> & {
  fields?: ChannelFieldPresentation[];
  manualFields?: ChannelFieldPresentation[];
};

export type ChannelFieldPresentation = {
  key: string;
  label: string;
  placeholder?: string;
  help?: string;
  choiceLabels?: Record<string, string>;
};

export type ChannelSetupAction = {
  id: string;
  label: string;
  url?: string;
  copyText?: string;
  logoUrl?: string;
};

export type ChannelProviderPreset = {
  id: string;
  label: string;
  values: Record<string, string>;
};

export type ChannelConfigField = {
  key: string;
  label: string;
  placeholder?: string;
  secret?: boolean;
  optional?: boolean;
  help?: string;
  inputType?: "text" | "number";
  defaultValue?: string;
  options?: ChannelConfigOption[];
};

export type ChannelConfigOption = {
  value: string;
  label: string;
};

export const GROUP_BEHAVIOR_LABELS = {
  mention: "Mention only",
  open: "All messages",
  allowlist: "Allowlist",
};

export const BOOLEAN_LABELS = {
  true: "On",
  false: "Off",
};

const NANOBOT_DOCS_URL = "https://nanobot.wiki/docs/latest";
const CHAT_APPS_DOCS_URL = `${NANOBOT_DOCS_URL}/getting-started/chat-apps`;

export function chatAppGuideUrl(sectionId: string): string {
  return `${CHAT_APPS_DOCS_URL}#${sectionId}`;
}

export function docsUrlWithBase(
  url: string | undefined,
  chatAppsDocsUrl?: string,
): string | undefined {
  if (!url || !chatAppsDocsUrl) return url;
  if (!url.startsWith(CHAT_APPS_DOCS_URL)) return url;
  const anchor = url.includes("#") ? `#${url.split("#").pop()}` : "";
  return `${chatAppsDocsUrl.replace(/\/$/, "")}${anchor}`;
}
