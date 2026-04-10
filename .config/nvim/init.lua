-- =========================
-- 🧠 Opciones básicas
-- =========================
vim.cmd [[
  hi Normal guibg=NONE ctermbg=NONE
  hi NormalNC guibg=NONE ctermbg=NONE
  hi EndOfBuffer guibg=NONE ctermbg=NONE
]]
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.g.mapleader = " "
vim.g.terminal_emulator = "kitty"
vim.g.copilot_no_tab_map = true

vim.keymap.set('i', '<Right>', 'copilot#Accept("<Right>")',
  { expr = true, script = true, silent = true, replace_keycodes = false })

-- =========================
-- 🚀 Lazy.nvim setup
-- =========================
local lazypath = vim.fn.stdpath("config") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Explorador de archivos
  { "nvim-tree/nvim-tree.lua", config = function() require("nvim-tree").setup() end },
  { "nvim-tree/nvim-web-devicons" },

  -- Barra de estado
  { "nvim-lualine/lualine.nvim", config = function() require("lualine").setup() end },

  -- Tema
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },

  -- Syntax highlighting mejorado
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

  -- Autocompletado
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "huy-hng/anyline.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = true,
    event = "VeryLazy",
  },
  -- LSP
  { "neovim/nvim-lspconfig" },
  { "github/copilot.vim" },
  { "sphamba/smear-cursor.nvim",
    opts = {
        cursor_color = "#FFFFFF",
        smear_between_buffers = true,
        smear_between_neighbor_lines = true,
        smear_insert_mode = true,
        legacy_computing_symbols_support = true

    }
  },
  { "karb94/neoscroll.nvim",
    config = function()
      require("neoscroll").setup()
    end
  },
  -- Gestor de LSPs
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end
  },
  { "williamboman/mason-lspconfig.nvim" },

  -- Terminal flotante
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        open_mapping = [[<C-\>]],
        direction = "float",
        float_opts = {
          border = "curved",
          winblend = 3,
        },
      })
    end
  },
})

-- =========================
-- 🎨 Tema y apariencia
-- =========================
require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = true,
})
vim.cmd.colorscheme "catppuccin"

-- =========================
-- 🌳 Treesitter
-- =========================
require("nvim-treesitter.configs").setup({
  highlight = { enable = true },
})

require("smear_cursor").setup()

-- =========================
-- 🗂️ Mapeos
-- =========================
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- =========================
-- ⚙️ Autocompletado
-- =========================
local cmp = require("cmp")
cmp.setup({
  mapping = {
    ['<Tab>'] = cmp.mapping.select_next_item(),
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  },
  sources = {
    { name = "nvim_lsp" },
  },
})

-- =========================
-- 🧩 Configuración LSP moderna con Mason (Neovim 0.10+)
-- =========================

-- Obtenemos las capabilities necesarias para la integración con nvim-cmp
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Usamos mason-lspconfig.nvim para gestionar la instalación e iniciar los LSPs
require("mason-lspconfig").setup({
    -- 1. Asegura que estos LSPs estén instalados por Mason:
    ensure_installed = { "pyright", "clangd" },

    -- 2. Define la configuración para cada servidor a través de 'handlers':
    handlers = {
        -- Manejador universal: aplica esta configuración a CUALQUIER LSP listado.
        ["*"] = function(server_name)
            -- Llama a lspconfig.setup() para el servidor actual (pyright, clangd, etc.)
            require("lspconfig")[server_name].setup({
                capabilities = capabilities,
                -- Aquí podrías añadir un 'on_attach' si lo necesitaras
            })
        end,
    },
})
