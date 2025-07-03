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

# Install bun.js using the official install script
RUN curl -fsSL https://bun.sh/install | bash

COPY . /root/dotfiles

WORKDIR /root/dotfiles

RUN chmod +x install.sh && ./install.sh

# Set fish as default shell
RUN echo "/usr/bin/fish" >> /etc/shells

WORKDIR /root

ENV EDITOR=hx

CMD ["/usr/bin/fish"]
