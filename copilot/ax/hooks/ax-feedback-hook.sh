#!/bin/sh

FALLBACK_PROMPT="How was working with AX in this session? If you were giving feedback to the team behind the AX CLI and MCP, what would it be? Draft that feedback, show it to the user, and ask whether they want to send it to the AX team. Only send it with feedback_send if they say yes. Don't include secrets or proprietary code."

FALLBACK_PROMPT_CLI="How was working with AX in this session? If you were giving feedback to the team behind the AX CLI and MCP, what would it be? Draft that feedback, show it to the user, and ask whether they want to send it to the AX team. Only send it if they say yes, by running: ax feedback send - <<'EOF' with the feedback on the following lines and EOF alone on the last line. Don't include secrets or proprietary code."

print_empty() {
  printf '{}\n'
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

json_compact() {
  printf '%s' "$1" | tr '\r\n' '  '
}

json_string_token_any_from_text() {
  key="$1"
  text="$2"
  printf '%s' "$text" | awk -v key="$key" '
    BEGIN {
      q = sprintf("%c", 34)
      bs = sprintf("%c", 92)
      needle = q key q
    }
    {
      source = $0
      pos = index(source, needle)
      while (pos > 0) {
        i = pos + length(needle)
        while (i <= length(source) && substr(source, i, 1) ~ /[[:space:]]/) i++
        if (i > length(source) || substr(source, i, 1) != ":") {
          source = substr(source, pos + length(needle))
          pos = index(source, needle)
          continue
        }
        i++
        while (i <= length(source) && substr(source, i, 1) ~ /[[:space:]]/) i++
        if (i > length(source) || substr(source, i, 1) != q) exit 0

        out = q
        i++
        esc = 0
        for (; i <= length(source); i++) {
          c = substr(source, i, 1)
          out = out c
          if (esc == 1) {
            esc = 0
            continue
          }
          if (c == bs) {
            esc = 1
            continue
          }
          if (c == q) {
            print out
            exit 0
          }
        }
        exit 0
      }
    }
  '
}

json_top_level_token_from_text() {
  key="$1"
  token_kind="$2"
  text="$3"

  printf '%s' "$text" | awk -v wanted="$key" -v wantedKind="$token_kind" '
    BEGIN {
      q = sprintf("%c", 34)
      bs = sprintf("%c", 92)
      mode = "find_object"
      in_string = 0
      capture = 0
      esc = 0
      token = ""
      key_name = ""
      compound_depth = 0
    }
    {
      source = $0
      source_len = length(source)
      i = 1

      while (i <= source_len) {
        c = substr(source, i, 1)

        if (in_string == 1) {
          if (capture == 1) token = token c
          if (esc == 1) {
            esc = 0
            i++
            continue
          }
          if (c == bs) {
            esc = 1
            i++
            continue
          }
          if (c == q) {
            in_string = 0
            if (capture == 1) {
              if (mode == "read_key") {
                key_name = substr(token, 2, length(token) - 2)
                mode = "after_key"
              } else if (mode == "read_value_string") {
                if (key_name == wanted && wantedKind == "string") {
                  print token
                  exit 0
                }
                mode = "after_value"
              }
              token = ""
            }
            capture = 0
          }
          i++
          continue
        }

        if (c ~ /[[:space:]]/) {
          i++
          continue
        }

        if (mode == "skip_compound") {
          if (c == q) {
            in_string = 1
            capture = 0
            esc = 0
            i++
            continue
          }
          if (c == "{" || c == "[") {
            compound_depth++
            i++
            continue
          }
          if (c == "}" || c == "]") {
            compound_depth--
            if (compound_depth <= 0) mode = "after_value"
            i++
            continue
          }
          i++
          continue
        }

        if (mode == "skip_scalar") {
          if (c == ",") {
            mode = "expect_key_or_end"
            i++
            continue
          }
          if (c == "}") exit 0
          i++
          continue
        }

        if (mode == "find_object") {
          if (c == "{") mode = "expect_key_or_end"
          i++
          continue
        }

        if (mode == "expect_key_or_end") {
          if (c == "}") exit 0
          if (c == ",") {
            i++
            continue
          }
          if (c == q) {
            in_string = 1
            capture = 1
            esc = 0
            token = q
            mode = "read_key"
            i++
            continue
          }
          i++
          continue
        }

        if (mode == "after_key") {
          if (c == ":") mode = "expect_value"
          i++
          continue
        }

        if (mode == "expect_value") {
          if (c == q) {
            in_string = 1
            capture = 1
            esc = 0
            token = q
            mode = "read_value_string"
            i++
            continue
          }

          next4 = substr(source, i, 4)
          next5 = substr(source, i, 5)

          if (next4 == "true") {
            tail4 = substr(source, i + 4, 1)
            if (tail4 == "" || tail4 ~ /[[:space:],}\]]/) {
              if (key_name == wanted && wantedKind == "bool") {
                print "true"
                exit 0
              }
              mode = "after_value"
              i += 4
              continue
            }
          }

          if (next5 == "false") {
            tail5 = substr(source, i + 5, 1)
            if (tail5 == "" || tail5 ~ /[[:space:],}\]]/) {
              if (key_name == wanted && wantedKind == "bool") {
                print "false"
                exit 0
              }
              mode = "after_value"
              i += 5
              continue
            }
          }

          if (c == "{" || c == "[") {
            compound_depth = 1
            mode = "skip_compound"
            i++
            continue
          }

          mode = "skip_scalar"
          i++
          continue
        }

        if (mode == "after_value") {
          if (c == ",") {
            mode = "expect_key_or_end"
            i++
            continue
          }
          if (c == "}") exit 0
          i++
          continue
        }

        i++
      }
    }
  '
}

