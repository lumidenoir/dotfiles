return {
  {
    "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim", -- optional, for nicer UI
    },
    config = function()
      local lspconfig = require("nvchad.configs.lspconfig")

      require("flutter-tools").setup {
        lsp = {
          on_attach = lspconfig.on_attach,
          capabilities = lspconfig.capabilities,
        }
      }
    end,
  },
}
