setup:
	@sh scripts/setup.sh

dev: setup
	@bash scripts/dev.sh

verify:
	@sh scripts/verify.sh

.PHONY: setup dev verify