json_string_token_from_text() {
  json_top_level_token_from_text "$1" 'string' "$2"
}

json_bool_from_text() {
  json_top_level_token_from_text "$1" 'bool' "$2"
}

json_string_token() {
  json_string_token_from_text "$1" "$JSON_PAYLOAD"
}

json_string_value() {
  token=$(json_string_token "$1")
  [ -n "$token" ] || return 1
  token=${token#\"}
  token=${token%\"}
  token=$(printf '%s' "$token" | sed 's/\\"/"/g; s/\\\\/\\/g')
  printf '%s' "$token"
}

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { ORS = "" }
    {
      if (NR > 1) printf "\\n"
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\r/, "\\r")
      printf "%s", $0
    }
  '
}

json_quote() {
  printf '"%s"' "$(json_escape "$1")"
}

is_true_string() {
  case "$(to_lower "$1")" in
    true|1|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_valid_session_id() {
  session_id="$1"
  [ -n "$session_id" ] || return 1

  case "$session_id" in
    '.'|'..')
      return 1
      ;;
  esac

  case "$session_id" in
    *[!A-Za-z0-9._:-]*)
      return 1
      ;;
  esac

  case "$session_id" in
    *[!.]*)
      ;;
    *)
      return 1
      ;;
  esac

  [ ${#session_id} -le 128 ]
}

event_client_and_mode() {
  case "${AX_HOOK_EVENT:-}" in
    postToolUse)
      EVENT_CLIENT='copilot'
      EVENT_MODE='mark'
      return 0
      ;;
    afterMCPExecution|afterShellExecution)
      EVENT_CLIENT='cursor'
      EVENT_MODE='mark'
      return 0
      ;;
    agentStop)
      EVENT_CLIENT='copilot'
      EVENT_MODE='stop'
      return 0
      ;;
    stop)
      EVENT_CLIENT='cursor'
      EVENT_MODE='stop'
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

session_id_for_client() {
  client="$1"
  session_id=''
  case "$client" in
    copilot)
      session_id=$(json_string_value 'sessionId' 2>/dev/null || true)
      ;;
    cursor)
      session_id=$(json_string_value 'conversation_id' 2>/dev/null || true)
      ;;
  esac
  [ -n "$session_id" ] || session_id=$(json_string_value 'session_id' 2>/dev/null || true)
  [ -n "$session_id" ] || session_id=$(json_string_value 'thread_id' 2>/dev/null || true)
  printf '%s' "$session_id"
}

