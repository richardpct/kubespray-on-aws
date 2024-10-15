.DEFAULT_GOAL  := help
TERRAFORM_LOCK := .terraform.lock.hcl

.PHONY: help
help: ## Show help
	@echo "Usage: make TARGET\n"
	@echo "Targets:"
	@awk -F ":.* ##" '/^[^#].*:.*##/{printf "%-13s%s\n", $$1, $$2}' \
	$(MAKEFILE_LIST) \
	| grep -v awk

$(TERRAFORM_LOCK):
	tofu init \
		-backend-config="bucket=${TF_VAR_bucket}" \
		-backend-config="key=${TF_VAR_key_servers}" \
		-backend-config="region=${TF_VAR_region}"

.PHONY: init
init: $(TERRAFORM_LOCK) ## Init

.PHONY: apply
apply: init
apply: MY_IP = $(shell curl -s https://ifconfig.co)/32
apply: ## Create the infrastructure
	tofu apply -var="my_ip_address=$(MY_IP)"

.PHONY: plan
plan: init
plan: MY_IP = $(shell curl -s https://ifconfig.co)/32
plan: ## Dry run
	tofu plan -var="my_ip_address=$(MY_IP)"

.PHONY: destroy
destroy: ## Destroy the infrastructure
	ssh-keygen -R $$(kubectl get no control-plane-0 -o json | jq -r '.status.addresses.[0].address') || true
	ssh-keygen -R $$(kubectl get no control-plane-1 -o json | jq -r '.status.addresses.[0].address') || true
	ssh-keygen -R $$(kubectl get no control-plane-2 -o json | jq -r '.status.addresses.[0].address') || true
	ssh-keygen -R $$(kubectl get no worker-0 -o json | jq -r '.status.addresses.[0].address') || true
	ssh-keygen -R $$(kubectl get no worker-1 -o json | jq -r '.status.addresses.[0].address') || true
	ssh-keygen -R $$(kubectl get no worker-2 -o json | jq -r '.status.addresses.[0].address') || true
	tofu destroy

.PHONY: clean
clean: ## Clean
	rm -rfv .terraform*
