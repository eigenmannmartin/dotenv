-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Clipboard on a headless remote (Lima VM, container, any plain `ssh` box).
--
-- There is no pasteboard and no X11/Wayland there, so nvim has no clipboard
-- provider and yanks go nowhere. OSC 52 fixes it: nvim writes an escape
-- sequence down the existing pty and the terminal on YOUR machine puts the
-- text on ITS clipboard. Inside tmux this repo's `set-clipboard on` forwards
-- that escape to the outer terminal.
--
-- Why set it explicitly instead of relying on nvim's auto-detection: nvim only
-- auto-selects OSC 52 when `&clipboard` is empty, and LazyVim sets
-- `clipboard = "unnamedplus"` — so the automatic path never engages here.
--
-- Gated to remote+headless so macOS and Linux desktops keep their native
-- pasteboard, which is strictly better (and supports paste, which OSC 52
-- effectively does not — see below).
local function remote_headless()
  local function blank(v)
    return v == nil or v == ""
  end
  return (not blank(vim.env.SSH_TTY) or not blank(vim.env.SSH_CONNECTION))
    and blank(vim.env.DISPLAY)
    and blank(vim.env.WAYLAND_DISPLAY)
end

if remote_headless() then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    -- Paste deliberately does NOT use OSC 52: reading the clipboard needs the
    -- terminal to answer, and kitty prompts for permission on every single read
    -- by default (`read-clipboard-ask`). Returning the unnamed register instead
    -- makes `"+p` behave like `p` — yank-then-paste within nvim still works, and
    -- pasting FROM the Mac is what Cmd+V is for.
    local function paste_reg()
      return function()
        return vim.split(vim.fn.getreg("") or "", "\n"), vim.fn.getregtype("")
      end
    end

    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste_reg(), ["*"] = paste_reg() },
    }
  end
end
