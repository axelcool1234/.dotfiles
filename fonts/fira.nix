{
  ui = {
    family = "Fira Sans";
    size = 11;
    packageAttrPath = [ "fira" ];
  };

  monospace = {
    family = "FiraCode Nerd Font Mono";
    size = 10;
    packageAttrPath = [ "nerd-fonts" "fira-code" ];
  };

  terminal = {
    family = "FiraCode Nerd Font Mono";
    size = 10;
    packageAttrPath = [ "nerd-fonts" "fira-code" ];
    postscriptName = "FiraCodeNFM-Reg";
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
