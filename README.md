# patamu-purchases Db Backup Docker Image

This is the **Docker** image of the tiny Laravel app that is used to do database backups of patamu-purchases' database.

## **Preliminary tasks**

### Create base image repositories

> **Attention**: ***these image repositories could be already created from previous projects using them; if that's the case, ignore this task.***

Our **php**'s **Docker** image requires some resources to be able to build itself. That involves the following images:

- `git`: download the `patamu-purchase` source code.
- `composer`: install the packages required by the project.
- `php`: the official image base that builds **php**.

Using an `aws-cli` project terminal, create an image repository for each one of them on our private registry.

> **Note 1**: the suffix part (all that comes after `innovaetica-base/`) matches an image on the **AWS ECR Public Gallery**.
>
> **Note 2**: keep in mind that those are generic images that can be reused on any project we work on. That's why we'll prefix those images in our private registry with `innovaetica-base/`.

```bash
aws ecr create-repository --profile lluisaznar --repository-name innovaetica-base/docker/library/php
aws ecr create-repository --profile lluisaznar --repository-name innovaetica-base/bitnami/git
aws ecr create-repository --profile lluisaznar --repository-name innovaetica-base/docker/library/composer
```

### Create our Docker image repository

Our **php**'s **Docker** image also requires creating a repository on our **Private ECR Registry**.

```bash
aws ecr create-repository --profile lluisaznar --repository-name patamu-purchases-db-backup-php
```

### Create a *pull through cache* rule

It allows us to *cache* images from public repositories sources, like **AWS ECR Public Gallery**, into our **Private ECR Registry**. Once an image is cached, it'll always be pulled from there.

```bash
aws ecr create-pull-through-cache-rule --profile lluisaznar --ecr-repository-prefix innovaetica-base --upstream-registry-url public.ecr.aws
```

### Personal Access Token for Composer

The **Docker** image requires a secret that stores a **Personal Access Token** from **GitHub**. This is required because the **Laravel** app uses a private package `adrienlibre/db-backup`. **Composer** requires this **PAT** to be able to install it.

On **GitHub** site, access the **Developer Settings** section (our user has to be added as a collaborator of the `adrienlibre/db-backup` project); create a **Personal Access Token**.

Create a file `files/secrets/github-personal-access-token` with just the **PAT** as its content.

## **Generate our patamu-purchases-db-backup-php image**

### Build

Build the **php**'s **Docker** image that will be pushed to the **Private ECR Registry**.

> Note 1: execute the command through the `patamu-purchases--php-fpm--docker-image` project terminal.
>
> Note 2: the ***image/tag*** name will be the same both on local and on **Private ECR Registry**. This way the ***docker push*** will be straightforward: the local ***image/tag*** will be pushed to the same ***image/tag*** at the private registry.

```bash
docker build \
--build-arg GIT_REPO_NAME=<GIT_REPO_NAME> \
--build-arg GIT_REPO_TAG=<GIT_REPO_TAG> \
--build-arg GIT_REPO_OWNER=<GIT_REPO_OWNER> \
--build-arg PHP_EXPOSED_PORT=<PHP_EXPOSED_PORT> \
--build-arg TAG_COMPOSER=<TAG_COMPOSER> \
--build-arg TAG_GIT=<TAG_GIT> \
--build-arg TAG_PHP=<TAG_PHP> \
--secret id=github-personal-access-token,src=./files/secrets/github-personal-access-token \
--secret id=environment-file,src=./files/secrets/env.<ENVIRONMENT> \
--tag 280785378630.dkr.ecr.eu-central-1.amazonaws.com/patamu-purchases-db-backup-php:<ENVIRONMENT>-<IMAGE_TAG>-r<REVISION_NUMBER> \
--no-cache .
```

Command build arguments:

- `GIT_REPO_NAME`: repository on **GitHub** with the project source code.
- `GIT_REPO_TAG`: tag on the repository whose code will be added to the **docker** image.
- `GIT_REPO_OWNER`: owner of the repository.
- `TAG_COMPOSER`: tag of the official **composer** image used to obtain the *composer* executable.
- `TAG_GIT`: tag of the bitnami **git** image that will be used by **composer** to download package **db-backup**.
- `TAG_PHP`: tag of the innovaetica **php** image that will be used as a base at this `php-fpm` image.

Replacements on command options (`tag`, `secret`):

- `ENVIRONMENT`: can be `local` (development on *local*), `development` (development on *aws*) or `production` (live on *aws*).
- `IMAGE_TAG`: the name that will identify the image at hand. ***For integrity purpouses, its value must be the same as*** `GIT_REPO_TAG`.
- `REVISION_NUMBER`: image **revision number**. Useful when there are changes that doesn't involve changes on the source code. For example an update on some variable on the `.env` file; to reflect those software changes, a new image generation over the same `tag` has to be created. Creating it incrementing the `REVISION_NUMBER` would be enough.

Any change of software requires a generation of a new image. Those changes comprises:

- Base images (git, php, composer).
    > Note: could be solved incrementing the `REVISION_NUMBER`.
