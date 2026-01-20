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
                command = "tmux display-message '🤖 Claude ready (#{session_name})'";
              }
            ];
          }
        ];
        Notification = [
          {
            matcher = "permission_prompt";
            hooks = [
              {
                type = "command";
                command = "tmux display-message '🔐 Claude needs permission (#{session_name})'";
              }
            ];
          }
        ];
      };
    };
  };
}
