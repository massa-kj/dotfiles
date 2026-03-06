FROM ubuntu:24.04

# Install minimal dependencies required for bootstrap
RUN apt-get update && apt-get install -y \
    git \
    curl \
    sudo \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /dotfiles

# Copy dotfiles repository
COPY . .

# Make scripts executable
RUN chmod +x dotfiles \
    && chmod +x platforms/wsl/bootstrap.sh \
    && chmod +x cmd/apply.sh \
    && find tests/environment/linux/docker/scenarios -type f -name "*.sh" -exec chmod +x {} \;

CMD ["/bin/bash"]
