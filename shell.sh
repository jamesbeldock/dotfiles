# install the Homebrew version of zsh and permit it to be a default shell
sudo sh -c "echo '/opt/homebrew/bin/zsh' >> /etc/shells && chsh -s /opt/homebrew/bin/zsh"

# install Oh My Zsh and upgrade
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
omz update

# fix permissions on /opt/homebrew/share directories
chmod g-w,o-w /opt/homebrew/bin/zsh
# chmod g-w,o-w /opt/homebrew/bin/zsh/site-functions
