# .gitpod.Dockerfile
FROM gitpod/workspace-full:latest

# Install tools as the gitpod user
USER gitpod
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install helper tools
RUN brew update && brew upgrade && brew install tfenv && brew cleanup
RUN tfenv install latest && tfenv use latest

COPY .gitpod.bashrc /home/gitpod/.bashrc.d/custom

# Give back control
USER root
#  and revert back to default shell
#  otherwise adding Gitpod Layer will fail
SHELL ["/bin/sh", "-c"]