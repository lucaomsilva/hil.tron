# === HIL Connection Configuration ===
SHELL := /bin/bash

# === Colors ===
GREEN  := \033[32m
BLUE   := \033[34m
YELLOW := \033[33m
RED    := \033[31m
NC     := \033[0m

.SILENT:

##@ General

.PHONY: help
help: ## Display this help message
	@echo -e "$(BLUE)HIL Connection Makefile$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9\/-]+:.*?##/ { printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Build & Run

.PHONY: build
build: env install run ## Setup environment, install dependencies, and run

.PHONY: env
env: ## Create a Python virtual environment if it doesn't exist
	@if [ ! -d ".venv" ]; then \
		echo -e "$(BLUE)>> Creating Python virtual environment...$(NC)"; \
		python3 -m venv .venv; \
		echo -e "$(GREEN)>> Virtual environment created.$(NC)"; \
	else \
		echo -e "$(YELLOW)>> Virtual environment already exists.$(NC)"; \
	fi

.PHONY: install
install: ## Install dependencies statically from requirements.txt
	@echo -e "$(BLUE)>> Checking dependencies...$(NC)"
	@.venv/bin/pip install -r requirements.txt | grep -v 'Requirement already satisfied' || true
	@echo -e "$(GREEN)>> Dependencies installed/verified.$(NC)"

.PHONY: run
run: ## Execute the application
	@echo -e "$(BLUE)>> Running the HIL connection software...$(NC)"
	@.venv/bin/python src/main.py

##@ Clean

.PHONY: clean
clean: ## Remove virtual environment and temporary files
	@echo -e "$(YELLOW)>> Cleaning HIL connection files...$(NC)"
	@rm -rf .venv
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@echo -e "$(GREEN)>> Clean complete.$(NC)"
