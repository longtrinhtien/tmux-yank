#!/usr/bin/env bash
PS4='♞: ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]} '
exec >> "/tmp/tmux_plugin_debug_verbose.log" 2>&1
# set -x
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${CURRENT_DIR}/scripts"
HELPERS_DIR="${CURRENT_DIR}/scripts"

# shellcheck source=scripts/helpers.sh
source "${HELPERS_DIR}/helpers.sh"

clipboard_copy_without_newline_command() {
    local copy_command="$1"
    printf "tr -d '\\n' | %s" "$copy_command"
}

set_error_bindings() {
    local key_bindings key
    key_bindings="$(yank_key) $(put_key) $(yank_put_key)"
    for key in $key_bindings; do
        if tmux_is_at_least 2.4; then
            tmux bind-key -T copy-mode-vi "$key" send-keys -X copy-pipe-and-cancel "tmux display-message 'Error! tmux-yank dependencies not installed!'"
            tmux bind-key -T copy-mode "$key" send-keys -X copy-pipe-and-cancel "tmux display-message 'Error! tmux-yank dependencies not installed!'"
        else
            tmux bind-key -t vi-copy "$key" copy-pipe "tmux display-message 'Error! tmux-yank dependencies not installed!'"
            tmux bind-key -t emacs-copy "$key" copy-pipe "tmux display-message 'Error! tmux-yank dependencies not installed!'"
        fi
    done
}

error_handling_if_command_not_present() {
    local copy_command="$1"
    if [ -z "$copy_command" ]; then
        set_error_bindings
        exit 0
    fi
}

