{
  pkgs,
  ...
}:
{
  programs.claude-code = {
    enable = true;
    settings = {
      alwaysThinkingEnabled = true;
      hooks = {
        Notification = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "${pkgs.terminal-notifier}/bin/terminal-notifier -title 'Claude Code' -message 'Needs your attention' -sound default";
              }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "${pkgs.terminal-notifier}/bin/terminal-notifier -title 'Claude Code' -message 'Ready for input' -sound default";
              }
            ];
          }
        ];
      };
    };
  };
}
