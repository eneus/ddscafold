# Add utility functions and scripts to the container
include scripts/makefile/*.mk

.PHONY: all fast allfast provision si exec exec0 down clean dev drush info phpcs phpcbf hooksymlink clang cinsp compval watchdogval drupalrectorval upgradestatusval behat sniffers tests front front-install front-build clear-front lintval lint storybook back behatdl behatdi browser_driver browser_driver_stop statusreportval contentgen newlineeof localize sconf
.DEFAULT_GOAL := help

# https://stackoverflow.com/a/6273809/1826109
%:
	@:

# Prepare enviroment variables from defaults
$(shell false | cp -i \.env.default \.env 2>/dev/null)
$(shell false | cp -i \.\/docker\/docker-compose\.override\.yml\.default \.\/docker\/docker-compose\.override\.yml 2>/dev/null)
include .env

# Get user/group id to manage permissions between host and containers
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)

# Evaluate recursively
CUID ?= $(LOCAL_UID)
CGID ?= $(LOCAL_GID)

# Define network name.
COMPOSE_NET_NAME := $(COMPOSE_PROJECT_NAME)_front

# Determine mysql data directory if defined
# ifeq ($(shell docker-compose config --services | grep mysql),mysql)
# 	MYSQL_DIR=$(shell cd docker $(DB_DATA_DIR))/$(COMPOSE_PROJECT_NAME)_mysql
# endif

# Define current directory only once
CURDIR=$(shell pwd)

# Execute php container as regular user
php = docker-compose exec -T --user $(CUID):$(CGID) php ${1}
# Execute php container as root user
php-0 = docker-compose exec -T --user 0:0 php ${1}

## Full site install from the scratch
all: | provision back front si hooksymlink info
# Install for CI deploy:review. Back & Front tasks are run in a dedicated previous step in order to leverage CI cache
all_ci: | provision si localize hooksymlink info
# Full site install from the scratch with DB in ram (makes data NOT persistant)
allfast: | fast provision back front si localize hooksymlink info

## Update .env to build DB in ram (makes data NOT persistant)
fast:
	$(shell sed -i "s|^#DB_URL=sqlite:///dev/shm/d8.sqlite|DB_URL=sqlite:///dev/shm/d8.sqlite|g"  .env)
	$(shell sed -i "s|^DB_URL=sqlite:./../.cache/d8.sqlite|#DB_URL=sqlite:./../.cache/d8.sqlite|g"  .env)

## Provision enviroment
provision:
# Check if enviroment variables has been defined
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
	$(info Project name can not be default, please enter project name.)
	$(eval COMPOSE_PROJECT_NAME = $(strip $(shell read -p "Project name: " REPLY;echo -n $$REPLY)))
	$(shell sed -i -e '/COMPOSE_PROJECT_NAME=/ s/=.*/=$(COMPOSE_PROJECT_NAME)/' .env)
	$(info Please review your project settings and run `make all` again.)
	exit 1
endif
ifdef MYSQL_DIR
	mkdir -p $(MYSQL_DIR) && chmod 777 $(MYSQL_DIR)
endif
	make -s down
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d --remove-orphans
	mkdir -p $(COMPOSER_HOME_CACHE)
	$(call php-0, apk add --no-cache graphicsmagick $(ADD_PHP_EXT))
	$(call php-0, kill -USR2 1)
	$(call php-0, sh -c '[ ! -z "$$COMPOSER_HOME" -a -d $$COMPOSER_HOME  ] && chown -R $(CUID):$(CGID) $$COMPOSER_HOME')
	$(call php, composer global require -o --update-no-dev --no-suggest "hirak/prestissimo:^0.3")

## Install backend dependencies
back:
	mkdir -p $(COMPOSER_HOME_CACHE)
	docker-compose up -d --remove-orphans php # PHP container is required for composer
	$(call php-0, apk add --no-cache $(ADD_PHP_EXT))
	$(call php-0, sh -c '[ ! -z "$$COMPOSER_HOME" -a -d $$COMPOSER_HOME  ] && chown -R $(CUID):$(CGID) $$COMPOSER_HOME')
	$(call php-0, kill -USR2 1)
	$(call php, composer global require -o --update-no-dev --no-suggest "hirak/prestissimo:^0.3")
