RG ?= rg-aca-ref
LOC ?= eastus
# Override before running: make up BUDGET_EMAIL=you@example.com SAMPLE_SECRET=...
BUDGET_EMAIL ?= alert@example.com
SAMPLE_SECRET ?= change-me-before-deploy

.PHONY: up test verify down

up:
	az group create -n $(RG) -l $(LOC)
	az deployment group create -g $(RG) -f policy/deny-public-ingress.json -p @policy/params.json
	az deployment group create -g $(RG) -f policy/deny-literal-secrets.json -p @policy/params.json
	az deployment group create -g $(RG) -f hardened/main.bicep -p location=$(LOC) sampleSecret=$(SAMPLE_SECRET) budgetEmail=$(BUDGET_EMAIL)

test:
	bash tests/run-policy-tests.sh

verify:
	bash scripts/verify.sh

down:
	az group delete -n $(RG) --yes --no-wait
