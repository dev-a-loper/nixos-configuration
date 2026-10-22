{
  config,
  llm-agents,
  unstable,
  ...
}:
let
  userName = config.userConfiguration.name;
  secrets = config.userConfiguration.secrets;
in
{
  home-manager.users.${userName}.programs.claude-code = {
    enable = true;
    package = llm-agents.claude-code;
    settings = {
      env = {
        AGENT_BROWSER_HEADED = "true";
        AGENT_BROWSER_IGNORE_HTTPS_ERRORS = "true";
        # https_proxy = "http://localhost:1080";
        # ANTHROPIC_* lives in ../cli/locallm.nix (system env). settings.env
        # would clobber the shell, breaking `locallm`.
      };
      hooks = {
        Notification = [
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = "notify-send 'Claude Code' 'Awaiting your input'";
              }
            ];
          }
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = ''curl -s -X POST "https://api.telegram.org/bot${secrets.NOTIFIER_BOT_TOKEN}/sendMessage"  -d chat_id=${secrets.CHAT_ID}  -d text="claude is awaiting your input"'';
              }
            ];
          }
        ];
      };
      alwaysThinkingEnabled = true;
    };
    mcpServers = {
      "web-search-prime" = {
        "type" = "http";
        "url" = "https://api.z.ai/api/mcp/web_search_prime/mcp";
        "headers" = {
          "Authorization" = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
        };
      };
      "zai-mcp-server" = {
        "type" = "stdio";
        "command" = "npx";
        "args" = [
          "-y"
          "@z_ai/mcp-server"
        ];
        "env" = {
          "Z_AI_API_KEY" = "${secrets.ANTHROPIC_AUTH_TOKEN}";
          "Z_AI_MODE" = "ZAI";
        };
      };
      "web-reader" = {
        "type" = "http";
        "url" = "https://api.z.ai/api/mcp/web_reader/mcp";
        "headers" = {
          "Authorization" = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
        };
      };
      "zread" = {
        "type" = "http";
        "url" = "https://api.z.ai/api/mcp/zread/mcp";
        "headers" = {
          "Authorization" = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
        };
      };
    };
  };
}
