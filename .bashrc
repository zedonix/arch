PS1="\n \[\e[38;5;40m\]\w\[\e[38;5;51m\] > \[\e[0m\]"

set -o vi
HISTCONTROL=ignoreboth

export XDG_CURRENT_DESKTOP=sway
export EDITOR=nvim
export VISUAL=nvim

alias l="eza -l --icons=always"
alias ll="eza -la --icons=always"
alias vi="nvim ~/vimwiki/index.md"
alias vim="nvim"
alias nb="newsboat"
alias pic="swayimg"
alias speed="speedtest-cli --bytes"
alias record="asciinema rec"
alias play="asciinema play"
alias yt="yt-dlp"
alias fzf="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
eval "$(fzf --bash)"
