#!/usr/bin/zsh
source functions
setopt EXTENDED_GLOB

local sourceFile=""
local targetFile=""

for sourceFile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
	targetFile="${ZDOTDIR:-$HOME}/.${sourceFile:t}"

	if [ -e "$targetFile" ]; then # target already exists
		if [ "$(readlink "$targetFile")" != "$sourceFile" ]; then # and is not same as new

			ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
			if answer_is_yes; then
				execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile" # overwrite
			else
				print_error "$targetFile → $sourceFile"
			fi
		else
			print_success "$targetFile → $sourceFile"
		fi
	else
		execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
	fi
done
