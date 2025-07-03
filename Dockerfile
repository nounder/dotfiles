FROM alpine:3

# Install all packages in one go
RUN apk add --no-cache \
    curl \
    git \
    helix \
    fish \ 
    fd \
    ripgrep \ 
    tmux \
    fzf

# Get bun.js binary from official Docker image
COPY --from=oven/bun:latest /usr/local/bin/bun /usr/local/bin/bun
COPY --from=oven/bun:latest /usr/local/bin/bunx /usr/local/bin/bunx

COPY . /root/dotfiles

WORKDIR /root/dotfiles

RUN chmod +x install.sh && ./install.sh

# Set fish as default shell
RUN echo "/usr/bin/fish" >> /etc/shells

WORKDIR /root

ENV EDITOR=hx

CMD ["/usr/bin/fish"]