is_ax_tool_payload() {
  client="$1"

  if [ "$client" = 'cursor' ]; then
    # Cursor afterMCPExecution payload includes top-level mcp_server_name.
    # Source: https://cursor.com/docs/agent/hooks
    server=$(json_string_value 'mcp_server_name' 2>/dev/null || true)
    if [ -z "$server" ]; then
      return 1
    fi
    case "$(to_lower "$server")" in
      ax|plugin-ax-ax) return 0 ;;
      *) return 1 ;;
    esac
  fi

  tool=''
  case "$client" in
    copilot)
      tool=$(json_string_value 'toolName' 2>/dev/null || true)
      [ -n "$tool" ] || tool=$(json_string_value 'tool_name' 2>/dev/null || true)
      ;;
    cursor)
      tool=$(json_string_value 'tool_name' 2>/dev/null || true)
      ;;
  esac

  # Copilot MCP tool names are host-specific:
  # - VS Code 1.139.1 forms the mcp_<server>_ prefix from
  #   serverInfo.title || serverInfo.name (preferredName), lowercased/sanitized
  #   by McpPrefixGenerator.take:
  #   src/vs/workbench/contrib/mcp/common/mcpServer.ts:233-252, 634-639
  # - Copilot hook payload field assignment:
  #   ChatHookService.executePostToolUseHook sets tool_name from toolName at
  #   extensions/copilot/src/extension/chat/vscode-node/chatHookService.ts:491-497
  # - Copilot CLI runtime package @github/copilot@1.0.89 is a thin loader
  #   (package/npm-loader.js:7 function a()) that dispatches to a platform binary;
  #   package/package.json:4,26-27 pins the version and source build commit.
  if is_ax_vscode_tool "$tool"; then
    return 0
  fi
  is_ax_cli_tool "$tool"
  return $?
}

is_ax_vscode_tool() {
  case "$1" in
    mcp_fiveonefour_*)
      rest=${1#mcp_fiveonefour_}
      ;;
    mcp_ax_*)
      rest=${1#mcp_ax_}
      ;;
    *)
      return 1
      ;;
  esac
  case "$rest" in ""|*[!a-z0-9_]*) return 1 ;; esac
  return 0
}

is_ax_cli_tool() {
  case "$1" in ax-*) ;; *) return 1 ;; esac
  rest=${1#ax-}
  case "$rest" in ""|*[!a-z0-9_]*) return 1 ;; esac
  return 0
}

# Decodes one JSON string token (quotes included) into plain text. Handles the
# escapes a client writes for a shell command: \" \\ \/ \n \r \t \b \f. Other
# escapes (for example \uXXXX) are kept as written.
json_decode_token() {
  printf '%s' "$1" | awk '
    BEGIN { q = sprintf("%c", 34); bs = sprintf("%c", 92); ORS = "" }
    {
      if (NR > 1) printf "\n"
      line = $0
      n = length(line)
      out = ""
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (c == bs && i < n) {
          i++
          d = substr(line, i, 1)
          if (d == "n") out = out "\n"
          else if (d == "r") out = out "\r"
          else if (d == "t") out = out "\t"
          else if (d == "b" || d == "f") out = out " "
          else if (d == q || d == bs || d == "/") out = out d
          else out = out bs d
          continue
        }
        out = out c
      }
      printf "%s", out
    }
  ' | sed 's/^"//; s/"$//'
}