ifeq ($(INSTALL_DEV_DEPENDENCIES), TRUE)
	@echo "INSTALL_DEV_DEPENDENCIES=$(INSTALL_DEV_DEPENDENCIES)"
	@echo "Installing composer dependencies, including dev ones"
	$(call php, composer install --prefer-dist -o)
else
	@echo "INSTALL_DEV_DEPENDENCIES set to FALSE or missing from .env"
	@echo "Installing composer dependencies, without dev ones"
	$(call php, composer install --prefer-dist -o --no-dev)
endif

TESTER_NAME = tester
## Install drupal
si:
	@echo "Installing from: $(PROJECT_INSTALL)"
ifeq ($(PROJECT_INSTALL), config)
	$(call php, drush site:install --existing-config --config-dir=$(PROJECT_CONFIG_DIR) --db-url=$(DB_URL) --account-name=$(ADMIN_NAME) --account-mail=$(ADMIN_MAIL) --account-pass=$(ADMIN_PW) -y)
	# install_import_translations() overwrites config translations so we need to reimport.
	$(call php, drush cim -y)
else
	$(call php, drush si $(PROFILE_NAME) --db-url=$(DB_URL) --account-name=$(ADMIN_NAME) --account-mail=$(ADMIN_MAIL) --account-pass=$(ADMIN_PW) -y --site-name="$(SITE_NAME)" --site-mail="$(SITE_MAIL)" )
endif
ifneq ($(strip $(MODULES)),)
	$(call php, drush en $(MODULES) -y)
	$(call php, drush pmu $(MODULES) -y)
	$(call php, drush user:password "$(TESTER_NAME)" "$(TESTER_PW)")
endif

sconf: 
	$(shell echo '$$settings['\''config_sync_directory'\''] = '\''$(PROJECT_CONFIG_DIR)'\'';'   >> $(CODE_BASE_DIR)/web/sites/default/settings.php) 
	
## Import online & local translations
# localize:
# 	@echo "Checking & importing online translations..."
# 	$(call php, drush locale:check)
# 	$(call php, drush locale:update)
# 	@echo "Importing custom translations..."
# 	$(call php, drush locale:import:all /var/www/html/translations/ --type=customized --override=all)
# 	@echo "Localization finished"

