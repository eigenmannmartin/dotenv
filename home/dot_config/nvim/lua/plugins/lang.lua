-- LazyVim language extras for this stack. Each import pulls the right
-- LSP / treesitter / formatter / linter (Mason auto-installs them on first
-- launch; lazy-lock.json pins the plugin revisions). Catppuccin themes all of it.
return {
  { import = "lazyvim.plugins.extras.lang.go" }, -- gopls, delve, gofumpt, golangci-lint
  { import = "lazyvim.plugins.extras.lang.python" }, -- pyright + ruff, debugpy
  { import = "lazyvim.plugins.extras.lang.docker" }, -- dockerfile-ls, hadolint
  { import = "lazyvim.plugins.extras.lang.yaml" }, -- yaml-ls + SchemaStore (k8s schemas)
  { import = "lazyvim.plugins.extras.lang.helm" }, -- helm_ls
  { import = "lazyvim.plugins.extras.lang.dart" }, -- dartls + dart_format
  { import = "lazyvim.plugins.extras.dap.core" }, -- nvim-dap + dap-ui (debugger)
}
