#!/usr/bin/env zsh 

#PROMPT_SUCCESS_COLOR=$FG[103]
#PROMPT_FAILURE_COLOR=$FG[124]
RED_COLOR=$FG[124]
#VCS_CLEAN_COLOR=$FG[148]

MSK_THEME_START_TIME=""
MSK_THEME_END_TIME=""
MSK_THEME_MIN_DT=10
MSK_THEME_TIME_COUNT=0

function unixtime {
    echo $(date +%s)
}

# --- VCS prompt control -------------------------------------------------------
typeset -g MSK_THEME_VCS_MODE=${MSK_THEME_VCS_MODE:-auto}   # on | off | auto
typeset -g MSK_THEME_VCS_DETAIL=${MSK_THEME_VCS_DETAIL:-full} # full | light
typeset -g MSK_THEME_VCS_MIN_INTERVAL=${MSK_THEME_VCS_MIN_INTERVAL:-2}
typeset -g MSK_THEME_VCS_LAST_TS=0
typeset -g MSK_THEME_VCS_LAST_PWD=""
typeset -g MSK_THEME_VCS_STYLE_APPLIED=""

# Best-effort fs type detection (Linux first; falls back to stat)
function msk_fs_type() {
  local p="${1:-$PWD}" fs=""
  if [[ -r /proc/mounts ]]; then
    fs=$(
      awk -v p="$p" '
        BEGIN { best=""; fs="" }
        {
          mp=$2; gsub(/\\040/, " ", mp)
          if (index(p, mp)==1 && length(mp)>length(best)) { best=mp; fs=$3 }
        }
        END { print fs }
      ' /proc/mounts
    )
    print -r -- "${fs:-unknown}"
    return
  fi

  if command stat -f -c %T . >/dev/null 2>&1; then
    stat -f -c %T .
  elif command stat -f %T . >/dev/null 2>&1; then
    stat -f %T .
  else
    print -r -- unknown
  fi
}

function msk_is_slow_fs() {
  local fs="$(msk_fs_type "$PWD")"
  case "$fs" in
    nfs*|cifs*|smbfs*|sshfs*|fuse.sshfs*|fuse.*|lustre*|gpfs*|panfs*|afs* ) return 0 ;;
    * ) return 1 ;;
  esac
}

function msk_apply_vcs_styles() {
  local key="${MSK_THEME_VCS_DETAIL}"
  [[ "$MSK_THEME_VCS_STYLE_APPLIED" == "$key" ]] && return 0
  MSK_THEME_VCS_STYLE_APPLIED="$key"

  if [[ "$MSK_THEME_VCS_DETAIL" == light ]]; then
    zstyle ':vcs_info:*' check-for-changes false
    zstyle -d ':vcs_info:git*+set-message:*' hooks 2>/dev/null
  else
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:git*+set-message:*' hooks untracked-git
  fi
}

function msk_vcs_enabled() {
  case "$MSK_THEME_VCS_MODE" in
    off)  return 1 ;;
    on)   return 0 ;;
    auto) msk_is_slow_fs && return 1 || return 0 ;;
    *)    return 0 ;;
  esac
}

# Interactive command: msk_vcs on|off|auto|light|full|toggle
function msk_vcs() {
  case "$1" in
    on|off|auto) MSK_THEME_VCS_MODE="$1" ;;
    light|full)  MSK_THEME_VCS_DETAIL="$1" ;;
    toggle)
      [[ "$MSK_THEME_VCS_MODE" == off ]] && MSK_THEME_VCS_MODE=on || MSK_THEME_VCS_MODE=off
      ;;
    *) print -r -- "usage: msk_vcs on|off|auto|light|full|toggle"; return 2 ;;
  esac

  # Clear stale VCS output when disabling
  if ! msk_vcs_enabled; then
    vcs_info_msg_0_=""
  fi

  # Refresh prompt immediately if we're in ZLE
  [[ -n "$ZLE" ]] && zle reset-prompt 2>/dev/null
}
# Optional convenience aliases
alias vcs-off='msk_vcs off'
alias vcs-on='msk_vcs on'
alias vcs-auto='msk_vcs auto'
alias vcs-light='msk_vcs light'
alias vcs-full='msk_vcs full'

function msk_precmd {
  MSK_THEME_END_TIME=$(unixtime)
  local now=$MSK_THEME_END_TIME

  if msk_vcs_enabled; then
    msk_apply_vcs_styles

    # Throttle updates + always update on directory change
    if (( now - MSK_THEME_VCS_LAST_TS >= MSK_THEME_VCS_MIN_INTERVAL )) || [[ "$PWD" != "$MSK_THEME_VCS_LAST_PWD" ]]; then
      vcs_info
      MSK_THEME_VCS_LAST_TS=$now
      MSK_THEME_VCS_LAST_PWD=$PWD
    fi
  else
    vcs_info_msg_0_=""
  fi

  MSK_THEME_TIME_COUNT=$(($MSK_THEME_TIME_COUNT+1))
}

add-zsh-hook precmd msk_precmd

function msk_preexec {
    MSK_THEME_START_TIME=$(unixtime)
    MSK_THEME_TIME_COUNT=0
}

add-zsh-hook preexec msk_preexec

