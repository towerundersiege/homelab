#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -eq 0 ]]; then
  echo "Run this as the normal operator user, not root." >&2
  exit 1
fi

sudo -v
sudo apt-get update
sudo apt-get install -y \
  ca-certificates curl dnsutils fd-find fzf git htop jq less ncdu ripgrep \
  smartmontools tmux tree vim zsh zsh-autosuggestions zsh-syntax-highlighting
sudo chsh -s /usr/bin/zsh "$USER"

mkdir -p "$HOME/.config/zsh" "$HOME/.cache/zsh" "$HOME/.local/bin" \
  "$HOME/.local/share" "$HOME/.local/state/zsh"

cat > "$HOME/.zshenv" <<'EOF_ZSHENV'
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
EOF_ZSHENV

cat > "$HOME/.config/zsh/.zprofile" <<'EOF_ZPROFILE'
export EDITOR=vim
export GIT_EDITOR=vim
export PAGER=less
unset LESSOPEN
export PATH="$HOME/.local/bin:$PATH"
export KUBECONFIG="$XDG_CONFIG_HOME/kube/config"
export KUBECACHEDIR="$XDG_CACHE_HOME/kube"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"
EOF_ZPROFILE

cat > "$HOME/.config/zsh/.zshrc" <<'EOF_ZSHRC'
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
setopt extended_history hist_find_no_dups hist_ignore_dups hist_reduce_blanks
setopt hist_verify inc_append_history share_history

bindkey -e
export WORDCHARS="_-"
setopt globdots nolistbeep prompt_subst

autoload -Uz colors add-zsh-hook vcs_info compinit
colors
zstyle ':vcs_info:git:*' formats ' %b'
precmd_vcs_info() { vcs_info }
add-zsh-hook precmd precmd_vcs_info
PROMPT='%F{magenta}%m%f %F{blue}%~%f%F{green}${vcs_info_msg_0_}%f %(?.%F{green}.%F{red})$%f '

if [[ -z "$TMUX" && -t 1 ]] && command -v tmux >/dev/null 2>&1; then
  tmux attach -t home 2>/dev/null || tmux new -s home
fi

alias ls='ls -hv --color=auto --group-directories-first'
alias la='ls -a'
alias ll='ls -al'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -vI'
alias md='mkdir -pv'
alias v='vim'
alias tmux='tmux -u2'
alias fd='fdfind'

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gca='git commit --amend --no-edit'
alias gpl='git pull'
alias gp='git push'
alias gco='git checkout'
alias gcob='git checkout -b'
glo() { git log --oneline -"${1:-5}"; }

alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pod'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kgc='kubectl config get-contexts'
alias kuc='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

export FZF_DEFAULT_OPTS='--height=40% --layout=reverse -m --border=rounded --no-separator --no-scrollbar'
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

for plugin in \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
do
  [[ -r "$plugin" ]] && source "$plugin"
done
EOF_ZSHRC

echo "CLI bootstrap complete. Log out and reconnect so the zsh login shell starts."
