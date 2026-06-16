{ pkgs, ... }:
{
  plugins.telescope = {
    enable = true;
    keymaps = {
      "<leader>fr" = {
        action = "registers";
      };
      "<leader>fw" = {
        action = "live_grep hidden=true";
      };
      "<leader>ff" = {
        action = "find_files hidden=true";
      };
      "<leader>f<CR>" = {
        action = "resume";
      };
      "<leader>fp" = {
        action = "project";
      };
      "<leader>fs" = {
        action = "lsp_dynamic_workspace_symbols";
      };
    };

    extensions.project.enable = true;
    settings.defaults.sorting_strategy = "ascending";
    settings.defaults.layout_config = {
      horizontal = {
        prompt_position = "top";
        preview_width = 0.55;
      };
      vertical = {
        mirror = false;
      };
      width = 0.87;
      height = 0.8;
      preview_cutoff = 120;
    };
  };
}
