{ ... }:
{
  imports = [ ./module.nix ];

  config.settings.os = {
    edit = "echo {{filename}} > /tmp/lazygit-path; kill -TERM $(pidof lazygit)";
    editAtLine = "echo {{filename}}:{{line}} > /tmp/lazygit-path; kill -TERM $(pidof lazygit)";
  };
}