## Display project's information
info:
	$(info Containers for "$(COMPOSE_PROJECT_NAME)" info:)
	$(eval CONTAINERS = $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}" -f 'label=traefik.enable=true'))
	$(foreach CONTAINER, $(CONTAINERS),$(info http://$(shell printf '%-19s \n'  $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}} {{range $$p, $$conf := .NetworkSettings.Ports}}{{$$p}}{{end}} {{.Name}}' $(CONTAINER) | rev | sed "s/pct\//,pct:/g" | sed "s/,//" | rev | awk '{ print $0}')) ))
	@echo "$(RESULT)"
	@echo "System admin role - Login : \"$(ADMIN_NAME)\" - Password : \"$(ADMIN_PW)\""
	@echo "Contributor role - Login : \"$(TESTER_NAME)\" - Password : \"$(TESTER_PW)\""

## Run shell in PHP container as regular user
exec:
	docker-compose exec --user $(CUID):$(CGID) php ash

## Run shell in PHP container as root
exec0:
	docker-compose exec --user 0:0 php ash

down:
	@echo "Removing network & containers for $(COMPOSE_PROJECT_NAME)"
	@docker-compose down -v --remove-orphans --rmi local
	@if [ ! -z "$(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}')" ]; then \
		echo 'Stoping browser driver.' && make -s browser_driver_stop; fi

DIRS = $(CODE_BASE_DIR)/web/core $(CODE_BASE_DIR)/web/libraries $(CODE_BASE_DIR)/web/modules/contrib $(CODE_BASE_DIR)/web/profiles/contrib $(CODE_BASE_DIR)/web/sites $(CODE_BASE_DIR)/web/themes/contrib $(CODE_BASE_DIR)/vendor

DFIlES = $(CODE_BASE_DIR)/web/.csslintrc $(CODE_BASE_DIR)/web/.editorconfig $(CODE_BASE_DIR)/web/.eslintignore $(CODE_BASE_DIR)/web/.eslintrc.json $(CODE_BASE_DIR)/web/.gitattributes $(CODE_BASE_DIR)/web/.ht.router.php $(CODE_BASE_DIR)/web/.htaccess $(CODE_BASE_DIR)/web/index.php $(CODE_BASE_DIR)/web/robots.txt $(CODE_BASE_DIR)/web/update.php $(CODE_BASE_DIR)/web/web.config $(CODE_BASE_DIR)/web/sites/default/default.settings.php $(CODE_BASE_DIR)/web/sites/default/default.services.yml $(CODE_BASE_DIR)/web/sites/development.services.yml $(CODE_BASE_DIR)/web/sites/example.settings.local.php $(CODE_BASE_DIR)/web/sites/example.sites.php $(CODE_BASE_DIR)/web/example.gitignore $(CODE_BASE_DIR)/web/autoload.php $(CODE_BASE_DIR)/web/INSTALL.txt  $(CODE_BASE_DIR)/web/README.txt

## Totally remove project build folder, docker containers and network
clean: info
	make -s down
	# $(eval SCAFFOLD = $(shell docker run --rm -v $(CURDIR):/mnt -w /mnt --user $(CUID):$(CGID) $(IMAGE_PHP) composer run-script list-scaffold-files | grep -E '^(?!>)'))
	@docker run --rm --user 0:0 -v $(CURDIR):/mnt -w /mnt -e RMLIST="$(DFIlES) $(DIRS)" $(IMAGE_PHP) sh -c 'for i in $$RMLIST; do rm -fr $$i && echo "Removed $$i"; done'
# ifdef MYSQL_DIR
# 	@echo "Removing mysql data from $(MYSQL_DIR) ..."
# 	docker run --rm --user 0:0 -v $(shell dirname $(MYSQL_DIR)):/mnt $(IMAGE_PHP) sh -c "rm -fr /mnt/`basename $(MYSQL_DIR)`"
# endif
ifdef COMPOSER_HOME_CACHE
	@echo "Clean-up composer cache from $(COMPOSER_HOME_CACHE) ..."
	docker run --rm --user 0:0 -v $(shell dirname $(abspath $(COMPOSER_HOME_CACHE))):/mnt $(IMAGE_PHP) sh -c "rm -fr /mnt/`basename $(COMPOSER_HOME_CACHE)`"
endif
ifeq ($(CLEAR_FRONT_PACKAGES), yes)
	make clear-front
endif

## Enable development mode and disable caching
dev:
	@echo "Dev tasks..."
	$(call php, composer install --prefer-dist -o)
	@$(call php-0, chmod +w $(CODE_BASE_DIR)/web/sites/default)
	@$(call php, cp $(CODE_BASE_DIR)/web/sites/default/default.services.yml $(CODE_BASE_DIR)/web/sites/default/services.yml)
	@$(call php, sed -i -e 's/debug: false/debug: true/g' $(CODE_BASE_DIR)/web/sites/default/services.yml)
	@$(call php, cp $(CODE_BASE_DIR)/web/sites/example.settings.local.php $(CODE_BASE_DIR)/web/sites/default/settings.local.php)
	@echo "Including settings.local.php."
	@$(call php-0, sed -i "/settings.local.php';/s/# //g" $(CODE_BASE_DIR)/web/sites/default/settings.php)
	@$(call php, drush -y -q config-set system.performance css.preprocess 0)
	@$(call php, drush -y -q config-set system.performance js.preprocess 0)
	@echo "Enabling devel module."
	@$(call php, drush -y -q en devel devel_generate)
	@echo "Disabling caches."
	@$(call php, drush -y -q pm-uninstall dynamic_page_cache page_cache)
	@$(call php, drush cr)

## Run drush command in PHP container. To pass arguments use double dash: "make drush dl devel -- -y"
drush:
	$(call php, $(filter-out "$@",$(MAKECMDGOALS)))
	$(info "To pass arguments use double dash: "make drush en devel -- -y"")
