.DEFAULT_GOAL := help

REPO := $(HOME)/nix
TEMPLATE := $(REPO)/lima/guest.yaml

help:  ## list commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

vm-create:  ## create + bootstrap a guest:  make vm-create NAME=clientx
	limactl start --name=$(NAME) $(TEMPLATE) --tty=false
	limactl shell $(NAME) -- bash $(REPO)/bootstrap-guest.sh $(NAME)

vm-destroy:  ## destroy a guest:  make vm-down NAME=clientx
	limactl stop $(NAME) && limactl delete $(NAME)

shell:  ## shell into a guest:  make shell NAME=clientx
	limactl shell $(NAME)

rebuild:  ## rebuild the Mac host config
	sudo darwin-rebuild switch --flake $(REPO)#machost