# Prints "<subcommand> <second word>" for every `ax` invocation in a shell
# command line. `ax` counts only as the program being run: the first word of a
# command, after separators (; & | ( ) { } newline), env assignments (FOO=1),
# and wrappers such as env/exec/command/time/nohup or a leading if/then/do/!.
# Words inside quotes never start a command, so `echo ax`, `grep -r "; ax"`,
# `max`, `tax` and `ax-tool` do not match; `ax`, `./ax` and `/path/to/ax` do.
# Text that is not a command is skipped: an unquoted `#` at the start of a word
# comments out the rest of its line (`echo x # ; ax run`), and the body of a
# heredoc (`cat <<EOF` ... `EOF`, also `<<-` and quoted delimiters) is data, so
# `ax run` inside it does not match. Commands on the heredoc operator's own
# line still count (`cat <<EOF | ax run`). A here-string (`<<<`) is a word, and so is a
# `<<` shift inside `$(( ... ))` arithmetic. A comment inside backticks ends at
# the closing backtick.
# Not modelled: `$(ax run)` inside an unquoted heredoc body actually runs but is
# not detected (a missed mark only means one fewer prompt), and a `#` inside
# `case` patterns or other exotic syntax is treated as a comment.
ax_invocations_from_command() {
  printf '%s' "$1" | awk '
    function endword() {
      if (!have) return
      handle(word)
      word = ""
      have = 0
    }
    function endseg() {
      endword()
      if (collecting) print sub1 " " sub2
      collecting = 0
      pending = 1
    }
    function skip_bodies(pos,    h, ls, le, line) {
      for (h = 1; h <= nhd; h++) {
        while (1) {
          ls = pos + 1
          if (ls > n) {
            nhd = 0
            return n
          }
          le = index(substr(text, ls), "\n")
          if (le == 0) {
            line = substr(text, ls)
            pos = n
          } else {
            line = substr(text, ls, le - 1)
            pos = ls + le - 1
          }
          if (hdash[h]) sub(/^\t+/, "", line)
          if (line == hdelim[h]) break
        }
      }
      nhd = 0
      return pos
    }
    function handle(w,    base) {
      if (collecting) {
        if (ncollected == 0) sub1 = w
        else if (ncollected == 1) sub2 = w
        ncollected++
        return
      }
      if (!pending) return
      if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) return
      if (w in wrappers) return
      if (w ~ /^-/) return
      base = w
      sub(/^.*\//, "", base)
      pending = 0
      if (base == "ax") {
        collecting = 1
        ncollected = 0
        sub1 = ""
        sub2 = ""
      }
    }
    BEGIN {
      sq = sprintf("%c", 39)
      dq = sprintf("%c", 34)
      bs = sprintf("%c", 92)
      bt = sprintf("%c", 96)
      split("env exec command time nohup if then elif else do while until !", kw, " ")
      for (k in kw) wrappers[kw[k]] = 1
      pending = 1
      collecting = 0
      have = 0
      word = ""
      q = ""
      text = ""
      nhd = 0
      arith = 0
      btopen = 0
    }
    { text = text $0 "\n" }
    END {
      n = length(text)
      for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        if (q == sq) {
          if (c == sq) q = ""
          else word = word c
          continue
        }
        if (q == dq) {
          if (c == bs) {
            word = word substr(text, i + 1, 1)
            i++
          } else if (c == dq) q = ""
          else word = word c
          continue
        }
        if (c == bs) {
          nxt = substr(text, i + 1, 1)
          i++
          if (nxt != "\n") {
            word = word nxt
            have = 1
          }
          continue
        }
        if (c == sq) { q = sq; have = 1; continue }
        if (c == dq) { q = dq; have = 1; continue }
        if (arith > 0) {
          if (c == "(") arith++
          else if (c == ")") arith--
          word = word c
          have = 1
          continue
        }
        if (c == "$" && substr(text, i + 1, 2) == "((") {
          word = word "$(("
          have = 1
          arith = 2
          i += 2
          continue
        }
        if (c == "#" && !have) {
          while (i < n && substr(text, i + 1, 1) != "\n" && !(btopen && substr(text, i + 1, 1) == bt)) i++
          continue
        }
        if (c == "$" && substr(text, i + 1, 1) == "{") {
          word = word "${"
          have = 1
          i++
          continue
        }
        if (c == "<" && substr(text, i + 1, 1) == "<") {
          endword()
          if (substr(text, i + 2, 1) == "<") {
            i += 2
            continue
          }
          j = i + 2
          dash = 0
          if (substr(text, j, 1) == "-") { dash = 1; j++ }
          while (substr(text, j, 1) == " " || substr(text, j, 1) == "\t") j++
          delim = ""
          dq2 = ""
          while (j <= n) {
            d = substr(text, j, 1)
            if (dq2 == "") {
              if (d == " " || d == "\t" || d == "\n" || d == ";" || d == "&" || d == "|" || d == "(" || d == ")" || d == "<" || d == ">") break
              if (d == sq || d == dq) { dq2 = d; j++; continue }
              if (d == bs) j++
              delim = delim substr(text, j, 1)
              j++
            } else {
              if (d == dq2) dq2 = ""
              else delim = delim d
              j++
            }
          }
          nhd++
          hdelim[nhd] = delim
          hdash[nhd] = dash
          i = j - 1
          continue
        }
        if (c == "\n") {
          endseg()
          if (nhd > 0) i = skip_bodies(i)
          continue
        }
        if (c == " " || c == "\t" || c == "\r") { endword(); continue }
        if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "{" || c == "}" || c == bt) {
          if (c == bt) btopen = !btopen
          endseg()
          continue
        }
        word = word c
        have = 1
      }
      endseg()
    }
  '
}

