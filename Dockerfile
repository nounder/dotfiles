FROM alpine:3

# Install all packages in one go
RUN apk add --no-cache \
    bash \
    curl \
    git \
    helix \
    fish \ 
    fd \
    ripgrep \ 
    tmux \
    fzf \
    htop \
    coreutils \
    # for bun
    libstdc++

# Get bun.js binary from official Docker image
COPY --from=oven/bun:1-alpine /usr/local/bin/bun /usr/local/bin/bun
COPY --from=oven/bun:1-alpine /usr/local/bin/bunx /usr/local/bin/bunx

COPY . /root/dotfiles

WORKDIR /root/dotfiles

RUN chmod +x install.sh && ./install.sh

# Set fish as default shell
RUN echo "/usr/bin/fish" >> /etc/shells

WORKDIR /root

# fly ssh automatically runs bash instead of default shell
# so we replace bash with fish when it's started in interactive mode
RUN echo "exec fish" >> /root/.bash_profile

ENV EDITOR=hx

CMD ["/usr/bin/fish"]
