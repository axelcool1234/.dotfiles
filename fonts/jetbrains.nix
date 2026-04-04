{
  ui = {
    family = "JetBrains Mono";
    size = 11;
    packageAttrPath = [ "jetbrains-mono" ];
  };

  monospace = {
    family = "JetBrainsMono Nerd Font Mono";
    size = 10;
    packageAttrPath = [ "nerd-fonts" "jetbrains-mono" ];
  };

  terminal = {
    family = "JetBrainsMono Nerd Font Mono";
    size = 10;
    packageAttrPath = [ "nerd-fonts" "jetbrains-mono" ];
    postscriptName = "JetBrainsMonoNFM-Regular";
  };

  emoji = {
    family = "Noto Color Emoji";
    packageAttrPath = [ "noto-fonts-color-emoji" ];
  };

  symbols = {
    family = "Symbols Nerd Font Mono";
    packageAttrPath = [ "nerd-fonts" "symbols-only" ];
  };
}
