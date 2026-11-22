RG ?= rg-aca-ref
LOC ?= westeurope
# Override before running: make up BUDGET_EMAIL=you@example.com SAMPLE_SECRET=...
BUDGET_EMAIL ?= alert@example.com
SAMPLE_SECRET ?= change-me-before-deploy

.PHONY: up test verify down

up:
	az group create -n $(RG) -l $(LOC)
	az policy definition create --name deny-public-ingress --mode All --rules $$(jq -c '.properties.rules' policy/deny-public-ingress.json)
	az policy definition create --name deny-insecure-transport --mode All --rules $$(jq -c '.properties.rules' policy/deny-insecure-transport.json)
	az policy definition create --name deny-plaintext-secrets --mode All --rules $$(jq -c '.properties.rules' policy/deny-plaintext-secrets.json)
	az policy definition create --name require-managed-identity --mode All --rules $$(jq -c '.properties.rules' policy/require-managed-identity.json)
	az policy definition create --name deny-latest-tag --mode All --rules $$(jq -c '.properties.rules' policy/deny-latest-tag.json)
	az policy definition create --name deny-overprivileged-role --mode All --rules $$(jq -c '.properties.rules' policy/deny-overprivileged-role.json)
	az deployment sub create -f policy/assignment.bicep
	az deployment group create -g $(RG) -f hardened/main.bicep -p location=$(LOC) sampleSecret=$(SAMPLE_SECRET) budgetEmail=$(BUDGET_EMAIL)

test:
	python3 tests/run_tests.py

verify: test
	bash scripts/verify.sh

down:
	az group delete -n $(RG) --yes --no-wait
