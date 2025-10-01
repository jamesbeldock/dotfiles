set -x	# debugging on
pwd

# Run this script first of all. It will run the others.

source ./shell.sh		#TODO: fix this for Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
	source ./osx-package-install.sh
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
	source ./linux-apt-package-install.sh
fi

PACKAGE=(
	"basic"
	"config resources"
	"git"
	"iterm2"
	"nvim"
	"oh-my-zsh"
	"starship"
	"tmux"
	"wezterm"
	"zsh"
)

for package in "${PACKAGE[@]}"; do
	stow -v -t ~/ --dotfiles "$package"
done

#atuin installation and stow package
zinit ice as"command" from"gh-r" bpick"atuin-*.tar.gz" mv"atuin*/atuin -> atuin" \
    atclone"./atuin init zsh > init.zsh; ./atuin gen-completions --shell zsh > _atuin" \
    atpull"%atclone" src"init.zsh"
zinit light atuinsh/atuin
stow -v -t ~/ --dotfiles atuin

# install eza theme
ln -s ~/.config/resources/tokyonight.yml ~/.eza/theme.yml

# set up TPM (tmux plugin manager)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone https://github.com/2KAbhishek/tmux2k.git ~/.tmux/plugins/tmux2k
