.PHONY: test test-coverage verify

test: ## Run all tests
	dart test

test-coverage: ## Run tests with coverage
	dart test --coverage=coverage

verify: format-check analyze test ## Full verification (format check + analyze + test) — mirrors CI
