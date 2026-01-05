function _fzf_history_purge --description "Clear fzf file history"
    rm -f "$HOME/.local/share/fzf_file_history"
end
