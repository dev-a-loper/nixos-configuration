{ ... }:
{
  # Chat template for the local llama-server (Qwen3.8 GGUF), patched so a
  # system/developer message mid-conversation is rendered as a normal
  # <|im_start|>system block instead of raising. Claude Code sends that shape
  # over the Anthropic /v1/messages protocol and the stock template 500s on it.
  # llama-server is run manually (see `locallm` in cli/locallm.nix); it just
  # needs this flag added:
  #   --jinja --chat-template-file /etc/llama-cpp/qwen3.8-claude.jinja
  environment.etc."llama-cpp/qwen3.8-claude.jinja".source = ./qwen3.8-claude.jinja;
}
