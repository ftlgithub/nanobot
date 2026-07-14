import {
  CliAppMentionText,
  INLINE_TOKEN_HIGHLIGHT_COLOR,
  InlineTokenHighlight,
} from "@/components/CliAppMentionText";
import { matchingSlashCommand } from "@/lib/slash-command";
import type { CliAppInfo, McpPresetInfo, SlashCommand } from "@/lib/types";

interface SlashCommandTextProps {
  text: string;
  slashCommands: SlashCommand[];
  cliApps: CliAppInfo[];
  mcpPresets: McpPresetInfo[];
}

export function SlashCommandText({
  text,
  slashCommands,
  cliApps,
  mcpPresets,
}: SlashCommandTextProps) {
  const command = matchingSlashCommand(text, slashCommands);
  if (!command) {
    return <CliAppMentionText text={text} cliApps={cliApps} mcpPresets={mcpPresets} />;
  }

  return (
    <>
      <InlineTokenHighlight
        testId="message-slash-command"
        color={INLINE_TOKEN_HIGHLIGHT_COLOR}
        className="font-medium"
      >
        {command.command}
      </InlineTokenHighlight>
      <CliAppMentionText
        text={text.slice(command.command.length)}
        cliApps={cliApps}
        mcpPresets={mcpPresets}
      />
    </>
  );
}
