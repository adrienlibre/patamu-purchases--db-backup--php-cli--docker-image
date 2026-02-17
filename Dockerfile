#####################################
# build arguments
#####################################
ARG TAG_COMPOSER=latest
ARG TAG_GIT=latest
ARG TAG_PHP=latest

#####################################
# [MULTI-STAGE] composer
#####################################
FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-base/docker/library/composer:$TAG_COMPOSER AS composer-stage

#####################################
# [MULTI-STAGE] laravel app source
#####################################
FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-base/bitnami/git:$TAG_GIT AS repository
# those git arguments should be placed here. ARGs placed as first things in a Dockerfile, are not available after any FROM instruction
# https://stackoverflow.com/questions/44438637/arg-substitution-in-run-command-not-working-for-dockerfile
# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG GIT_REPO_NAME
ARG GIT_REPO_TAG
ARG GIT_REPO_OWNER
WORKDIR /var/www/html
RUN --mount=type=secret,id=github-personal-access-token,required \
    git clone --depth=1 --branch=$GIT_REPO_TAG https://${GIT_REPO_OWNER}:$(cat /run/secrets/github-personal-access-token)@github.com/$GIT_REPO_OWNER/$GIT_REPO_NAME.git; \
    find ./$GIT_REPO_NAME -mindepth 1 -maxdepth 1 ! -name '.git*' -exec mv {} . \;; \
    rm -rf ./$GIT_REPO_NAME

# ******************
# *** IMAGE BASE ***
# ******************
FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-php-cli:$TAG_PHP

#####################################
# variables
#####################################

# base location of installation
ENV BASE_DIR=/usr/local/etc

#####################################
# copies
#####################################

# copy the bash helper scripts
COPY files/lib /patamu/lib

# copy the templates (used to generate Laravel app's env file)
COPY files/templates /patamu/templates

# copy our php configuration file, used to customize php directives
COPY --chmod=644 files/configuration/php-custom-directives.ini "$PHP_INI_DIR/conf.d/zz-docker-php-custom-directives.ini"

# copying customized docker entrypoint
COPY --chmod=775 files/entrypoint /usr/local/bin/docker-php-entrypoint

# copying supervisor worker's configuration file
COPY --chmod=644 files/supervisor/worker-database.conf /etc/supervisor/conf.d/worker-database.conf

# copy composer program from composer stage
# note: interpolation doesn't work directly on a 'COPY --from' instruction. An auxiliar composer-stage is used to copy the composer program
COPY --chown=www-data:www-data --from=composer-stage /usr/bin/composer /usr/bin/composer

# copy laravel app source code from repository to base stage
# ATTENTION: when using a volume (like the EFS used on this project), take into account that it will not be mounted until the container
# is running. That's why files can't be copied directly to the path that is going to be mounted as a volume. Copy those files to a different
# path, and then move them to the volume path at the entrypoint stage (when the container is up and running).
COPY --chown=www-data:www-data --from=repository /var/www/html /source/

#####################################
# commands
#####################################

# change shell to bash to be able to use the bash helper scripts used to generate the Laravel app's env file
SHELL ["/bin/bash", "-c"]

RUN --mount=type=secret,id=github-personal-access-token,required \
    --mount=type=secret,id=environment-file,required \
    \
    set -eux; \
    \
    # ------ install system dependencies ------
    \
	apt-get update; \
	apt-get install -y --no-install-recommends \
        # provides the mysqldump binary, used by the backup command
        default-mysql-client; \
    \
    rm -rf /var/lib/apt/lists/*; \
    \
    # allow composer accessing GitHub private repositories (https://getcomposer.org/doc/articles/authentication-for-private-packages.md#command-line-github-oauth)
    { \
        echo "{"; \
        echo "    \"github-oauth\": {"; \
        echo "        \"github.com\": \"$(cat /run/secrets/github-personal-access-token)\""; \
        echo "    }"; \
        echo "}"; \
    } >> /home/www-data/.composer/auth.json; \
    \
    # change owner of the file auth.json to www-data
    chown www-data:www-data /home/www-data/.composer/auth.json; \
    \
    # cd into the folder where the source code is located
    cd /source; \
    # clean laravel app files not required for production
    find . -name ".gitignore" -type f -delete; \
    rm -rf .env.example .eslintrc.js .gitattributes database/factories database/seeders node_modules package* phpunit.xml postcss.config.cjs README.md tailwind.config.cjs tests UPGRADES.md vite.config.js; \
    \
    # ------ generate .env file ------
    \
    # include helper bash scripts
    . /patamu/lib/libfs.sh; \
    # generate Laravel app's .env file
    generate_env_file; \
    # remove unnecessary files from directory /patamu
    rm -rf /patamu/templates; \
    \
    # ------ install php dependencies ------
    \
    # note 1: also install dev ones. Database seeders need fakerphp/faker (once the db is initialized, all dev dependencies will be removed)
    sudo -u www-data composer install --no-cache --no-interaction --no-progress --prefer-dist; \
    # remove the composer auth.json (all libraries are in place, it's no longer needed)
    sudo -u www-data rm -f /home/www-data/.composer/auth.json; \
    # generate a new laravel app key
    sudo -u www-data php artisan key:generate; \
    # remove the dev libraries
    # note: all except fakerphp/faker, which is required by laravel app to seed the database at initialization stage
    sudo -u www-data composer remove --dev \
        fakerphp/faker \
        laravel/pail \
        laravel/pint \
        laravel/sail \
        mockery/mockery \
        nunomaduro/collision \
        phpunit/phpunit; \
    \
    # optimize the composer autoloader
    sudo -u www-data composer dump-autoload --optimize; \
    # cd back into /opt/innovaetica-cli-app
    cd -; \
    # remove packages just used for the build process (they are installed through the base image)
    apt-get -y remove ssh git

# change user to www-data
# note: we do it for security reasons, to avoid running the containerized web app as root
USER www-data

# Override base image's CMD to pass no arguments
# This allows the entrypoint to use the ARTISAN_COMMAND environment variable
# instead of inheriting the base image's CMD (likely "php -a")
CMD []
