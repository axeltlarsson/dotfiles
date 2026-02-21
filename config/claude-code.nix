{
  pkgs,
  ...
}:
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code-bin;
    settings = {
      permissions = {
        allow = [
          "Bash(gh pr view*)"
          "Bash(gh pr list*)"
          "Bash(gh pr diff*)"
          "Bash(gh pr checks*)"
          "Bash(gh issue view*)"
          "Bash(gh issue list*)"
          "Bash(gh api*)"
          "Bash(gh repo view*)"
          "WebSearch"
          "WebFetch"
        ];
      };
      alwaysThinkingEnabled = true;
      verbose = true;
      hooks = {
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "tmux display-message '🤖 Claude is ready (#{session_name})'";
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
                command = "echo -n '\a'; tmux display-message '🔐 Claude needs permission (#{session_name})'";
              }
            ];
          }
        ];
      };
    };
    memory.text = /* markdown */ ''
      - When writing python code - always make sure to format it by ruff's rules and type check it with ty
      - Use rg instead of grep
      - Use fd instead of find
      - Before committing make sure to run `ci` if configured in the repo (it usually is), if `ci` doesn't work - try `nix develop -c ci`
      - For tools that are missing - you can run `nix run nixpkgs#<tool-name>`
      - Never read .env files!
      - Do not use git commit prefixes like fix:, chore:, feat: etc - just use an emoji then an imperative description, e.g. "🐛 Use correct ICD-10-SE format..."
      - Hotfix commit means to use 🚑 emoji in commit message
    '';
  };
}