# Set up vcs info style
zstyle ':vcs_info:*' enable git bzr svn hg

zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr "$RED_COLOR✘${reset_color}"   # display this when there are unstaged changes
zstyle ':vcs_info:*' stagedstr "%F{yellow}✔${reset_color}"  # display this when there are staged changes
zstyle ':vcs_info:*' actionformats "%s 📂%r%F{yellow}│${reset_color}%S %F{magenta}%b${reset_color} [$RED_COLOR%a${reset_color}] %c%u%m"
zstyle ':vcs_info:*' formats "%s 📂%r%F{yellow}│${reset_color}%S %F{magenta}%b${reset_color} %c%u%m"
zstyle ':vcs_info:git*+set-message:*' hooks untracked-git

+vi-untracked-git() {
  if command git status --porcelain 2>/dev/null | command grep -q '??'; then
    hook_com[misc]="%F{red}?${reset_color}"
  else
    hook_com[misc]=''
  fi
}

function zle-keymap-select {
    # Skip DECSCUSR if TERM is "linux" (as in JuiceSSH)
    if [[ "$TERM" == "linux" ]]; then
	return
    fi
    if [[ ${KEYMAP} == vicmd ]] ||
       [[ $1 = 'block' ]]; then
        echo -ne '\e[1 q'
    elif [[ ${KEYMAP} == main ]] ||
         [[ ${KEYMAP} == viins ]] ||
         [[ ${KEYMAP} == '' ]] ||
         [[ ${KEYMAP} == 'underline' ]]; then
        echo -ne '\e[3 q'
    fi
}
zle -N zle-keymap-select
function zle-line-init {
    if [[ "$TERM" == "linux" ]]; then
	return
    fi
    echo -ne '\e[3 q'
}
zle -N zle-line-init

zle_highlight=(region:standout special:standout suffix:bold isearch:underline paste:standout)

function collapse_pwd {
    echo $(pwd | sed -e "s,^$HOME,~,")
}

function prev_cmd_time_info {
    if [[ -n ${MSK_THEME_START_TIME} ]] && [[ -n ${MSK_THEME_END_TIME} ]] && [[ ${MSK_THEME_TIME_COUNT} -eq 1 ]]
    then
        dt=$(($MSK_THEME_END_TIME-$MSK_THEME_START_TIME))
        if (( $dt >= $MSK_THEME_MIN_DT ))
        then
            days=$(($dt/86400))
            if [[ $days > 0 ]]
            then
                dt=$(($dt-$days*86400))
                hrs=$(($dt/3600))
                dt=$(($dt-$hrs*3600))
                mins=$(($dt/60))
                dt=$(($dt-$mins*60))
                secs=$dt
                MSK_THEME_DT="${days}d ${hrs}h ${mins}m ${secs}s"
            else
            hrs=$(($dt/3600))
            if [[ $hrs > 0 ]]
            then
                dt=$(($dt-$hrs*3600))
                mins=$(($dt/60))
                dt=$(($dt-$mins*60))
                secs=$dt
                MSK_THEME_DT="${hrs}h ${mins}m ${secs}s"
            else
            mins=$(($dt/60))
            if [[ $mins > 0 ]]
            then
                dt=$(($dt-$mins*60))
                secs=$dt
                MSK_THEME_DT="${mins}m ${secs}s"
            else
                MSK_THEME_DT="${dt}s"
            fi
            fi
            fi
            echo "%{$fg[green]%}§%{$reset_color%} Command took %{$fg[green]%}$MSK_THEME_DT%{$reset_color%}\n "
        fi
    else
    fi
}

function virtualenv_info {
    #[ $VIRTUAL_ENV ] && echo "\n["`basename $VIRTUAL_ENV`"]"
    [ $VIRTUAL_ENV ] && echo "\n[$VIRTUAL_ENV]"
}

function conda_info {
    if [[ -n $CONDA_DEFAULT_ENV ]]
    then
        if [[ $CONDA_DEFAULT_ENV == *"/"* ]]
        then
            echo "\n(📂 $CONDA_DEFAULT_ENV)"
        else
            echo "\n($CONDA_DEFAULT_ENV)"
        fi
    fi
}

function current_date {
    echo $(date +"%a %b %d %T")
}

function msk_vcs_info {
  [[ -n "${vcs_info_msg_0_}" ]] && echo "\n${vcs_info_msg_0_}"
}

PROMPT='$(prev_cmd_time_info)
%{$fg[red]%}%n%{$reset_color%} on %{$fg[blue]%}%m%{$reset_color%} [%{$fg[green]%}$(current_date)%{$reset_color%}]$(msk_vcs_info)$(virtualenv_info)$(conda_info)
%{$fg_bold[black]%}$(collapse_pwd)%{$reset_color%}
%{$fg_bold[black]%}❯%{$reset_color%} '

# In the future, I may want to change the cursor style. It's called 'DECSCUSR'.
# set it like this: echo -ne '\e[5 q' and replace the 5 with 
# 0 - blinking block
# 1 - blinking block (default)
# 2 - steady block
# 3 - blinking underline
# 4 - steady underline
# 5 - blinking bar, xterm
# 6 - steady bar, xterm

RPROMPT=""
