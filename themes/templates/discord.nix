{ lib, theme }:
''
    .theme-${theme.discord.mode},
    .visual-refresh.theme-${theme.discord.mode},
    .visual-refresh .theme-${theme.discord.mode} {
      --brand-500: ${theme.hex (theme.selection.accent)} !important;
      --brand-530: ${theme.hex (theme.selection.accent)};
      --brand-560: ${theme.hex (theme.selection.accent)};
      --blurple-50: ${theme.hex (theme.selection.accent)};
      --text-default: ${theme.hex "text"};
      --text-muted: ${theme.hex "subtext0"} !important;
      --text-link: ${theme.hex (theme.selection.accent)} !important;
      --text-brand: ${theme.hex (theme.selection.accent)};
      --text-strong: ${theme.hex "text"} !important;
      --text-subtle: ${theme.hex "subtext1"};
      --text-feedback-positive: ${theme.hex "green"};
      --text-feedback-critical: ${theme.hex "red"};
      --text-feedback-warning: ${theme.hex "yellow"};
      --text-feedback-info: ${theme.hex "sky"};
      --app-frame-background: ${theme.hex "crust"};
      --background-primary: ${theme.hex "base"};
      --background-secondary: ${theme.hex "mantle"};
      --background-secondary-alt: ${theme.hex "mantle"} !important;
      --background-tertiary: ${theme.hex "crust"};
      --background-accent: ${theme.hex "surface1"} !important;
      --background-floating: ${theme.hex "mantle"};
      --background-modifier-hover: ${theme.rgba "surface2" 0.15};
      --background-modifier-active: ${theme.rgba "surface2" 0.25};
      --background-modifier-selected: ${theme.rgba "surface2" 0.45};
      --background-mentioned: ${theme.rgba "yellow" 0.1};
      --background-mentioned-hover: ${theme.rgba "yellow" 0.08};
      --background-message-hover: ${theme.rgba "crust" 0.3};
      --background-message-highlight: ${theme.rgba theme.selection.accent 0.3};
      --background-base-lowest: ${theme.hex "crust"} !important;
      --background-base-lower: ${theme.hex "mantle"} !important;
      --background-base-low: ${theme.hex "surface0"} !important;
      --background-surface-high: ${theme.hex "base"} !important;
      --background-surface-higher: ${theme.hex "surface0"} !important;
      --background-surface-highest: ${theme.hex "surface1"} !important;
      --background-code: ${theme.hex "base"};
      --chat-background: ${theme.hex "base"};
      --chat-background-default: ${theme.hex "base"};
      --chat-border: ${theme.hex "crust"};
      --channeltextarea-background: ${theme.hex "mantle"};
      --input-background: ${theme.hex "crust"};
      --input-placeholder-text-default: ${theme.hex "subtext1"};
      --input-border-default: ${theme.hex "overlay0"};
      --modal-background: ${theme.hex "base"} !important;
      --modal-footer-background: ${theme.hex "mantle"};
      --scrollbar-thin-thumb: ${theme.hex (theme.selection.accent)};
      --scrollbar-auto-thumb: ${theme.hex (theme.selection.accent)};
      --scrollbar-auto-track: ${theme.hex "crust"};
      --scrollbar-auto-scrollbar-color-thumb: ${theme.hex (theme.selection.accent)};
      --scrollbar-auto-scrollbar-color-track: ${theme.hex "crust"};
      --button-secondary-background: ${theme.hex "surface1"};
      --button-secondary-background-hover: ${theme.hex "surface2"};
      --button-secondary-background-active: ${theme.hex "surface0"};
      --interactive-normal: ${theme.hex "text"};
      --interactive-hover: ${theme.hex "text"};
      --interactive-active: ${theme.hex "text"};
      --interactive-muted: ${theme.hex "overlay0"};
      --channels-default: ${theme.hex "subtext1"} !important;
      --channel-icon: ${theme.hex "subtext1"} !important;
      --channel-text-area-placeholder: ${theme.hex "subtext0"};
      --header-primary: ${theme.hex "text"};
      --header-secondary: ${theme.hex "subtext1"};
      --logo-primary: ${theme.hex "text"};
      --mention-foreground: ${theme.hex (theme.selection.accent)};
      --message-reacted-background-default: ${theme.rgba (theme.selection.accent) 0.3} !important;
      --message-reacted-text-default: ${theme.hex (theme.selection.accent)};
      --background-feedback-positive: ${theme.rgba "green" 0.15};
      --background-feedback-warning: ${theme.rgba "yellow" 0.15};
      --background-feedback-critical: ${theme.rgba "red" 0.15};
      --background-feedback-info: ${theme.rgba "sky" 0.15};
      --background-feedback-notification: ${theme.hex "red"};
      --status-positive: ${theme.hex "green"};
      --status-warning: ${theme.hex "yellow"};
      --status-danger: ${theme.hex "red"};
      --status-positive-background: ${theme.hex "green"};
      --status-warning-background: ${theme.hex "yellow"};
      --status-danger-background: ${theme.hex "red"};
      --status-positive-text: ${theme.hex "base"};
      --status-warning-text: ${theme.hex "base"};
      --status-danger-text: ${theme.hex "base"};
      --spoiler-hidden-background: ${theme.hex "surface2"};
      --spoiler-revealed-background: ${theme.hex "surface0"};
      --border-subtle: ${theme.hex "base"} !important;
      --border-normal: ${theme.hex "crust"};
      --border-strong: ${theme.hex "mantle"};
      --custom-channel-members-bg: ${theme.hex "mantle"};
      --custom-status-bubble-background: ${theme.hex "crust"} !important;
      --custom-status-bubble-background-color: ${theme.hex "mantle"} !important;
      --card-background-filled: ${theme.hex "surface0"};
      --notice-background-positive: ${theme.hex "green"};
      --notice-background-warning: ${theme.hex "yellow"};
      --notice-background-critical: ${theme.hex "red"};
      --notice-background-info: ${theme.hex "sky"};
      --notice-text-positive: ${theme.hex "base"};
      --notice-text-warning: ${theme.hex "base"};
      --notice-text-critical: ${theme.hex "base"};
      --notice-text-info: ${theme.hex "base"};
    }

    .theme-${theme.discord.mode} ::selection,
    .visual-refresh.theme-${theme.discord.mode} ::selection,
    .visual-refresh .theme-${theme.discord.mode} ::selection {
      background-color: ${theme.rgba (theme.selection.accent) 0.6};
    }

    .theme-${theme.discord.mode} button[class*=colorBrand_],
    .visual-refresh.theme-${theme.discord.mode} button[class*=colorBrand_],
    .visual-refresh .theme-${theme.discord.mode} button[class*=colorBrand_] {
      background-color: ${theme.hex (theme.selection.accent)} !important;
      color: ${theme.hex "base"} !important;
    }

    .theme-${theme.discord.mode} button[class*=colorBrand_]:hover,
    .visual-refresh.theme-${theme.discord.mode} button[class*=colorBrand_]:hover,
    .visual-refresh .theme-${theme.discord.mode} button[class*=colorBrand_]:hover {
      filter: brightness(1.08);
    }

    .theme-${theme.discord.mode} [class*=panels_],
    .theme-${theme.discord.mode} [class*=sidebar_],
    .theme-${theme.discord.mode} [class*=membersWrap_],
    .theme-${theme.discord.mode} [class*=container_][class*=themed_],
    .visual-refresh.theme-${theme.discord.mode} [class*=panels_],
    .visual-refresh.theme-${theme.discord.mode} [class*=sidebar_],
    .visual-refresh.theme-${theme.discord.mode} [class*=membersWrap_],
    .visual-refresh.theme-${theme.discord.mode} [class*=container_][class*=themed_] {
      background: ${theme.hex "mantle"} !important;
    }
  ''
