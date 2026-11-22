RG ?= rg-aca-ref
LOC ?= westeurope
# Override before running: make up BUDGET_EMAIL=you@example.com
BUDGET_EMAIL ?= alert@example.com
EXTERNAL_INGRESS ?= false
SUB ?= $$(az account show --query id -o tsv)

.PHONY: up verify down

up:
	az group create -n $(RG) -l $(LOC)
	az policy definition create --name deny-public-ingress --display-name "Deny public Container Apps ingress" --mode All --rules $$(jq -c '.properties.rules' policy/deny-public-ingress.json)
	az policy definition create --name require-managed-identity --display-name "Require user-assigned managed identity on Container Apps" --mode All --rules $$(jq -c '.properties.rules' policy/require-managed-identity.json)
	az policy definition create --name deny-latest-tag --display-name "Deny :latest image tag on Container Apps" --mode All --rules $$(jq -c '.properties.rules' policy/deny-latest-tag.json)
	az policy assignment create --name deny-public-ingress --policy-set-definition /subscriptions/$(SUB)/providers/Microsoft.Authorization/policyDefinitions/deny-public-ingress --scope /subscriptions/$(SUB) --enforcement-mode Default
	az policy assignment create --name require-managed-identity --policy-set-definition /subscriptions/$(SUB)/providers/Microsoft.Authorization/policyDefinitions/require-managed-identity --scope /subscriptions/$(SUB) --enforcement-mode Default
	az policy assignment create --name deny-latest-tag --policy-set-definition /subscriptions/$(SUB)/providers/Microsoft.Authorization/policyDefinitions/deny-latest-tag --scope /subscriptions/$(SUB) --enforcement-mode Default
	az deployment group create -g $(RG) -f bicep/main.bicep -p location=$(LOC) externalIngress=$(EXTERNAL_INGRESS) budgetEmail=$(BUDGET_EMAIL)

verify:
	bash scripts/verify.sh

down:
	az group delete -n $(RG) --yes --no-wait
