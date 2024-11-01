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
		-backend-config="bucket_certificate=${TF_VAR_bucket}" \
		-backend-config="key_certificate=${TF_VAR_key_kubernetes}" \
		-backend-config="region=${TF_VAR_region}"

.PHONY: init
init: $(TERRAFORM_LOCK) ## Init

.PHONY: apply
apply: init ## Create the infrastructure
	tofu apply

.PHONY: plan
plan: init ## Dry run
	tofu plan

.PHONY: destroy
destroy: ## Destroy the infrastructure
	kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag || true
	tofu destroy

.PHONY: clean
clean: ## Clean
	rm -rfv .terraform*
