# Search the command history and expand it to the command line.
__fzf_history() {
	local cmd
	cmd=$(history |
		# Delete the numbers, sort them by newest, and output only the first one.
		sed 's/ *[0-9]* *//' | tac | awk '!seen[$0]++' |
		fzf --no-sort --reverse --bind=ctrl-s:toggle-sort --bind 'ctrl-e:accept,tab:accept')

	if [[ -n $cmd ]]; then
		READLINE_LINE="$cmd"
		READLINE_POINT=${#cmd}
	fi
}
# Assign(Override) history search to Ctrl-r.
bind -x '"\C-r": __fzf_history'

__git_commit_browser() {
	git log --graph --color=always \
		--format="%C(red)%h %C(green)(%cd)%C(yellow)%d %C(reset)%s %C(bold blue)<%an>%C(reset)" --date=format:'%Y-%m-%d %H:%M:%S' "$@" |
	fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
		--bind "ctrl-m:execute:
			(grep -o '[a-f0-9]\{7\}' | head -1 |
			xargs -I % sh -c 'git show % | delta | less -R') << 'FZF-EOF'
			{}
FZF-EOF"
}

__git_diff_browser() {
	local args="$*"
	git diff --name-only \
		$args |
	fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
		--bind "ctrl-m:execute:
			(head -1 |
			xargs -I % sh -c 'git diff $args -- \"%\" | delta | less -R') << 'FZF-EOF'
			{}
FZF-EOF"
}

__cd_fzf() {
	local dir
	dir=$(find ${1:-.} -path '*/\.*' -prune \
					-o -type d -print 2> /dev/null | fzf +m) &&
	cd "$dir"
}
__cd_git_root() {
	cd $(git rev-parse --show-toplevel)
}

# -------------------------
# Private function for recursive tree display
#   _tree_with_lines <directory> <prefix> <current_depth> <max_depth> <excludes_array...>
# -------------------------
_tree_with_lines() {
	local dir="$1"
	local prefix="$2"
	local current_depth="$3"
	local max_depth="$4"
	shift 4
	local excludes=("$@")  # Rest arguments as an array (.git, node_modules, etc.)

	# Get a list of elements in a directory (including hidden files)
	local items=()
	mapfile -t items < <(ls -A "$dir" 2>/dev/null || true)

	local count=${#items[@]}
	local i=0

	for item in "${items[@]}"; do
		((i++))
		local path="$dir/$item"

		# ---------- Exclusion Check ----------
		# If it is included in the excludes array, it will be skipped.
		local skip=""
		for exc in "${excludes[@]}"; do
			if [[ "$item" == "$exc" ]]; then
				skip=1
				break
			fi
		done
		[ -n "$skip" ] && continue
		# ---------------------------------

		# Set the tree branch characters
		local branch="├──"
		[ $i -eq $count ] && branch="└──"  # If it is the last element, use "└──"

		if [ -d "$path" ]; then
			# In the case of a directory, the line number is not displayed and the output is as is.
			echo "${prefix}${branch} $item"

			# If max_depth has not been reached yet, recurse down
			if [ "$current_depth" -lt "$max_depth" ]; then
				local new_prefix="${prefix}│   "
				[ $i -eq $count ] && new_prefix="${prefix}    "
				_tree_with_lines "$path" "$new_prefix" $((current_depth + 1)) "$max_depth" "${excludes[@]}"
			fi
		else
			# If it is a file, get the number of lines (0 on failure)
			local lines
			lines=$(wc -l < "$path" 2>/dev/null || echo 0)
			echo "${prefix}${branch} $item  ($lines lines)"
		fi
	done
}

# -------------------------
# 
#   tree_with_lines [<directory>] [<max_depth>] [--exclude <dir_to_exclude> ...]
# -------------------------
__tree_with_lines() {
	local target_dir="."
	local max_depth="1"

	# Default exclusion list
	local EXCLUDES=( ".git" )

	# For argument analysis
	while [ $# -gt 0 ]; do
		case "$1" in
			# Add to the exclude list when called with the --exclude <dir> form
			-x|--exclude)
				if [ -n "$2" ]; then
					EXCLUDES+=("$2")
					shift 2
				else
					echo "ERROR: The --exclude option must be followed by the name of the directory to be excluded." >&2
					return 1
				fi
				;;
			-d|--depth)
				if [ -n "$2" ]; then
					max_depth="$2"
					max_depth_specified=1
					shift 2
				else
					echo "ERROR: The -d option is required followed by depth." >&2
					return 1
				fi
				;;
			*)
				if [ -n "$1" ]; then
					target_dir="$1"
					target_dir_specified=1
					shift 1
				else
					echo "ERROR: The -p option must be followed by a path." >&2
					return 1
				fi
				;;
		esac
	done

	# Show top-level directory name (optional if necessary)
	echo "$target_dir"

	# If the hierarchy depth is 1 or more, search below
	if [ "$max_depth" -ge 1 ]; then
		_tree_with_lines "$target_dir" "" 1 "$max_depth" "${EXCLUDES[@]}"
	fi
}

__repo() {
  local selected
  selected=$(ghq list | fzf --reverse)
  if [ -n "$selected" ]; then
    cd "$HOME/ghq/$selected"
  else
    return 1
  fi
}

alias cdf="__cd_fzf"
alias cdr="__cd_git_root"
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dirs="dirs -v"
alias doc="docker container"
alias doce="docker container exec -it"
alias docl="docker container ls"
alias docr="docker container run"
alias doi="docker image"
alias doib="docker image build"
alias doil="docker image ls"
alias don="docker network"
alias dov="docker volume"
alias g="git"
alias gshow="__git_commit_browser"
alias hist="history"
alias l='ls -CF'
alias la='ls -A'
alias lg="lazygit"
alias ll='ls -alF'
alias gd="pushd"
alias gdf="__git_diff_browser"
alias ghs="gh search"
alias ghsr="gh search repos --sort=stars --order=desc"
alias pd="popd"
alias repo="__repo"
alias tm="tmux"
alias vtree="__tree_with_lines"
alias vi="nvim"
alias vim="nvim"
alias virepo="cd ~/ghq/\$(ghq list | fzf --reverse) && vi"

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

