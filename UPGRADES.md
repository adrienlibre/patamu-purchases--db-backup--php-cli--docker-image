# UPGRADES

This file contains the upgrades' log of the **Laravel** app.

## 202602171218

- Fixed Dockerfile: Added `CMD []` instruction to override base image's CMD, preventing `php -a` interactive shell from running instead of artisan commands
- Fixed EventBridge trust policy: Changed service principal from `events.amazonaws.com` to `scheduler.amazonaws.com` for AWS EventBridge Scheduler compatibility
- Added deployment automation: Created `load-aws-env.sh` helper script in `deploy-to-aws-ecs/` directory to automatically retrieve and export all necessary environment variables (IAM role ARNs, task definition ARNs, network configuration)
- Updated README: Added comprehensive step-by-step deployment instructions for ECS tasks and EventBridge Scheduler configuration
- Fixed environment template parser: Modified `parse_env_template` function in `files/lib/libfs.sh` to handle template files without trailing newlines, ensuring all environment variables are parsed correctly

## 202602130856

- Install Bugsnag
- Add log variables on `files/templates/laravel/env/020--log`.

## 202602121518

- First commit
