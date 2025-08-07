

# alias python=python3
alias p=python
# alias pip=pip3



alias ls='eza -F --icons --color=always --group-directories-first' # eza is an ls replacement
alias l='eza -alF --icons --color=always --group-directories-first'
alias la='eza -a --icons --color=always --group-directories-first'
alias l.='eza -a | egrep "^\."'

alias cls=clear
#alias vscode=code 
#alias code=codium

alias clu='ssh laurenzo@login.cluster.uy'
alias inco='ssh laurenzo@login-inco.fing.edu.uy'
alias convo='ssh tola1460@conversation.colorado.edu'
alias monvo='sshfs tola1460@conversation.colorado.edu:/home/tola1460/devel/ /Users/tom/devel/ml-llm/ml/cu.boulder'
alias monvoff="umount -f tola1460@conversation.colorado.edu:/home/tola1460/devel/"

alias rmds='find "${@:-.}" -name ".DS_Store" -delete'
alias tst='echo "${@:-.}"'
  
export CC=clang
export CXX=clang++

#export GDRIVE_LOCAL_BASE_DIR="/Users/tom/GoogleDriveTom"
#export GDRIVE_REMOTE_BASE_NAME="GoogleDriveTom"
	
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/tom/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/tom/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/Users/tom/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/tom/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

ssh-add --apple-use-keychain ~/.ssh/id_rsa
ssh-add --apple-use-keychain ~/.ssh/conversation_id_rsa

export PATH="\
/Users/tom/devel/ml-llm/flutter/bin:\

/Users/tom/miniforge3/bin:/Users/tom/miniforge3/condabin:\

/opt/homebrew/bin:/opt/homebrew/sbin:\

/usr/local/bin:\

/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:\

/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:\
/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:\
/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:\

/Library/Apple/usr/bin:\

/Library/TeX/texbin:\

/Applications/Little Snitch.app/Contents/Components:\

/Users/tom/.cargo/bin:\

/Users/tom/devel/shell-scripts/bin:\

$PATH"


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tom/devel/ml-llm/ml/gtts/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/tom/devel/ml-llm/ml/gtts/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/tom/devel/ml-llm/ml/gtts/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/tom/devel/ml-llm/ml/gtts/google-cloud-sdk/completion.zsh.inc'; fi

if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH=/opt/homebrew/opt/ruby/bin:$PATH
  export PATH=`gem environment gemdir`/bin:$PATH
fi

# Set XDG_DATA_DIRS for applications like czkawka_gui
export XDG_DATA_DIRS="/opt/homebrew/share:$XDG_DATA_DIRS"
export PATH=~/.npm-global/bin:$PATH
