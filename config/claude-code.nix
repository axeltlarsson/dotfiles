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
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "tmux display-message '🤖 Claude ready'";
              }
            ];
          }
        ];
      };
    };
  };
}
