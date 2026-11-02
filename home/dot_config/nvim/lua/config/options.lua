-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Clipboard on headless Linux (Lima VM, container, any plain `ssh` box).
--
-- There is no pasteboard and no X11/Wayland there, so nvim has no clipboard
-- provider and yanks go nowhere. OSC 52 fixes it: nvim writes an escape
-- sequence down the existing pty and the terminal on YOUR machine puts the
-- text on ITS clipboard. Inside tmux this repo's `set-clipboard on` forwards
-- that escape to the outer terminal.
--
-- Why set it explicitly instead of relying on nvim's auto-detection: nvim only
-- turns OSC 52 on if the TERMINAL ANSWERS an XTGETTCAP query for the `Ms`
-- capability (runtime/plugin/osc52.lua, 1s timeout), and even then only while
-- `&clipboard` is empty (provider/clipboard.vim:260). We want `unnamedplus`
-- below, which kills the second condition outright, so the explicit
-- `g:clipboard` is not optional here — do not delete it.
--
-- Gated to Linux with no display server so macOS keeps pbcopy and Linux
-- desktops keep their native provider, which is strictly better (and supports
-- paste, which OSC 52 effectively does not — see below). Deliberately NOT gated
-- on $SSH_TTY/$SSH_CONNECTION: those are missing whenever the shell did not come
-- from sshd (docker exec, a devcontainer), and there yanks silently went nowhere.
local function linux_headless()
  local function blank(v)
    return v == nil or v == ""
  end
  return vim.fn.has("linux") == 1 and blank(vim.env.DISPLAY) and blank(vim.env.WAYLAND_DISPLAY)
end

if linux_headless() then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    -- Paste deliberately does NOT use OSC 52: reading the clipboard needs the
    -- terminal to answer, and kitty prompts for permission on every single read
    -- by default (`read-clipboard-ask`). Returning the unnamed register instead
    -- makes `"+p` behave like `p` — yank-then-paste within nvim still works, and
    -- pasting FROM the Mac is what Cmd+V is for.
    local function paste_reg()
      return function()
        -- The DOCUMENTED shape is a single `{ lines, regtype }` list (:h provider).
        -- Returning two values silently drops the regtype — a Lua funcref yields
        -- only its first value to Vimscript — and then a charwise register whose
        -- text ends in "\n" comes back linewise. nvim rejects the `^V<width>`
        -- blockwise spelling from a provider, so send a bare `^V` and let it
        -- recompute the width.
        local regtype = vim.fn.getregtype("")
        if regtype:sub(1, 1) == "\022" then
          regtype = "\022"
        end
        return { vim.fn.getreg("", 1, true), regtype }
      end
    end

    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste_reg(), ["*"] = paste_reg() },
    }

    -- LazyVim sets `clipboard = ""` whenever $SSH_CONNECTION is set, so that
    -- nvim's own auto-detection can engage. We pinned the provider above, and an
    -- empty `clipboard` means a plain `yy` never touches the "+ register, so
    -- nothing is ever sent — only an explicit `"+y` works. Turn it back on (the
    -- macOS branch below does the same). The `&clipboard == ""` guard in
    -- provider/clipboard.vim only guards the auto-detect branch, so the explicit
    -- g:clipboard still wins.
    vim.o.clipboard = "unnamedplus"
  end
elseif vim.fn.has("mac") == 1 then
  -- The same LazyVim rule bites on macOS: with $SSH_CONNECTION set (an ssh session
  -- into the Mac, or a tmux pane that kept it from a client that attached over ssh)
  -- a plain `yy` would skip the "+ register and copy nowhere. Keep `y` on nvim's
  -- macOS provider (pbcopy), where the mouse-release copy in keymaps.lua goes too.
  vim.o.clipboard = "unnamedplus"
end
