{ pkgs, ... }:
let
  # Workspace, window and tape-column snapshot, the Hyprland counterpart of
  # kitty-save-tabs (kitty.nix). Split ratios are not saved for dwindle workspaces.
  # Each app is launched from its desktop entry, so wrapper env survives; a class
  # with no entry and no same-named command is recorded with exec null.
  state = ''"$HOME/.local/state/hyprland/layout.json"'';

  # Desktop entry search order: system, home-manager/user profile, per-user profile.
  appDirs = ''/run/current-system/sw/share/applications $HOME/.local/share/applications $HOME/.nix-profile/share/applications /etc/profiles/per-user/$(id -un)/share/applications'';

  saveLayout = pkgs.writeShellApplication {
    name = "hypr-layout-save";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      out=${state}
      mkdir -p "$(dirname "$out")"

      # Exec line of the desktop entry whose StartupWMClass, or file name, is the
      # class, with the %u/%F style field codes dropped. Empty when there is none.
      exec_for() {
        local class=$1 d f line
        for d in ${appDirs}; do
          f=$(grep -rlFxi --include='*.desktop' "StartupWMClass=$class" "$d" 2>/dev/null | head -n1 || true)
          [ -n "$f" ] || f="$d/$class.desktop"
          if [ -f "$f" ]; then
            line=$(grep -m1 '^Exec=' "$f" || true)
            printf '%s' "''${line#Exec=}" | sed -E 's/ %[a-zA-Z]//g; s/%%/%/g'
            return 0
          fi
        done
        # No entry: a command named like the class (herdr-app), else nothing
        if command -v "$class" >/dev/null 2>&1; then printf '%s' "$class"; fi
        return 0
      }

      # Mirrors keybinds.nix: the kitty windows are launched by their own commands.
      launcher_for() {
        case $1 in
          kitty) printf '%s' kitty-start ;;
          kitty-yazi) printf '%s' "kitty --class kitty-yazi yazi" ;;
          *) exec_for "$1" ;;
        esac
      }

      # Mapped windows on real workspaces; games (steam_app_*) and the throwaway
      # scratch terminal are not part of a layout.
      clients=$(hyprctl clients -j | jq -c '[.[] | select(.mapped and .workspace.id > 0 and .class != "" and .class != "kitty-scratch" and (.class | startswith("steam_app_") | not))]')

      rows=""
      while read -r w; do
        class=$(jq -r .class <<<"$w")
        launch=$(launcher_for "$class")
        rows+=$(jq -c --arg launch "$launch" '{class, workspace: .workspace.id, floating, y: .at[1], x: .at[0], h: .size[1], exec: (if $launch == "" then null else $launch end)}' <<<"$w")$'\n'
      done < <(jq -c '.[]' <<<"$clients")

      count=$(printf '%s' "$rows" | grep -c . || true)
      if [ "$count" -eq 0 ]; then
        hyprctl notify -1 2500 "rgb(f9e2af)" "Nothing saved, no windows on workspaces"
        exit 1
      fi

      # Tape columns: windows that share a workspace and y are one strip. colh is the
      # column's window height, kept only for tiled windows on scrolling workspaces.
      scroll=$(hyprctl workspaces -j | jq -c '[.[] | select(.tiledLayout == "scrolling") | .id]')
      tmp=$(mktemp "$out.XXXXXX")
      printf '%s' "$rows" | jq -s --arg saved "$(date -Is)" --argjson scroll "$scroll" '
        def columns:
          reduce .[] as $w ({rows: [], key: null, n: -1};
            ([$w.workspace, $w.y]) as $k
            | (if $k == .key then .n else .n + 1 end) as $n
            | .rows += [$w + {col: $n}] | .key = $k | .n = $n)
          | .rows;
        {saved: $saved, windows: (
          sort_by(.workspace, .y, .x) | columns
          | map(. as $r | . + {colh: (if (.floating | not) and ($scroll | any(. == $r.workspace)) then .h else null end)} | del(.h))
        )}' >"$tmp"
      mv "$tmp" "$out"

      ws=$(jq '[.windows[].workspace] | unique | length' "$out")
      nolaunch=$(jq '[.windows[] | select(.exec == null)] | length' "$out")
      hyprctl notify -1 2500 "rgb(a6da95)" "Saved $count windows on $ws workspaces ($nolaunch without a launcher)"
    '';
  };

  restoreLayout = pkgs.writeShellApplication {
    name = "hypr-layout-restore";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      in=${state}
      dry=false
      if [ "''${1:-}" = --dry-run ]; then dry=true; fi

      if [ ! -f "$in" ]; then
        hyprctl notify -1 3000 "rgb(f9e2af)" "No saved layout yet, save one with CTRL+SUPER+ALT+S"
        exit 1
      fi

      # Launch only what is missing: a class with a window already running is left
      # alone, so a second restore is a no-op. Each launch goes onto its saved
      # workspace, silently (no focus change).
      running=$(hyprctl clients -j | jq -r '.[].class')
      launched=0
      skipped=0
      while read -r w; do
        class=$(jq -r .class <<<"$w")
        launch=$(jq -r '.exec // empty' <<<"$w")
        ws=$(jq -r .workspace <<<"$w")
        if grep -qxF -- "$class" <<<"$running"; then
          skipped=$((skipped + 1))
          continue
        fi
        if [ -z "$launch" ]; then
          echo "no launcher for $class, skipped" >&2
          skipped=$((skipped + 1))
          continue
        fi

        rule="{ workspace = \"$ws silent\""
        if [ "$(jq -r .floating <<<"$w")" = true ]; then rule+=", float = true"; fi
        rule+=" }"
        expr="hl.dsp.exec_cmd($(jq -nc --arg s "$launch" '$s'), $rule)"

        if $dry; then
          printf '%-22s workspace %-2s %s\n' "$class" "$ws" "$launch"
        else
          hyprctl dispatch "$expr" >/dev/null
          # Launches in quick succession race for tape order; a short gap keeps it.
          sleep 0.4
        fi
        running+=$'\n'"$class"
        launched=$((launched + 1))
      done < <(jq -c '.windows[]' "$in")

      # Column heights on the vertical tape: one colresize per column on its window.
      # A column is about 1870 * fraction - 17 px tall (measured on the live tape).
      # Focus follows the pointer and the tape moves under it, so follow-mouse is off
      # while this runs, and focus goes back to the window that had it at the start.
      sized=0
      if ! $dry; then
        follow=$(hyprctl getoption input:follow_mouse -j | jq -r .int)
        origin=$(hyprctl activewindow -j | jq -r .address)
        trap 'hyprctl eval "hl.config({ input = { follow_mouse = $follow } })" >/dev/null; hyprctl dispatch "hl.dsp.focus({ window = \"address:$origin\" })" >/dev/null' EXIT
        hyprctl eval 'hl.config({ input = { follow_mouse = 0 } })' >/dev/null
      fi
      used=""
      while read -r c; do
        class=$(jq -r .class <<<"$c")
        colh=$(jq -r .colh <<<"$c")
        f=$(awk -v h="$colh" 'BEGIN { printf "%.4f", (h + 17) / 1870 }')
        addr=""
        # A launch may still be mapping: wait up to ~10 s for its window
        for _ in $(seq 20); do
          addr=$(hyprctl clients -j | jq -r --arg c "$class" '[.[] | select(.class == $c)] | sort_by(.at[1]) | .[].address' | grep -vxF -- "$used" | head -n1 || true)
          [ -n "$addr" ] && break
          sleep 0.5
        done
        if [ -z "$addr" ]; then
          echo "no window for column $class, height not restored" >&2
          continue
        fi
        used+="$addr"$'\n'
        if $dry; then
          printf '%-22s column height %-5s colresize %s\n' "$class" "$colh" "$f"
          continue
        fi
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
        sleep 0.6
        # Never resize a column that is not the focused one
        if [ "$(hyprctl activewindow -j | jq -r .address)" != "$addr" ]; then
          echo "could not focus $class, height not restored" >&2
          continue
        fi
        hyprctl dispatch "hl.dsp.layout(\"colresize $f\")" >/dev/null
        sleep 0.6
        sized=$((sized + 1))
      done < <(jq -c '[.windows[] | select(.colh != null)] | unique_by(.col)[]' "$in")

      if $dry; then
        echo "would launch $launched, skip $skipped; $sized columns"
      else
        hyprctl notify -1 2500 "rgb(a6da95)" "Restored: launched $launched, skipped $skipped, sized $sized columns"
      fi
    '';
  };
in
{
  home.packages = [
    saveLayout
    restoreLayout
  ];
}
