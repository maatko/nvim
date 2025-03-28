return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local config = require("nvim-treesitter")
    config.setup({
      ensure_installed = { "lua", "python", "c", "cpp", "java" },
      highlight = { enable = true },
    })
  end,
}
