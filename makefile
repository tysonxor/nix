.DEFAULT_GOAL := help
REPO := $(HOME)/nix
TEMPLATE := $(REPO)/lima/guest.yaml
SCRIPT_URL := https://raw.githubusercontent.com/tysonxor/nix/main/guests/bootstrap-guest.sh

help:  ## list commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

vm-create:  ## create + bootstrap a guest:  make vm-create NAME=clientx
	limactl start --name=$(NAME) $(TEMPLATE) --tty=false
	limactl shell $(NAME) bash -c 'curl -fsSL $(SCRIPT_URL) | bash -s -- $(NAME)'

vm-destroy:  ## destroy a guest:  make vm-destroy NAME=clientx
	limactl stop $(NAME) && limactl delete $(NAME)

shell:  ## shell into a guest:  make shell NAME=clientx
	limactl shell $(NAME)

rebuild:  ## rebuild Mac host:
	sudo darwin-rebuild switch --flake $(REPO)#machost
