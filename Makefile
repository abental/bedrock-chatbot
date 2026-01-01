# Makefile for Bedrock Knowledge Base Chatbot

.PHONY: help build up down logs restart shell test clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Docker image
	cd src && docker-compose -f ../docker-compose.yaml build

up: ## Start containers
	cd src && docker-compose -f ../docker-compose.yaml up -d

down: ## Stop and remove containers
	cd src && docker-compose -f ../docker-compose.yaml down

logs: ## View logs
	cd src && docker-compose -f ../docker-compose.yaml logs -f

restart: ## Restart containers
	cd src && docker-compose -f ../docker-compose.yaml restart

shell: ## Open shell in container
	cd src && docker-compose -f ../docker-compose.yaml exec bedrock-chatbot bash

test: ## Run tests
	cd src && docker-compose -f ../docker-compose.yaml run --rm bedrock-chatbot python -m pytest

clean: ## Remove containers, volumes, and images
	cd src && docker-compose -f ../docker-compose.yaml down -v --rmi local

rebuild: ## Rebuild and restart
	cd src && docker-compose -f ../docker-compose.yaml up -d --build

status: ## Show container status
	cd src && docker-compose -f ../docker-compose.yaml ps

health: ## Check health endpoint
	curl http://localhost:5000/api/health

config: ## Show docker-compose configuration
	cd src && docker-compose -f ../docker-compose.yaml config

