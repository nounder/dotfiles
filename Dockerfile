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
    fzf

# Install bun.js using the official install script
RUN curl -fsSL https://bun.sh/install | bash

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
