.PHONY: format format-check analyze

format: ## Format code
	dart format .

format-check: ## Check formatting without modifying files
	dart format --output=none --set-exit-if-changed .

analyze: ## Run static analysis
	dart analyze --fatal-infos --fatal-warnings
