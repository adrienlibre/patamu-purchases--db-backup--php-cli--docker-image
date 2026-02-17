# patamu-purchases Db Backup Docker Image

This is the **Docker** image of the tiny Laravel app that is used to do database backups of patamu-purchases' database.

## Table of Contents

- [patamu-purchases Db Backup Docker Image](#patamu-purchases-db-backup-docker-image)
  - [Table of Contents](#table-of-contents)
  - [Preliminary tasks](#preliminary-tasks)
    - [Create base image repositories](#create-base-image-repositories)
    - [Create our Docker image repository](#create-our-docker-image-repository)
    - [Create a *pull through cache* rule](#create-a-pull-through-cache-rule)
    - [Personal Access Token for Composer](#personal-access-token-for-composer)
  - [Generate our patamu-purchases-db-backup-php image](#generate-our-patamu-purchases-db-backup-php-image)
    - [Build](#build)
    - [Push](#push)
    - [Document the tag changes on UPGRADES.md](#document-the-tag-changes-on-upgradesmd)
  - [Deploy ECS Service for Database Backup](#deploy-ecs-service-for-database-backup)
    - [Step 1: Create Task Execution Role](#step-1-create-task-execution-role)
      - [1.1. Create the trust policy file](#11-create-the-trust-policy-file)
      - [1.2. Create the execution role](#12-create-the-execution-role)
      - [1.3. Create the permissions policy file](#13-create-the-permissions-policy-file)
      - [1.4. Attach the permissions policy to the role](#14-attach-the-permissions-policy-to-the-role)
      - [1.5. Verify the role was created and save its ARN](#15-verify-the-role-was-created-and-save-its-arn)
    - [Step 2: Create Task Role](#step-2-create-task-role)
      - [2.1. Create the trust policy file](#21-create-the-trust-policy-file)
      - [2.2. Create the task role](#22-create-the-task-role)
      - [2.3. Create the permissions policy file](#23-create-the-permissions-policy-file)
      - [2.4. Attach the permissions policy to the role](#24-attach-the-permissions-policy-to-the-role)
      - [2.5. Verify the role and save its ARN](#25-verify-the-role-and-save-its-arn)
    - [Step 3: Create EventBridge Role](#step-3-create-eventbridge-role)
      - [3.1. Store the role ARNs in variables](#31-store-the-role-arns-in-variables)
      - [3.2. Create the EventBridge trust policy file](#32-create-the-eventbridge-trust-policy-file)
      - [3.3. Create the EventBridge role](#33-create-the-eventbridge-role)
      - [3.4. Create the EventBridge permissions policy file](#34-create-the-eventbridge-permissions-policy-file)
      - [3.5. Attach the permissions policy to the role](#35-attach-the-permissions-policy-to-the-role)
      - [3.6. Verify the EventBridge role and save its ARN](#36-verify-the-eventbridge-role-and-save-its-arn)
    - [Step 4: Create CloudWatch Log Group](#step-4-create-cloudwatch-log-group)
    - [Step 5: Register ECS Task Definitions](#step-5-register-ecs-task-definitions)
      - [5.1. Create the backup creation task definition file](#51-create-the-backup-creation-task-definition-file)
      - [5.2. Register the backup creation task definition](#52-register-the-backup-creation-task-definition)
      - [5.3. Create the backup deletion task definition file](#53-create-the-backup-deletion-task-definition-file)
      - [5.4. Register the backup deletion task definition](#54-register-the-backup-deletion-task-definition)
      - [5.5. Save both task definition ARNs](#55-save-both-task-definition-arns)
    - [Step 6: Create EventBridge Schedules](#step-6-create-eventbridge-schedules)
      - [6.1. Set network configuration variables](#61-set-network-configuration-variables)
      - [6.2. Create the backup creation schedule](#62-create-the-backup-creation-schedule)
      - [6.3. Create the backup deletion schedule](#63-create-the-backup-deletion-schedule)
    - [Step 7: Verification](#step-7-verification)
      - [7.1. Verify all IAM roles exist](#71-verify-all-iam-roles-exist)
      - [7.2. Verify the task definitions](#72-verify-the-task-definitions)
      - [7.3. Verify the EventBridge schedules](#73-verify-the-eventbridge-schedules)
      - [7.4. Manually test the backup tasks](#74-manually-test-the-backup-tasks)
      - [7.5. Check the task logs](#75-check-the-task-logs)
  - [**Hints**](#hints)
    - [Using Private ECR Registry instead of Docker Hub](#using-private-ecr-registry-instead-of-docker-hub)
    - [Using Private ECR Registry for local development](#using-private-ecr-registry-for-local-development)
    - [Environment Template Variables Syntax](#environment-template-variables-syntax)

## Preliminary tasks

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

## Generate our patamu-purchases-db-backup-php image

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

## Deploy ECS Service for Database Backup

This section provides a complete step-by-step guide to deploy scheduled **ECS Fargate** tasks using **AWS CLI**. We'll create two EventBridge schedules: one to run daily for creating database backups, and another to run weekly for deleting old backups. We'll set up the necessary IAM roles, task definition, and EventBridge schedulers.

> **Prerequisites**: Ensure you have the Docker image built and pushed to ECR, and that you're working from the project root directory.

### Step 1: Create Task Execution Role

The **Task Execution Role** allows ECS to pull images from ECR, write logs to CloudWatch, and access other AWS services needed to run the task.

#### 1.1. Create the trust policy file

This trust policy allows the ECS service to assume the role.

```bash
cat > deploy-to-aws-ecs/task-execution-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

#### 1.2. Create the execution role

```bash
aws iam create-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--execution \
  --assume-role-policy-document file://deploy-to-aws-ecs/task-execution-trust-policy.json
```

#### 1.3. Create the permissions policy file

This policy grants permissions to pull images from ECR and write logs to CloudWatch.

```bash
cat > deploy-to-aws-ecs/task-execution-role-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "ecr:BatchImportUpstreamImage",
            "Resource": "arn:aws:ecr:eu-central-1:280785378630:repository/patamu-purchases-db-backup-php",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer"
            ],
            "Resource": "arn:aws:ecr:eu-central-1:280785378630:repository/patamu-purchases-db-backup-php",
            "Effect": "Allow"
        },
        {
            "Action": "ecr:GetAuthorizationToken",
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:eu-central-1:280785378630:log-group:patamu-purchases--db-backup--container--php-cli--log-group:*",
            "Effect": "Allow"
        }
    ]
}
EOF
```

#### 1.4. Attach the permissions policy to the role

```bash
aws iam put-role-policy \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--execution \
  --policy-name custom-execution-policy \
  --policy-document file://deploy-to-aws-ecs/task-execution-role-policy.json
```

#### 1.5. Verify the role was created and save its ARN

```bash
aws iam get-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--execution \
  --query 'Role.Arn' \
  --output text
```

Expected output: `arn:aws:iam::280785378630:role/patamu-purchases-db-backup--iam--role--execution`

### Step 2: Create Task Role

The **Task Role** grants permissions to the running container (e.g., uploading backups to S3).

#### 2.1. Create the trust policy file

The trust policy is the same as the execution role's.

```bash
cat > deploy-to-aws-ecs/task-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

#### 2.2. Create the task role

```bash
aws iam create-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--task \
  --assume-role-policy-document file://deploy-to-aws-ecs/task-trust-policy.json
```

#### 2.3. Create the permissions policy file

This policy allows the container to upload backup files to S3 and manage archives in Glacier (retrieve and delete old backups).

```bash
cat > deploy-to-aws-ecs/task-role-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::patamu-purchases--resources/db-backups/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:GetBucketLocation",
            "Resource": "arn:aws:s3:::patamu-purchases--resources"
        },
        {
            "Effect": "Allow",
            "Action": [
                "glacier:DescribeVault",
                "glacier:ListJobs",
                "glacier:InitiateJob",
                "glacier:DescribeJob",
                "glacier:GetJobOutput",
                "glacier:DeleteArchive"
            ],
            "Resource": "arn:aws:glacier:eu-central-1:280785378630:vaults/database-backups--purchases"
        }
    ]
}
EOF
```

#### 2.4. Attach the permissions policy to the role

```bash
aws iam put-role-policy \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--task \
  --policy-name custom-task-policy \
  --policy-document file://deploy-to-aws-ecs/task-role-policy.json
```

#### 2.5. Verify the role and save its ARN

```bash
aws iam get-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--task \
  --query 'Role.Arn' \
  --output text
```

Expected output: `arn:aws:iam::280785378630:role/patamu-purchases-db-backup--iam--role--task`

### Step 3: Create EventBridge Role

The **EventBridge Role** allows EventBridge to trigger the ECS task on a schedule.

#### 3.1. Store the role ARNs in variables

These will be used in the EventBridge policy.

```bash
TASK_EXECUTION_ROLE_ARN=$(aws iam get-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--execution \
  --query 'Role.Arn' \
  --output text)

TASK_ROLE_ARN=$(aws iam get-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--task \
  --query 'Role.Arn' \
  --output text)

echo "Task Execution Role ARN: $TASK_EXECUTION_ROLE_ARN"
echo "Task Role ARN: $TASK_ROLE_ARN"
```

#### 3.2. Create the EventBridge trust policy file

```bash
cat > deploy-to-aws-ecs/eventbridge-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "scheduler.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

#### 3.3. Create the EventBridge role

```bash
aws iam create-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--eventbridge \
  --assume-role-policy-document file://deploy-to-aws-ecs/eventbridge-trust-policy.json
```

#### 3.4. Create the EventBridge permissions policy file

This policy allows EventBridge to run the ECS task and pass the necessary roles.

```bash
cat > deploy-to-aws-ecs/eventbridge-role-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ecs:RunTask",
      "Resource": [
        "arn:aws:ecs:eu-central-1:280785378630:task-definition/patamu-purchases-db-backup-create:*",
        "arn:aws:ecs:eu-central-1:280785378630:task-definition/patamu-purchases-db-backup-delete:*"
      ],
      "Condition": {
        "ArnLike": {
          "ecs:cluster": "arn:aws:ecs:eu-central-1:280785378630:cluster/patamu-purchases--cluster"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "$TASK_EXECUTION_ROLE_ARN",
        "$TASK_ROLE_ARN"
      ],
      "Condition": {
        "StringLike": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
EOF
```

#### 3.5. Attach the permissions policy to the role

```bash
aws iam put-role-policy \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--eventbridge \
  --policy-name custom-eventbridge-policy \
  --policy-document file://deploy-to-aws-ecs/eventbridge-role-policy.json
```

#### 3.6. Verify the EventBridge role and save its ARN

```bash
EVENTBRIDGE_ROLE_ARN=$(aws iam get-role \
  --profile lluisaznar \
  --role-name patamu-purchases-db-backup--iam--role--eventbridge \
  --query 'Role.Arn' \
  --output text)

echo "EventBridge Role ARN: $EVENTBRIDGE_ROLE_ARN"
```

### Step 4: Create CloudWatch Log Group

Create a log group for the container logs.

```bash
aws logs create-log-group \
  --profile lluisaznar \
  --log-group-name patamu-purchases--db-backup--container--php-cli--log-group \
  --region eu-central-1
```

> **Note**: If the log group already exists, you'll see an error message. You can safely ignore it.

### Step 5: Register ECS Task Definitions

We'll create two task definitions: one for backup creation and one for backup deletion.

#### 5.1. Create the backup creation task definition file

This file defines the container configuration for creating backups.

```bash
cat > deploy-to-aws-ecs/task-definition-create.json << EOF
{
    "family": "patamu-purchases-db-backup-create",
    "containerDefinitions": [
        {
            "name": "php",
            "image": "280785378630.dkr.ecr.eu-central-1.amazonaws.com/patamu-purchases-db-backup-php:production-202602130856-r1",
            "memory": 1920,
            "essential": true,
            "environment": [
                {
                    "name": "ARTISAN_COMMAND",
                    "value": "db-backup:create"
                }
            ],
            "linuxParameters": {
                "capabilities": {
                    "drop": [
                        "AUDIT_CONTROL",
                        "BLOCK_SUSPEND",
                        "CHOWN",
                        "DAC_OVERRIDE",
                        "DAC_READ_SEARCH",
                        "FOWNER",
                        "FSETID",
                        "IPC_LOCK",
                        "IPC_OWNER",
                        "KILL",
                        "LEASE",
                        "LINUX_IMMUTABLE",
                        "MAC_ADMIN",
                        "MAC_OVERRIDE",
                        "MKNOD",
                        "NET_ADMIN",
                        "NET_BIND_SERVICE",
                        "NET_BROADCAST",
                        "NET_RAW",
                        "SETFCAP",
                        "SETPCAP",
                        "SYS_ADMIN",
                        "SYS_BOOT",
                        "SYS_CHROOT",
                        "SYS_MODULE",
                        "SYS_NICE",
                        "SYS_PACCT",
                        "SYS_PTRACE",
                        "SYS_RAWIO",
                        "SYS_RESOURCE",
                        "SYS_TIME",
                        "SYS_TTY_CONFIG",
                        "SYSLOG",
                        "WAKE_ALARM"
                    ]
                }
            },
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "patamu-purchases--db-backup--container--php-cli--log-group",
                    "awslogs-region": "eu-central-1",
                    "awslogs-stream-prefix": "patamu-purchases--db-backup--container--php-cli"
                }
            }
        }
    ],
    "taskRoleArn": "$TASK_ROLE_ARN",
    "executionRoleArn": "$TASK_EXECUTION_ROLE_ARN",
    "networkMode": "awsvpc",
    "requiresCompatibilities": [
        "FARGATE"
    ],
    "cpu": "256",
    "memory": "2048"
}
EOF
```

#### 5.2. Register the backup creation task definition

```bash
aws ecs register-task-definition \
  --profile lluisaznar \
  --cli-input-json file://deploy-to-aws-ecs/task-definition-create.json
```

#### 5.3. Create the backup deletion task definition file

This file is identical except it runs the `db-backup:delete` command.

```bash
cat > deploy-to-aws-ecs/task-definition-delete.json << EOF
{
    "family": "patamu-purchases-db-backup-delete",
    "containerDefinitions": [
        {
            "name": "php",
            "image": "280785378630.dkr.ecr.eu-central-1.amazonaws.com/patamu-purchases-db-backup-php:production-202602130856-r1",
            "memory": 1920,
            "essential": true,
            "environment": [
                {
                    "name": "ARTISAN_COMMAND",
                    "value": "db-backup:delete"
                }
            ],
            "linuxParameters": {
                "capabilities": {
                    "drop": [
                        "AUDIT_CONTROL",
                        "BLOCK_SUSPEND",
                        "CHOWN",
                        "DAC_OVERRIDE",
                        "DAC_READ_SEARCH",
                        "FOWNER",
                        "FSETID",
                        "IPC_LOCK",
                        "IPC_OWNER",
                        "KILL",
                        "LEASE",
                        "LINUX_IMMUTABLE",
                        "MAC_ADMIN",
                        "MAC_OVERRIDE",
                        "MKNOD",
                        "NET_ADMIN",
                        "NET_BIND_SERVICE",
                        "NET_BROADCAST",
                        "NET_RAW",
                        "SETFCAP",
                        "SETPCAP",
                        "SYS_ADMIN",
                        "SYS_BOOT",
                        "SYS_CHROOT",
                        "SYS_MODULE",
                        "SYS_NICE",
                        "SYS_PACCT",
                        "SYS_PTRACE",
                        "SYS_RAWIO",
                        "SYS_RESOURCE",
                        "SYS_TIME",
                        "SYS_TTY_CONFIG",
                        "SYSLOG",
                        "WAKE_ALARM"
                    ]
                }
            },
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "patamu-purchases--db-backup--container--php-cli--log-group",
                    "awslogs-region": "eu-central-1",
                    "awslogs-stream-prefix": "patamu-purchases--db-backup--container--php-cli"
                }
            }
        }
    ],
    "taskRoleArn": "$TASK_ROLE_ARN",
    "executionRoleArn": "$TASK_EXECUTION_ROLE_ARN",
    "networkMode": "awsvpc",
    "requiresCompatibilities": [
        "FARGATE"
    ],
    "cpu": "256",
    "memory": "2048"
}
EOF
```

#### 5.4. Register the backup deletion task definition

```bash
aws ecs register-task-definition \
  --profile lluisaznar \
  --cli-input-json file://deploy-to-aws-ecs/task-definition-delete.json
```

#### 5.5. Save both task definition ARNs

```bash
TASK_DEFINITION_CREATE_ARN=$(aws ecs describe-task-definition \
  --profile lluisaznar \
  --task-definition patamu-purchases-db-backup-create \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

TASK_DEFINITION_DELETE_ARN=$(aws ecs describe-task-definition \
  --profile lluisaznar \
  --task-definition patamu-purchases-db-backup-delete \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Create Task Definition ARN: $TASK_DEFINITION_CREATE_ARN"
echo "Delete Task Definition ARN: $TASK_DEFINITION_DELETE_ARN"
```

### Step 6: Create EventBridge Schedules

We'll create two schedules using EventBridge Scheduler (the modern approach): one to create daily backups and another to delete old backups.

#### 6.1. Set network configuration variables

We'll reuse the network configuration (subnets and security groups) from the existing patamu-purchases ECS service.

**To find these values in the AWS Console:**

1. Navigate to **ECS** → **Clusters** → **patamu-purchases--cluster**
2. Click on the **patamu-purchases--fargate-service** service
3. Go to the **Configuration and networking** tab
4. Under **Network configuration**, you'll find:
   - **Subnets**: Copy the subnet IDs (they look like `subnet-xxxxxxxxx`)
   - **Security groups**: Copy the security group IDs (they look like `sg-xxxxxxxxx`)

   > **Note**: Only copy security groups needed for database access and basic networking. Exclude security groups specific to the main application (like packagist or paypal).

**Set the environment variables:**

```bash
# Set subnets as comma-separated values (replace with your actual subnet IDs)
SUBNETS="subnet-0425fdfb5541b7a9c,subnet-092dd5929001c7a12"

# Set security groups as comma-separated values (replace with your actual security group IDs)
SECURITY_GROUPS="sg-08ccd68bb58faa5f3,sg-023f4f99f90f9e3d6,sg-0ba7bab5f6f64d623"

echo "Subnets: $SUBNETS"
echo "Security Groups: $SECURITY_GROUPS"
```

#### 6.2. Create the backup creation schedule

This creates a daily schedule to run the backup creation at 5 AM UTC.

```bash
aws scheduler create-schedule \
  --profile lluisaznar \
  --name patamu-purchases-db-backup--event--create \
  --schedule-expression "cron(0 5 * * ? *)" \
  --schedule-expression-timezone "UTC" \
  --description "Daily database backup creation at 5 AM UTC" \
  --flexible-time-window Mode=OFF \
  --target "{
    \"Arn\": \"arn:aws:ecs:eu-central-1:280785378630:cluster/patamu-purchases--cluster\",
    \"RoleArn\": \"$EVENTBRIDGE_ROLE_ARN\",
    \"EcsParameters\": {
      \"TaskDefinitionArn\": \"$TASK_DEFINITION_CREATE_ARN\",
      \"LaunchType\": \"FARGATE\",
      \"NetworkConfiguration\": {
        \"awsvpcConfiguration\": {
          \"Subnets\": [\"$SUBNETS\"],
          \"SecurityGroups\": [\"$SECURITY_GROUPS\"],
          \"AssignPublicIp\": \"DISABLED\"
        }
      }
    }
  }"
```

#### 6.3. Create the backup deletion schedule

This creates a weekly schedule to delete old backups every Sunday at 6 AM UTC.

```bash
aws scheduler create-schedule \
  --profile lluisaznar \
  --name patamu-purchases-db-backup--event--delete \
  --schedule-expression "cron(0 6 ? * SUN *)" \
  --schedule-expression-timezone "UTC" \
  --description "Weekly database backup cleanup on Sundays at 6 AM UTC" \
  --flexible-time-window Mode=OFF \
  --target "{
    \"Arn\": \"arn:aws:ecs:eu-central-1:280785378630:cluster/patamu-purchases--cluster\",
    \"RoleArn\": \"$EVENTBRIDGE_ROLE_ARN\",
    \"EcsParameters\": {
      \"TaskDefinitionArn\": \"$TASK_DEFINITION_DELETE_ARN\",
      \"LaunchType\": \"FARGATE\",
      \"NetworkConfiguration\": {
        \"awsvpcConfiguration\": {
          \"Subnets\": [\"$SUBNETS\"],
          \"SecurityGroups\": [\"$SECURITY_GROUPS\"],
          \"AssignPublicIp\": \"DISABLED\"
        }
      }
    }
  }"
```

### Step 7: Verification

#### 7.1. Verify all IAM roles exist

```bash
echo "=== Verifying IAM Roles ==="
aws iam get-role --profile lluisaznar --role-name patamu-purchases-db-backup--iam--role--task --query 'Role.RoleName' --output text
aws iam get-role --profile lluisaznar --role-name patamu-purchases-db-backup--iam--role--execution --query 'Role.RoleName' --output text
aws iam get-role --profile lluisaznar --role-name patamu-purchases-db-backup--iam--role--eventbridge --query 'Role.RoleName' --output text
```

Expected output:

```text
=== Verifying IAM Roles ===
patamu-purchases-db-backup--iam--role--task
patamu-purchases-db-backup--iam--role--execution
patamu-purchases-db-backup--iam--role--eventbridge
```

#### 7.2. Verify the task definitions

```bash
echo "=== Backup Creation Task Definition ==="
aws ecs describe-task-definition \
  --profile lluisaznar \
  --task-definition patamu-purchases-db-backup-create \
  --query 'taskDefinition.{Family:family,Revision:revision,Status:status}' \
  --output table

echo ""
echo "=== Backup Deletion Task Definition ==="
aws ecs describe-task-definition \
  --profile lluisaznar \
  --task-definition patamu-purchases-db-backup-delete \
  --query 'taskDefinition.{Family:family,Revision:revision,Status:status}' \
  --output table
```

#### 7.3. Verify the EventBridge schedules

```bash
echo "=== Backup Creation Schedule ==="
aws scheduler get-schedule \
  --profile lluisaznar \
  --name patamu-purchases-db-backup--event--create \
  --query '{Name:Name,State:State,Schedule:ScheduleExpression,Description:Description,TaskDef:Target.EcsParameters.TaskDefinitionArn}' \
  --output table

echo ""
echo "=== Backup Deletion Schedule ==="
aws scheduler get-schedule \
  --profile lluisaznar \
  --name patamu-purchases-db-backup--event--delete \
  --query '{Name:Name,State:State,Schedule:ScheduleExpression,Description:Description,TaskDef:Target.EcsParameters.TaskDefinitionArn}' \
  --output table
```

#### 7.4. Manually test the backup tasks

You can manually run both tasks to test them before waiting for the schedules:

**Test backup creation:**

```bash
aws ecs run-task \
  --profile lluisaznar \
  --cluster patamu-purchases--cluster \
  --task-definition patamu-purchases-db-backup-create \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}"
```

**Test backup deletion:**

```bash
aws ecs run-task \
  --profile lluisaznar \
  --cluster patamu-purchases--cluster \
  --task-definition patamu-purchases-db-backup-delete \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}"
```

#### 7.5. Check the task logs

After the task runs, check CloudWatch Logs:

```bash
aws logs tail \
  --profile lluisaznar \
  --follow \
  patamu-purchases--db-backup--container--php-cli--log-group
```

> **Success!** Your scheduled database backup tasks are now configured:
>
> - Backups will be created daily at 5 AM UTC
> - Old backups will be deleted weekly on Sundays at 6 AM UTC

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
