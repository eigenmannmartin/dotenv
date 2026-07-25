# dotenv: TERM safety net — sourced from ~/.zshrc and ~/.bashrc.
#
# If $TERM has no terminfo entry on this machine, tmux does not degrade — it
# refuses to start outright ("missing or unsuitable terminal: xterm-kitty"),
# which in turn silently blocks tpm plugin installation. Curses apps misbehave
# too, and nothing can advertise the OSC 52 `Ms` capability, so copying to the
# system clipboard over SSH stops working.
#
# Installing the real terminfo is the actual fix (see the 25-terminfo chezmoi
# script); this only stops a missing entry from being fatal. Typical trigger:
# ssh'ing from kitty (TERM=xterm-kitty) into a box that has never seen kitty.
if [ -n "${TERM:-}" ] && [ "${TERM}" != "dumb" ] \
   && ! tput -T "${TERM}" longname >/dev/null 2>&1; then
  # Exported so the downgrade is discoverable rather than mysterious.
  DOTENV_ORIG_TERM="${TERM}"
  export DOTENV_ORIG_TERM
  export TERM=xterm-256color
fi
