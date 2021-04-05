.ONESHELL:

SHELL := /bin/bash

.SILENT .PHONY: run
run:
	cd src/httpipe
	./httpipe.sh