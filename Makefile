# Makefile for JholaXL Development

# Include command modules
include scripts/*.mk

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "Available targets:"
	@echo ""
	@for mkFile in Makefile scripts/*.mk; do \
		if [ -f "$$mkFile" ]; then \
			echo "From $$mkFile:"; \
			grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' "$$mkFile" | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'; \
			echo ""; \
		fi \
	done
