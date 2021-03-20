# install the Homebrew version of zsh and permit it to be a default shell
sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells && chsh -s /usr/local/bin/zsh"

# install Oh My Zsh and upgrade
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
omz update

# fix permissions on /usr/local/share directories
chmod g-w,o-w /usr/local/share/zsh
chmod g-w,o-w /usr/local/share/zsh/site-functions
