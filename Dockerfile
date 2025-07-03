FROM alpine:3

# Install all packages in one go
RUN apk add --no-cache \
    curl git neovim fish fd ripgrep tmux fzf gcc musl-dev

COPY . /root/dotfiles

WORKDIR /root/dotfiles

RUN chmod +x install.sh && ./install.sh

# Set fish as default shell
RUN echo "/usr/bin/fish" >> /etc/shells

RUN nvim --headless "+Lazy! sync" +qa

WORKDIR /root

CMD ["/usr/bin/fish"]
