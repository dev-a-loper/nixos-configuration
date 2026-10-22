{
  config,
  llm-agents,
  ...
}:
let
  userName = config.userConfiguration.name;
  secrets = config.userConfiguration.secrets;
in
{
  home-manager.users.${userName}.programs.opencode = {
    enable = true;
    package = llm-agents.opencode;
    settings = {
      # nix-managed binary — no self-updates
      autoupdate = false;
      # env-switchable default (cli/locallm.nix exports OPENCODE_MODEL):
      # zai-anthropic/glm-5.3 by default, llamacpp/<model> under `locallm`
      model = "{env:OPENCODE_MODEL}";
      small_model = "zai-anthropic/glm-5.3-flash";
      provider = {
        # distinct id: `zai` is the built-in models.dev provider (openai
        # endpoint); this one hits the anthropic-compatible endpoint
        "zai-anthropic" = {
          npm = "@ai-sdk/anthropic";
          name = "Z.AI (Anthropic endpoint)";
          options = {
            baseURL = "https://api.z.ai/api/anthropic";
            apiKey = secrets.ANTHROPIC_AUTH_TOKEN;
          };
          models = {
            "glm-5.3".name = "GLM-5.3";
            "glm-5.3-flash".name = "GLM-5.3 Flash";
          };
        };
        # local llama.cpp server (llama-server, OpenAI-compatible API);
        # model id must match what /v1/models reports there
        llamacpp = {
          npm = "@ai-sdk/openai-compatible";
          name = "llama.cpp (local)";
          options = {
            baseURL = "http://localhost:8080/v1";
            apiKey = "local";
          };
          models = {
            "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M".name = "Qwen3.8 27B (local)";
          };
        };
      };
      mcp = {
        "web-search-prime" = {
          type = "remote";
          url = "https://api.z.ai/api/mcp/web_search_prime/mcp";
          headers.Authorization = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
        };
        "zai-mcp-server" = {
          type = "local";
          command = [
            "npx"
            "-y"
            "@z_ai/mcp-server"
          ];
          environment = {
            Z_AI_API_KEY = "${secrets.ANTHROPIC_AUTH_TOKEN}";
            Z_AI_MODE = "ZAI";
          };
        };
        "web-reader" = {
          type = "remote";
          url = "https://api.z.ai/api/mcp/web_reader/mcp";
          headers.Authorization = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
        };
        "zread" = {
          type = "remote";
          url = "https://api.z.ai/api/mcp/zread/mcp";
          headers.Authorization = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
        };
      };
    };
  };
}
