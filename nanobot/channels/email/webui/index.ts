import type { ChannelUiContribution } from "@/channel-plugins/types";
import {
  BOOLEAN_LABELS,
  type ChannelProviderPreset,
  chatAppGuideUrl,
} from "@/components/settings/channels/catalog";

const CONSENT_LABELS = {
  true: "Granted",
  false: "Not granted",
};

const EMAIL_PROVIDER_PRESETS: ChannelProviderPreset[] = [
  {
    id: "gmail",
    label: "Gmail",
    values: {
      "channels.email.imapHost": "imap.gmail.com",
      "channels.email.imapPort": "993",
      "channels.email.smtpHost": "smtp.gmail.com",
      "channels.email.smtpPort": "587",
    },
  },
  {
    id: "outlook",
    label: "Outlook",
    values: {
      "channels.email.imapHost": "outlook.office365.com",
      "channels.email.imapPort": "993",
      "channels.email.smtpHost": "smtp.office365.com",
      "channels.email.smtpPort": "587",
    },
  },
  {
    id: "icloud",
    label: "iCloud",
    values: {
      "channels.email.imapHost": "imap.mail.me.com",
      "channels.email.imapPort": "993",
      "channels.email.smtpHost": "smtp.mail.me.com",
      "channels.email.smtpPort": "587",
    },
  },
  { id: "custom", label: "Custom", values: {} },
];

export default {
  presentation: {
    displayName: "Email",
    description: "Let nanobot receive and answer email messages.",
    requirements: "IMAP inbox, SMTP sender, app password, explicit consent",
    initials: "EM",
    color: "#64748B",
    logoUrl: "https://gmail.com/favicon.ico",
    setup: {
      mode: "credentials",
      docsUrl: chatAppGuideUrl("email"),
      docsLabel: "Open Email setup",
      officialLabel: "Open app password guide",
      tryIt: "Send a test email to the connected mailbox.",
      presets: EMAIL_PROVIDER_PRESETS,
      summary:
        "Email is IMAP polling plus SMTP replies. Use a dedicated mailbox when possible, and grant explicit consent before nanobot reads mail.",
      steps: [
        "Create or choose the mailbox nanobot will own, enable IMAP, and create an app password when the provider requires one.",
        "Fill IMAP settings for receiving unread mail, then SMTP settings for sending replies.",
        "Set consentGranted to true only after confirming this mailbox may be processed by nanobot.",
        "Save and enable Email, then send a test message to the mailbox.",
      ],
      fields: [
        {
          key: "channels.email.consentGranted",
          label: "Consent granted",
          choiceLabels: CONSENT_LABELS,
          help: "Required safety switch. Leave false until this bot mailbox is intentionally connected.",
        },
        { key: "channels.email.imapHost", label: "IMAP host", placeholder: "imap.gmail.com" },
        { key: "channels.email.imapUsername", label: "IMAP username", placeholder: "bot@example.com" },
        {
          key: "channels.email.imapPassword",
          label: "IMAP password",
          placeholder: "App password",
          help: "Use an app password when your mail provider requires one.",
        },
        { key: "channels.email.smtpHost", label: "SMTP host", placeholder: "smtp.gmail.com" },
        { key: "channels.email.smtpUsername", label: "SMTP username", placeholder: "bot@example.com" },
        {
          key: "channels.email.smtpPassword",
          label: "SMTP password",
          placeholder: "App password",
          help: "Usually the same app password used for IMAP.",
        },
        { key: "channels.email.imapPort", label: "IMAP port", placeholder: "993" },
        { key: "channels.email.smtpPort", label: "SMTP port", placeholder: "587" },
        { key: "channels.email.fromAddress", label: "From address", placeholder: "bot@example.com" },
        { key: "channels.email.pollIntervalSeconds", label: "Poll interval", placeholder: "30" },
        {
          key: "channels.email.allowFrom",
          label: "Allowed senders",
          placeholder: "Email addresses, comma separated",
          help: "Leave empty to require pairing before a sender can use email.",
        },
        { key: "channels.email.verifyDkim", label: "Verify DKIM", choiceLabels: BOOLEAN_LABELS },
        { key: "channels.email.verifySpf", label: "Verify SPF", choiceLabels: BOOLEAN_LABELS },
      ],
    },
  },
} satisfies ChannelUiContribution;