# `yank_without_newline` binding isn't intended to be used by the user. It is
# a helper for `copy_line` command.
set_copy_mode_bindings() {
    local copy_command="$1"
    local copy_wo_newline_command
    copy_wo_newline_command="$(clipboard_copy_without_newline_command "$copy_command")"
    local copy_command_mouse
    copy_command_mouse="$(clipboard_copy_command "true")" # Lệnh copy ra clipboard hệ thống cho chuột

    # -- BINDINGS CHO TMUX PHIÊN BẢN 2.4 TRỞ LÊN --
    if tmux_is_at_least 2.4; then
        set -x
        tmux bind-key -T copy-mode-vi "$(yank_key)" send-keys -X "$(yank_action)" "$copy_command"
        tmux bind-key -T copy-mode-vi "$(put_key)" send-keys -X copy-pipe-and-cancel "tmux paste-buffer -p"
        tmux bind-key -T copy-mode-vi "$(yank_put_key)" send-keys -X copy-pipe-and-cancel "$copy_command; tmux paste-buffer -p"
        tmux bind-key -T copy-mode-vi "$(yank_wo_newline_key)" send-keys -X "$(yank_action)" "$copy_wo_newline_command"
        
        # Bắt đầu binding tùy chỉnh MouseDragEnd1Pane cho copy-mode-vi
        if [[ true ]]; then
            tmux bind-key -T copy-mode-vi MouseDragEnd1Pane run-shell ' \
                if [ "$(tmux display -p "#{scroll_position}")" -eq 0 ]; then \
                    # Nếu ở đầu (scroll_position == 0), copy và thoát chế độ copy \
                    tmux send-keys -X copy-pipe-and-cancel "'"$copy_command_mouse"'"; \
                else \
                    # Nếu không ở đầu, copy và giữ nguyên chế độ copy (-x) \
                    tmux send-keys -X copy-pipe "'"$copy_command_mouse"'" -x; \
                fi'
        fi
        set +x
        # Kết thúc binding tùy chỉnh MouseDragEnd1Pane cho copy-mode-vi

        tmux bind-key -T copy-mode "$(yank_key)" send-keys -X "$(yank_action)" "$copy_command"
        tmux bind-key -T copy-mode "$(put_key)" send-keys -X copy-pipe-and-cancel "tmux paste-buffer -p"
        tmux bind-key -T copy-mode "$(yank_put_key)" send-keys -X copy-pipe-and-cancel "$copy_command; tmux paste-buffer -p"
        tmux bind-key -T copy-mode "$(yank_wo_newline_key)" send-keys -X "$(yank_action)" "$copy_wo_newline_command"
        
        # Bắt đầu binding tùy chỉnh MouseDragEnd1Pane cho copy-mode (Emacs-like)
        if [[ "$(yank_with_mouse)" == "on" ]]; then
            tmux bind-key -T copy-mode MouseDragEnd1Pane run-shell ' \
                if [ "$(tmux display -p "#{scroll_position}")" -eq 0 ]; then \
                    # Nếu ở đầu (scroll_position == 0), copy và thoát chế độ copy
                    tmux send-keys -X copy-pipe-and-cancel "'"$copy_command_mouse"'"; \
                else \
                    # Nếu không ở đầu, copy và giữ nguyên chế độ copy (-x)
                    tmux send-keys -X copy-pipe "'"$copy_command_mouse"'" -x; \
                fi'
        fi
        # Kết thúc binding tùy chỉnh MouseDragEnd1Pane cho copy-mode

    # -- BINDINGS CHO TMUX PHIÊN BẢN DƯỚI 2.4 --
    else 
        tmux bind-key -t vi-copy "$(yank_key)" copy-pipe "$copy_command"
        tmux bind-key -t vi-copy "$(put_key)" copy-pipe "tmux paste-buffer -p"
        tmux bind-key -t vi-copy "$(yank_put_key)" copy-pipe "$copy_command; tmux paste-buffer -p"
        tmux bind-key -t vi-copy "$(yank_wo_newline_key)" copy-pipe "$copy_wo_newline_command"
        
        # Bắt đầu binding tùy chỉnh MouseDragEnd1Pane cho vi-copy (Tmux < 2.4)
        if [[ "$(yank_with_mouse)" == "on" ]]; then
            tmux bind-key -t vi-copy MouseDragEnd1Pane run-shell ' \
                if [ "$(tmux display -p "#{scroll_position}")" -eq 0 ]; then \
                    # Nếu ở đầu, copy và thoát chế độ copy
                    tmux copy-pipe "'"$copy_command_mouse"'"; \
                    tmux send-keys -X cancel; \
                else \
                    # Nếu không ở đầu, copy và giữ nguyên chế độ copy (không có -x, nên chỉ copy)
                    # Lưu ý: Tmux < 2.4 không có cách đơn giản để copy và giữ nguyên mode bằng chuột.
                    # Hành vi mặc định là thoát copy mode sau khi copy.
                    tmux copy-pipe "'"$copy_command_mouse"'"; \
                fi'
        fi
        # Kết thúc binding tùy chỉnh MouseDragEnd1Pane cho vi-copy

        tmux bind-key -t emacs-copy "$(yank_key)" copy-pipe "$copy_command"
        tmux bind-key -t emacs-copy "$(put_key)" copy-pipe "tmux paste-buffer -p"
        tmux bind-key -t emacs-copy "$(yank_put_key)" copy-pipe "$copy_command; tmux paste-buffer -p"
        tmux bind-key -t emacs-copy "$(yank_wo_newline_key)" copy-pipe "$copy_wo_newline_command"
        
        # Bắt đầu binding tùy chỉnh MouseDragEnd1Pane cho emacs-copy (Tmux < 2.4)
        if [[ "$(yank_with_mouse)" == "on" ]]; then
            tmux bind-key -t emacs-copy MouseDragEnd1Pane run-shell ' \
                if [ "$(tmux display -p "#{scroll_position}")" -eq 0 ]; then \
                    # Nếu ở đầu, copy và thoát chế độ copy
                    tmux copy-pipe "'"$copy_command_mouse"'"; \
                    tmux send-keys -X cancel; \
                else \
                    # Nếu không ở đầu, copy và giữ nguyên chế độ copy (không có -x, nên chỉ copy)
                    # Hành vi mặc định là thoát copy mode sau khi copy.
                    tmux copy-pipe "'"$copy_command_mouse"'"; \
                fi'
        fi
        # Kết thúc binding tùy chỉnh MouseDragEnd1Pane cho emacs-copy
    fi
}

set_normal_bindings() {
    tmux bind-key "$(yank_line_key)" run-shell -b "$SCRIPTS_DIR/copy_line.sh"
    tmux bind-key "$(yank_pane_pwd_key)" run-shell -b "$SCRIPTS_DIR/copy_pane_pwd.sh"
}

main() {
    local copy_command
    copy_command="$(clipboard_copy_command)"
    error_handling_if_command_not_present "$copy_command"
    set_copy_mode_bindings "$copy_command"
    set_normal_bindings
}
main
