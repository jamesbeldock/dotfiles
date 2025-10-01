-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

require("lazy").setup({
  {"nvim-treesitter/nvim-treesitter", branch = 'master', lazy = false, build = ":TSUpdate"}
})