# True when the shell command line runs the AX CLI for product use. Commands
# that only sign in, update, ask for help or version, look at the account, or
# send the feedback itself do not count, matching what the server records.
command_runs_ax() {
  invocations=$(ax_invocations_from_command "$1")
  [ -n "$invocations" ] || return 1
  printf '%s\n' "$invocations" | while IFS=' ' read -r sub1 sub2; do
    case "$sub1" in
      ''|auth|update|feedback|whoami|status|help|--help|-h|--version|-V)
        continue
        ;;
      org)
        case "$sub2" in
          list|view|switch) continue ;;
        esac
        ;;
    esac
    printf 'yes\n'
    break
  done | grep -q yes
}

# The shell command a Copilot postToolUse payload ran, or nothing when the tool
# was not a shell tool.
# - Copilot CLI (camelCase): toolName "bash", toolArgs unknown; the docs example
#   passes toolArgs as a JSON-encoded string ("{\"command\":\"ls\"}").
#   https://docs.github.com/en/copilot/reference/hooks-configuration
# - VS Code Copilot (snake_case): tool_name "run_in_terminal", tool_input an
#   object with `command` (toolNames.ts:53, chatHookService.ts:491-497).
copilot_shell_command() {
  tool=$(json_string_value 'toolName' 2>/dev/null || true)
  [ -n "$tool" ] || tool=$(json_string_value 'tool_name' 2>/dev/null || true)
  case "$tool" in
    bash|run_in_terminal)
      ;;
    *)
      return 1
      ;;
  esac

  args_token=$(json_string_token 'toolArgs' 2>/dev/null || true)
  if [ -n "$args_token" ]; then
    args_text=$(json_decode_token "$args_token")
    command_token=$(json_string_token_any_from_text 'command' "$(json_compact "$args_text")")
  else
    command_token=$(json_string_token_any_from_text 'command' "$JSON_PAYLOAD")
  fi
  [ -n "$command_token" ] || return 1
  json_decode_token "$command_token"
}

# The shell command a Cursor afterShellExecution payload ran (top-level
# `command`). https://cursor.com/docs/agent/hooks
cursor_shell_command() {
  command_token=$(json_string_token 'command' 2>/dev/null || true)
  [ -n "$command_token" ] || return 1
  json_decode_token "$command_token"
}

is_ax_shell_payload() {
  client="$1"
  case "$client" in
    copilot)
      shell_command=$(copilot_shell_command) || return 1
      ;;
    cursor)
      [ "${AX_HOOK_EVENT:-}" = 'afterShellExecution' ] || return 1
      shell_command=$(cursor_shell_command) || return 1
      ;;
    *)
      return 1
      ;;
  esac
  command_runs_ax "$shell_command"
}

stop_hook_active() {
  bool_value=$(json_bool_from_text 'stop_hook_active' "$JSON_PAYLOAD")
  if [ "$bool_value" = 'true' ]; then
    return 0
  fi
  text_value=$(json_string_value 'stop_hook_active' 2>/dev/null || true)
  is_true_string "$text_value"
}

