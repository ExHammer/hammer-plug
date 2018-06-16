# Hammer makefile

default: format test docs


format:
	mix format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"


test: format
	mix test --no-start


docs:
	mix docs


.PHONY: format test docs
