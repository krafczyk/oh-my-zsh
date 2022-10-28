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

function msk_precmd {
    MSK_THEME_END_TIME=$(unixtime)
    vcs_info
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
    echo "\n${vcs_info_msg_0_}"
}

PROMPT='$(prev_cmd_time_info)
%{$fg[red]%}%n%{$reset_color%} on %{$fg[blue]%}%m%{$reset_color%} [%{$fg[green]%}$(current_date)%{$reset_color%}]$(msk_vcs_info)$(virtualenv_info)$(conda_info)
%{$fg_bold[black]%}$(collapse_pwd)%{$reset_color%}
%{$fg_bold[black]%}❯%{$reset_color%} '

RPROMPT=""
