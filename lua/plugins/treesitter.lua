return  {
  'nvim-treesitter/nvim-treesitter', 
  build = ':TSUpdate',
  config = function()
    local config = require("nvim-treesitter")
    config.setup({
      ensure_installed = { "lua", "html", "css", "c", "cpp", "go" },
      highlight = { enable = true },
      indent = { enable = true },  
    }) 
  end
}