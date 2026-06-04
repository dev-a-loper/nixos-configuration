{ ... }:
{
  plugins.codecompanion.enable = true;
  plugins.codecompanion.settings.adapters = {
    acp = {
      claude = {
        __raw = ''
          function()
            return require("codecompanion.adapters").extend("claude_code", {})
          end,
        '';
      };
    };
    http.zai = {
      __raw = ''
        function()
             return require("codecompanion.adapters").extend("openai_compatible", {
               env = {
                 url = "https://api.z.ai",
                 api_key = "ANTHROPIC_AUTH_TOKEN",
                 chat_url = "/api/coding/paas/v4",
               },
             })
         end   
      '';
    };
  };
  plugins.codecompanion.settings.interactions = {
    chat = {
      adapter = "claude";
    };
    inline = {
      adapter = {
        name = "zai";
        model = "glm-5.1";
      };
    };
  };
  # keymaps = [
  #   {
  #     key = "]g";
  #     action = "<cmd>Gitsigns prev_hunk<cr>";
  #     mode = "n";
  #   }
  #   {
  #     key = "[g";
  #     action = "<cmd>Gitsigns next_hunk<cr>";
  #     mode = "n";
  #   }
  #   {
  #     key = "<leader>gd";
  #     action = "<cmd>Gitsigns diffthis<cr>";
  #     mode = "n";
  #   }
  # ];
}
