setup:
	@echo "Definido na T-02." >&2; exit 1

dev:
	@echo "Definido na T-02." >&2; exit 1

verify:
	@sh scripts/verificar.sh

.PHONY: setup dev verify
