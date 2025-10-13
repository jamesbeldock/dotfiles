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
