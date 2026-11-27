setup:
	@echo "Definido na T-02." >&2; exit 1

dev:
	@echo "Definido na T-02." >&2; exit 1

verify:
	@sh scripts/verify.sh

.PHONY: setup dev verify
