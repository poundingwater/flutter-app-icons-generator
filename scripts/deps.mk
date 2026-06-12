.PHONY: get outdated upgrade

get: ## Install dependencies
	dart pub get

outdated: ## Check for outdated dependencies
	dart pub outdated

upgrade: ## Upgrade dependencies
	dart pub upgrade
