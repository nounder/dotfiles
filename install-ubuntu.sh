#!/bin/bash
set -e

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_SUFFIX="x86_64" ;;
    aarch64) ARCH_SUFFIX="aarch64" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

sudo apt update
sudo apt install -y fzf ripgrep fd-find

# fd-find installs as 'fdfind', create symlink for 'fd' command
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p ~/bin
    ln -sf "$(command -v fdfind)" ~/bin/fd
    echo "Created symlink: fd -> fdfind"
fi

echo "Installed: fzf, ripgrep (rg), fd-find (fd)"

# Yazi installation
YAZI_VERSION="26.1.4"
if [ "$ARCH_SUFFIX" = "x86_64" ]; then
    YAZI_SHA256="7f40ca439f710fe7fbbda71c7873d278dd05fc20b87bd989b6e5233d7decbe31"
else
    YAZI_SHA256="e65b819d0e0404ca960ea732bb1d0bbeacfac8cc7f1eccc3638f9179838c0809"
fi

read -p "Install yazi terminal file manager? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing yazi v${YAZI_VERSION}..."
    YAZI_DIR="yazi-${ARCH_SUFFIX}-unknown-linux-gnu"
    YAZI_ZIP="${YAZI_DIR}.zip"
    YAZI_URL="https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/${YAZI_ZIP}"

    cd /tmp
    curl -sLO "$YAZI_URL"

    echo "${YAZI_SHA256}  ${YAZI_ZIP}" | sha256sum -c -
    if [ $? -ne 0 ]; then
        echo "ERROR: SHA256 checksum verification failed!"
        rm -f "$YAZI_ZIP"
        exit 1
    fi

    unzip -o "$YAZI_ZIP"
    mkdir -p ~/bin
    mv "${YAZI_DIR}/yazi" ~/bin/
    rm -rf "${YAZI_DIR}"*

    echo "Installed: yazi $(~/bin/yazi --version | head -1)"
fi

# Nushell installation
NU_VERSION="0.109.1"
if [ "$ARCH_SUFFIX" = "x86_64" ]; then
    NU_SHA256="0fa23b828ac610e3ee7798b25e38cef5cfdc47503326236d27cd57d1c959190e"
else
    NU_SHA256="d32b40be35ea82f45b912359fca61edcbe21c5f426e390f8aef0f8e98ddf5f14"
fi

read -p "Install nushell? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing nushell v${NU_VERSION}..."
    NU_DIR="nu-${NU_VERSION}-${ARCH_SUFFIX}-unknown-linux-gnu"
    NU_TAR="${NU_DIR}.tar.gz"
    NU_URL="https://github.com/nushell/nushell/releases/download/${NU_VERSION}/${NU_TAR}"

    cd /tmp
    curl -sLO "$NU_URL"

    echo "${NU_SHA256}  ${NU_TAR}" | sha256sum -c -
    if [ $? -ne 0 ]; then
        echo "ERROR: SHA256 checksum verification failed!"
        rm -f "$NU_TAR"
        exit 1
    fi

    tar -xzf "$NU_TAR"
    mkdir -p ~/bin
    mv "${NU_DIR}/nu" ~/bin/
    rm -rf "${NU_DIR}"*

    echo "Installed: $(~/bin/nu --version)"
fi