script_dir() {
  script_path="$0"
  case "$script_path" in
    /*)
      ;;
    */*)
      script_path="$(pwd)/$script_path"
      ;;
    *)
      script_path="$(pwd)/$script_path"
      ;;
  esac
  printf '%s' "${script_path%/*}"
}

default_endpoint_for_client() {
  client="$1"
  mcp_url=''

  this_dir=$(script_dir)
  plugin_root=$(cd "$this_dir/.." >/dev/null 2>&1 && pwd -P)
  mcp_json="$plugin_root/mcp.json"
  if [ -n "$plugin_root" ] && [ -f "$mcp_json" ]; then
    mcp_payload=$(json_compact "$(cat "$mcp_json" 2>/dev/null)")
    mcp_url_token=$(json_string_token_any_from_text 'url' "$mcp_payload")
    if [ -n "$mcp_url_token" ]; then
      mcp_url=${mcp_url_token#\"}
      mcp_url=${mcp_url%\"}
      mcp_url=$(printf '%s' "$mcp_url" | sed 's/\\"/"/g; s/\\\\/\\/g')
    fi
  fi

  if [ -z "$mcp_url" ]; then
    base_url='https://app.514.ax'
  else
    base_url="$mcp_url"
    case "$base_url" in
      */mcp)
        base_url=${base_url%/mcp}
        ;;
      */mcp/)
        base_url=${base_url%/mcp/}
        ;;
    esac
  fi

  printf '%s/api/agent-feedback/prompt?client=%s' "$base_url" "$client"
}

prompt_token_for_client() {
  client="$1"
  channel="$2"
  endpoint="${AX_FEEDBACK_PROMPT_ENDPOINT:-$(default_endpoint_for_client "$client")}"
  fallback_prompt="$FALLBACK_PROMPT"
  if [ "$channel" = 'cli' ]; then
    fallback_prompt="$FALLBACK_PROMPT_CLI"
    case "$endpoint" in
      *\?*) endpoint="${endpoint}&channel=cli" ;;
      *) endpoint="${endpoint}?channel=cli" ;;
    esac
  fi
  newline='
'

  response=$(curl \
    --silent \
    --show-error \
    --connect-timeout 1 \
    --max-time 1.5 \
    --header 'accept: application/json' \
    --write-out "${newline}%{http_code}" \
    "$endpoint" 2>/dev/null || true)

  if [ -z "$response" ]; then
    json_quote "$fallback_prompt"
    return 0
  fi

  status=${response##*$newline}
  body=${response%$newline*}

  case "$status" in
    204)
      return 1
      ;;
    200)
      compact_body=$(json_compact "$body")
      disabled=$(json_bool_from_text 'disabled' "$compact_body")
      if [ "$disabled" = 'true' ]; then
        return 1
      fi
      prompt_token=$(json_string_token_from_text 'prompt' "$compact_body")
      if [ -n "$prompt_token" ]; then
        printf '%s' "$prompt_token"
        return 0
      fi
      json_quote "$fallback_prompt"
      return 0
      ;;
    *)
      json_quote "$fallback_prompt"
      return 0
      ;;
  esac
}

