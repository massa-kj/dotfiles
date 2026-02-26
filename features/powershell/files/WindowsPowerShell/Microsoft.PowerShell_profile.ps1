Set-Alias vi nvim
Set-Alias vim nvim
Set-Alias lg lazygit
# Set-Alias make mingw32-make

# The operating system type for dotfiles configuration scripts
$env:DOTFILES_OS_TYPE = "windows"

# Prepared ~/.local/bin to PATH
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

# Initialize mise (version manager)
if (Get-Command mise -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (mise activate pwsh | Out-String) })
}

function repo {
    $selection = ghq list -p | fzf
    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-Output "No selection made. Exiting."
        return
    }
    cd $selection
}

function repocode {
    $selection = ghq list -p | fzf
    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-Output "No selection made. Exiting."
        return
    }
    code $selection
}

function repovi {
    $selection = ghq list -p | fzf
    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-Output "No selection made. Exiting."
        return
    }
    cd $selection
	nvim .
}

function viconf {
	cd $env:LOCALAPPDATA/nvim; vim .
}

