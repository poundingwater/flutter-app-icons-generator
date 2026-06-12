.PHONY: clean build generate publish publish-dry-run

clean: ## Remove build artifacts
	rm -rf build/ .dart_tool/

build: ## Build the package executable
	dart compile exe bin/flutter_app_icons_generator.dart -o build/flutter_app_icons_generator

generate: ## Run build_runner code generation
	dart run build_runner build --delete-conflicting-outputs

publish-dry-run: ## Dry-run publish to pub.dev (validates without uploading)
	dart pub publish --dry-run

publish: ## Publish package to pub.dev
	dart pub publish
