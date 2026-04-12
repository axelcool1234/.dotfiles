{
  ...
}:
{
  imports = [ ./module.nix ];

  config = {
    settings = {
      preview = {
        show_at_start = true;
        position = "right";
        revision_command = [
          "show"
          "-r"
          "$change_id"
          "--summary"
          "--git"
          "--color"
          "always"
        ];
      };

      suggest.exec.mode = "fuzzy";
    };
  };
}
