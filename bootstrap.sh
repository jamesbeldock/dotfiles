set -x	# debugging on
pwd

# Run this script first of all. It will run the others.

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ] ; then
	echo "Usage: bootstrap.sh [--help|-h] server|workstation|iot"
	echo "This script bootstraps a new machine by installing packages and stowing dotfiles."
	echo "server, workstation, and iot are predefined sets of packages."
	exit 0
elif [ "$1" = "server" ] || [ "$1" = "workstation" ] || [ "$1" = "iot" ] ; then
	MODE="$1"
else
	echo "Invalid option: $1"
	echo "Usage: bootstrap.sh [--help|-h] server|workstation|iot"
	exit 1
fi

source ./shell.sh		#TODO: fix this for Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
	source ./osx-package-install.sh "$MODE"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
	source ./linux-apt-package-install.sh "$MODE"
fi

source ./stow-packages.sh "$MODE"

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
