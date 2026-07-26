# Docker
#
# CLI only - this bundle deliberately installs no container runtime, because
# that's a choice rather than a default. Pick one and uncomment it below.
#
# Removed as part of the 2026-07 cleanup, all gone from Homebrew entirely so
# `brew bundle install` on the old file failed outright:
#   docker-machine              upstream archived in 2021; only a GitLab fork survives
#   docker-machine-completion   went with it
#   docker-toolbox              EOL, superseded by Docker Desktop
#   docker-edge                 lived in homebrew/cask-versions, a tap that no longer exists
#   kitematic                   discontinued GUI
#   kite                        the company shut down in 2022

brew "docker"

# Compose is a CLI plugin, so it isn't linked onto PATH as its own binary. For
# `docker compose` to find it, add to ~/.docker/config.json:
#   "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]
brew "docker-compose", link: false

# Browse registries and tags without pulling
brew "docker-ls"

# Kubernetes GUI - not Docker as such, worth splitting into its own bundle if
# the k8s tooling ever grows past this one entry
cask "kubernetic"

# Container runtime - pick one:
#
#   cask "docker-desktop"   the official app. Note the cask was renamed from
#                           "docker", so the old name now resolves via an alias
#   cask "orbstack"         faster and lighter on macOS, drop-in Docker API
#   brew "colima"           CLI-only runtime on Lima, no GUI, no licence question
#
# Docker Desktop needs a paid subscription for larger companies; OrbStack and
# Colima don't, which is usually what settles it.
