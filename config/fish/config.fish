# rice and the rest from install.sh live in ~/.local/bin, and Arch does not put it in PATH
fish_add_path -g ~/.local/bin

if status is-interactive
    # Starship custom prompt
    command -v starship &> /dev/null && starship init fish | source

    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish | source

    # Better ls
    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    # cava as dots, like Glyph Matrix (~/.config/cava/dots); regular bars -- command cava
    command -v cava &> /dev/null && alias cava ~/.config/cava/dots

    # Abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'


    # For jumping between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end

# User environment & tools (cross-distro portable)
test -f "$HOME/.openclaw/completions/openclaw.fish"; and source "$HOME/.openclaw/completions/openclaw.fish"
test -d "$HOME/.opencode/bin"; and fish_add_path "$HOME/.opencode/bin"
fish_add_path "$HOME/.local/bin"

if type -q fdfind
    alias fd fdfind
end

# Activate Python virtual environment if present
if test -f "$HOME/.local/share/rice/venv/bin/activate.fish"
    source "$HOME/.local/share/rice/venv/bin/activate.fish"
else if test -f "$HOME/extras/local_venv/bin/activate.fish"
    source "$HOME/extras/local_venv/bin/activate.fish"
end