- Change on an `.env` file.
    > Note: could be solved incrementing the `REVISION_NUMBER`.
- **Dockerfile** instructions.
    > Note: could be solved incrementing the `REVISION_NUMBER`.
- Source code on **git** repository `adrienlibre/patamu-purchases--db-backup`.
    > Note: it requires a new `IMAGE_TAG` generation matching the `GIT_REPO_TAG` (and restarting the `REVISION_NUMBER` to 0).

Here's a build command example:

```bash
docker build \
--build-arg GIT_REPO_NAME=patamu-purchases \
--build-arg GIT_REPO_TAG=202502121526 \
--build-arg GIT_REPO_OWNER=adrienlibre \
--build-arg TAG_COMPOSER=2.8.5 \
--build-arg TAG_GIT=2.48.1-debian-12-r4 \
--build-arg TAG_PHP=8.4.3-fpm-bookworm--r0 \
--secret id=github-personal-access-token,src=./files/secrets/github-personal-access-token \
--secret id=environment-file,src=./files/secrets/env.local \
--tag 280785378630.dkr.ecr.eu-central-1.amazonaws.com/patamu-purchases-db-backup-php:local-202502121526-r0 \
--no-cache .
```

### Push

Push the **php** image to the **Private ECR Registry**'s repository `patamu-purchases-db-backup-php`.

> Note: no matter which terminal is used, this command uses local **Docker** service.

```bash
docker push 280785378630.dkr.ecr.eu-central-1.amazonaws.com/patamu-purchases-db-backup-php:<IMAGE_TAG>
```

### Document the tag changes on UPGRADES.md

It's important to keep track of the evolution of the project. Everytime a new version is released, we should document the related tag and the changes it involves on the file `UPGRADES.md`.

## **Hints**

### Using Private ECR Registry instead of Docker Hub

It's worth noting that it's not a requirement that all images referenced on the **Dockerfile** exist at our **Private ECR registry**. The built image will reside there with all its related layers (they have everything that belongs to the image; multi-stage images included). That means that an image that has these instructions:

```dockerfile
FROM bitnami/git:$TAG_GIT AS repository
FROM composer:$TAG_COMPOSER AS composer-stage
FROM php:$TAG_PHP
```

Should work once its built and pushed to the **Private ECR Registry**. But we prefer an alternate approach: using *pull through cache* technique. The previous instructions would be:

```dockerfile
FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-base/bitnami/git:$TAG_GIT AS repository
FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-base/docker/library/composer:$TAG_COMPOSER AS composer-stage
FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-base/docker/library/php:$TAG_PHP
```

These images are stored on our **Private ECR Registry**. We've defined a *pull through cache* rule on all those repositories prefixed with `innovaetica-base`. When a requested image matches this rule, the system pulls the repository from the **AWS ECR Public Gallery** and caches it onto our **Private ECR Registry**. From now on, when those images are again requested, they'll be served directly from there. That's the case for `bitnami/git`, `docker/library/composer`, `docker/library/php`.

Using **AWS ECR Public Gallery** instead of **Docker Hub** for pulling images has a clear advantage. The latter has limitations on image download and pulling ([**reference**](https://docs.docker.com/docker-hub/download-rate-limit/)).

### Using Private ECR Registry for local development

If our local **Docker** service is logged in our **Private ECR Registry**, the used images will work also in local development, meaning that, for example, the instruction `FROM 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-base/docker/library/php:$TAG_PHP` will pull the image from there.

If we can't make local **Docker** service work with our **Private ECR registry** because of credentials issues, execute one of the following commands (it'll login the service on the private registry):

```bash
aws ecr get-login-password --profile lluisaznar --region eu-central-1 | docker login --username AWS --password-stdin 280785378630.dkr.ecr.eu-central-1.amazonaws.com/innovaetica-php
```

### Environment Template Variables Syntax

The `.env` file is generated from template files located in `files/templates/laravel/env/`. These templates use a special syntax to define environment variables with optional defaults and validation.

**Syntax rules:**

- **Variable with default value**: `KEY_NAME=<VARIABLE_NAME>,default_value`
  
  Example: `APP_DEBUG=<APP_DEBUG>,true`
  
  If `APP_DEBUG` is not provided in the environment file, it will be set to `true` in the generated `.env`.

- **Optional variable with empty default**: `KEY_NAME=<VARIABLE_NAME>,`
  
  Example: `AWS_ACCESS_KEY=<AWS_ACCESS_KEY>,`
  
  If `AWS_ACCESS_KEY` is not provided, it will be added as `AWS_ACCESS_KEY=` (empty string) in the generated `.env`.

- **Required variable (no default)**: `KEY_NAME=<VARIABLE_NAME>`
  
  Example: `APP_NAME=<APP_NAME>`
  
  If `APP_NAME` is not provided in the environment file, the **build will fail** with an error indicating which variable is missing.

**The comma is the key differentiator:**

- **Comma present**: Variable is optional (uses default or empty)
- **No comma**: Variable is required (build fails if missing)

This validation happens during the Docker image build when the `generate_env_file` function (defined in `libfs.sh`) processes the templates.
