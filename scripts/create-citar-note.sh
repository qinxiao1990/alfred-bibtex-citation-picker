#!/bin/zsh
# Create (or open) a citar note for the selected citekey via Emacs `citar-create-note`.
# Requires a running Emacs server (`M-x server-start`, or `(server-start)` in init.el).
# shellcheck disable=2154

export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Emacs.app/Contents/MacOS/bin:$PATH"
citekey="$*"
emacsclient="${emacsclient_path:-emacsclient}"
emacsclient="${emacsclient/#\~/$HOME}"

if ! command -v "$emacsclient" &>/dev/null; then
	echo "⚠️ emacsclient not found. Set its path in the workflow configuration."
	return 1
fi

# escape backslashes & quotes for the elisp string
key_escaped=${citekey//\\/\\\\}
key_escaped=${key_escaped//\"/\\\"}

ec() { "$emacsclient" "$@" 2>&1; }

# Bring Emacs to the front *before* creating the note, so citar's prompts
# (template/note selection) are visible. Derive the .app bundle from the
# server's PID, so this works for Emacs.app, Emacs Plus, emacs-mac, etc.
if ! pid=$(ec --eval '(emacs-pid)'); then
	echo "⚠️ Emacs server not reachable: ${pid:0:100}"
	return 1
fi
# if Emacs runs as a daemon without a GUI frame, create one
if [[ $(ec --eval '(length (seq-filter (lambda (f) (display-graphic-p f)) (frame-list)))') == 0 ]]; then
	ec --create-frame --no-wait &>/dev/null
fi
app_path=$(ps -o comm= -p "$pid" | sed -E 's|(\.app)/.*|\1|')
activate_emacs() {
	if [[ "$app_path" == *.app ]]; then open "$app_path"; else open -a Emacs 2>/dev/null; fi
	# fallback: macOS sometimes ignores `open` for an already-running app
	# launched from the background (needs one-time Automation permission)
	osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" &>/dev/null
}
activate_emacs

if ! output=$(ec --no-wait --eval "(progn (let ((f (car (seq-filter #'display-graphic-p (frame-list))))) (when f (select-frame-set-input-focus f))) (require 'citar) (citar-create-note \"$key_escaped\") t)"); then
	echo "⚠️ Emacs: ${output:0:120}"
	return 1
fi

# citar may switch buffers/frames; make sure Emacs is still in front
sleep 0.2
activate_emacs