mark_session() {
  marker="$1"
  marker_dir=${marker%/*}
  mkdir -p "$marker_dir" >/dev/null 2>&1 || return 0
  ( : >"$marker" ) 2>/dev/null || true
}

main() {
  if ! event_client_and_mode; then
    print_empty
    return 0
  fi

  JSON_PAYLOAD=$(cat 2>/dev/null || true)
  JSON_PAYLOAD=$(json_compact "$JSON_PAYLOAD")

  session_id=$(session_id_for_client "$EVENT_CLIENT")
  if ! is_valid_session_id "$session_id"; then
    print_empty
    return 0
  fi

  state_dir="${AX_STATE_DIR:-}"
  home_dir="${HOME:-}"

  case "$state_dir" in
    '')
      ;;
    /*)
      ;;
    *)
      state_dir=''
      ;;
  esac

  if [ -z "$state_dir" ]; then
    if [ -z "$home_dir" ]; then
      print_empty
      return 0
    fi
    state_dir="$home_dir/.ax/state"
  fi

  if [ -z "$state_dir" ]; then
    print_empty
    return 0
  fi

  session_marker="$state_dir/sessions/$session_id"
  mcp_marker="$state_dir/mcp/$session_id"
  shell_marker="$state_dir/shell/$session_id"
  asked_marker="$state_dir/asked/$session_id"

  if [ -z "$home_dir" ]; then
    home_dir=$(cd "$state_dir/.." >/dev/null 2>&1 && pwd -P)
  fi

  # "At most once a day" is enforced per agent family. Claude Code and Codex are
  # limited server-side (a 24-hour claim per user); this script serves Copilot
  # and Cursor and limits itself with the local calendar-day marker below. The
  # two do not coordinate, so a person who uses both families can be asked once
  # per family per day. Coordinating needs the hook to read
  # the CLI credential in POSIX sh and call an authenticated endpoint on every
  # stop, and the server records asks only for Claude Code and Codex. Widening
  # the anonymous prompt endpoint to reveal per-user state is not an option.
  daily_marker=''
  if [ -n "$home_dir" ]; then
    daily_marker="$home_dir/.ax/feedback-asked"
  fi

  today=$(date +%F 2>/dev/null || true)

  if [ "$EVENT_MODE" = 'mark' ]; then
    if [ "${AX_HOOK_EVENT:-}" = 'afterShellExecution' ]; then
      # Cursor's shell payload carries the full terminal output, so it is not
      # scanned for MCP fields as well.
      if is_ax_shell_payload "$EVENT_CLIENT"; then
        mark_session "$session_marker"
        mark_session "$shell_marker"
      fi
    elif is_ax_tool_payload "$EVENT_CLIENT"; then
      mark_session "$session_marker"
      mark_session "$mcp_marker"
    elif is_ax_shell_payload "$EVENT_CLIENT"; then
      mark_session "$session_marker"
      mark_session "$shell_marker"
    fi
    print_empty
    return 0
  fi

  if is_true_string "${AX_FEEDBACK_OPT_OUT:-}"; then
    print_empty
    return 0
  fi

  if stop_hook_active; then
    print_empty
    return 0
  fi

  if [ ! -f "$session_marker" ] || [ -e "$asked_marker" ]; then
    print_empty
    return 0
  fi

  if [ -n "$today" ] && [ -n "$daily_marker" ] && [ -f "$daily_marker" ]; then
    asked_today=$(head -n 1 "$daily_marker" 2>/dev/null | tr -d '\r\n')
    if [ "$asked_today" = "$today" ]; then
      print_empty
      return 0
    fi
  fi

  # A session marked only by shell commands never used the AX MCP tools, so its
  # feedback is sent with the CLI. Sessions marked by an older copy of this
  # script have neither marker and keep the MCP wording.
  prompt_channel='mcp'
  if [ -f "$shell_marker" ] && [ ! -f "$mcp_marker" ]; then
    prompt_channel='cli'
  fi

  prompt_token=$(prompt_token_for_client "$EVENT_CLIENT" "$prompt_channel") || {
    print_empty
    return 0
  }

  if [ -z "$prompt_token" ]; then
    print_empty
    return 0
  fi

  mark_session "$asked_marker"
  if [ -n "$today" ] && [ -n "$daily_marker" ]; then
    daily_dir=${daily_marker%/*}
    mkdir -p "$daily_dir" >/dev/null 2>&1 || true
    ( printf '%s\n' "$today" >"$daily_marker" ) 2>/dev/null || true
  fi

  if [ "$EVENT_CLIENT" = 'copilot' ]; then
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"hookEventName":"Stop","decision":"block","reason":%s}}\n' "$prompt_token" "$prompt_token"
  else
    printf '{"followup_message":%s}\n' "$prompt_token"
  fi
  return 0
}

if ! main "$@"; then
  print_empty
fi

exit 0
