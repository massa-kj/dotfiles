# The operating system type for dotfiles configuration scripts
export DOTFILES_OS_TYPE=linux
# Set the default editor to nvim
export EDITOR=nvim
# default less options
export LESS='-i -M -R'

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

eval "$(mise activate bash)"
# if type mise &>/dev/null; then
# 	eval "$(mise activate bash)"
# 	eval "$(mise activate --shims)"
# else
# 	echo "mise is not installed."
# fi

