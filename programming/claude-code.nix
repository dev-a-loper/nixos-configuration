{
  config,
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
    package = unstable.claude-code;
    settings = {
      env = {
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-5.1";
        ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.1";
        ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.1";
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = "200000";
        # https_proxy = "http://localhost:1080";
        ANTHROPIC_AUTH_TOKEN = secrets.ANTHROPIC_AUTH_TOKEN;
        ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic";
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
