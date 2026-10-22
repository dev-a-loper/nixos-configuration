# locallm — flip claude-code / opencode onto the local llama.cpp server.
#
# Remote (z.ai) is the default; `locallm` in an interactive shell switches both
# tools to llama-server on localhost:8080 (e.g. run with
# `-hf unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M`), `locallm off` switches back, and
# a fresh shell always starts on the remote defaults.
{
  config,
  ...
}:
let
  llamaUrl = "http://localhost:8080";
  # model id exactly as llama-server reports it in /v1/models
  llamaModel = "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M";
  remoteModel = "glm-5.3";
  remoteSmallModel = "glm-5.3-flash[1m]";
  secrets = config.userConfiguration.secrets;
in
{
  # Remote defaults, inherited by every shell and thus by claude/opencode.
  # These must NOT reappear in claude-code's settings.env: settings.json env
  # clobbers inherited shell vars, which would defeat `locallm`.
  environment.variables = {
    ANTHROPIC_AUTH_TOKEN = secrets.ANTHROPIC_AUTH_TOKEN;
    ANTHROPIC_BASE_URL = secrets.ANTHROPIC_BASE_URL;
    ANTHROPIC_DEFAULT_HAIKU_MODEL = remoteSmallModel;
    ANTHROPIC_DEFAULT_SONNET_MODEL = remoteModel;
    ANTHROPIC_DEFAULT_OPUS_MODEL = remoteModel;
    # consumed by opencode.json's {env:...} substitution
    OPENCODE_MODEL = "zai-anthropic/${remoteModel}";
  };

  # shell function (not a script): a child process cannot export into the
  # caller's environment, and both CLIs read env at launch
  programs.zsh.interactiveShellInit = ''
    locallm() {
      if [ "$1" = "off" ]; then
        if [ -n "''${_LOCALLM_BASE_URL+x}" ]; then
          export ANTHROPIC_BASE_URL="$_LOCALLM_BASE_URL"
          export ANTHROPIC_AUTH_TOKEN="$_LOCALLM_TOKEN"
          export ANTHROPIC_DEFAULT_HAIKU_MODEL="$_LOCALLM_HAIKU"
          export ANTHROPIC_DEFAULT_SONNET_MODEL="$_LOCALLM_SONNET"
          export ANTHROPIC_DEFAULT_OPUS_MODEL="$_LOCALLM_OPUS"
          export OPENCODE_MODEL="$_LOCALLM_OPENCODE"
          unset _LOCALLM_BASE_URL _LOCALLM_TOKEN _LOCALLM_HAIKU _LOCALLM_SONNET _LOCALLM_OPUS _LOCALLM_OPENCODE
          echo "locallm: back to remote"
        else
          echo "locallm: nothing to restore (new shells start remote anyway)"
        fi
        return
      fi
      _LOCALLM_BASE_URL="$ANTHROPIC_BASE_URL"
      _LOCALLM_TOKEN="$ANTHROPIC_AUTH_TOKEN"
      _LOCALLM_HAIKU="$ANTHROPIC_DEFAULT_HAIKU_MODEL"
      _LOCALLM_SONNET="$ANTHROPIC_DEFAULT_SONNET_MODEL"
      _LOCALLM_OPUS="$ANTHROPIC_DEFAULT_OPUS_MODEL"
      _LOCALLM_OPENCODE="$OPENCODE_MODEL"
      export ANTHROPIC_BASE_URL="${llamaUrl}"
      export ANTHROPIC_AUTH_TOKEN="local"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${llamaModel}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${llamaModel}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${llamaModel}"
      export OPENCODE_MODEL="llamacpp/${llamaModel}"
      echo "locallm: claude + opencode -> ${llamaUrl} (${llamaModel}); 'locallm off' or a new shell to reset"
    }
  '';
}
