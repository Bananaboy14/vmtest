FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NOVNC_USE_PROXY=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates sudo wget curl git python3 python3-pip tzdata \
    xvfb x11vnc xfce4 xfce4-terminal dbus-x11 xinit xauth \
     openjdk-17-jre-headless libgl1-mesa-dri libgbm1 libgtk-3-0 openssl \
    libfuse2 software-properties-common \
    tigervnc-standalone-server tigervnc-tools \
        libgl1-mesa-glx libegl1-mesa libgles2 \
        libxrandr2 libxcomposite1 libxcursor1 libxdamage1 libxfixes3 libxi6 \
        libxinerama1 libxss1 libxtst6 \
        libatk1.0-0 libatk-bridge2.0-0 libgdk-pixbuf2.0-0 \
        libpangocairo-1.0-0 libpango-1.0-0 libxcb-render0 libxcb-shm0 \
        libnss3 libasound2 pulseaudio \
    iproute2 net-tools netcat gdb \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash developer && echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Install noVNC and websockify
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify

# Ensure the system python has websockify and numpy for best compatibility
RUN pip3 install --no-cache-dir websockify numpy || true

# Install nodejs & npm so the lightweight novnc_proxy fallback can run inside the container
RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm || true

# Install TurboVNC from releases (best-effort). This will provide vncserver/Xvnc.
RUN set -eux; \
    PR_URL=$(curl -s https://api.github.com/repos/TurboVNC/TurboVNC/releases/latest | \
        grep "browser_download_url" | grep amd64.deb | head -n1 | cut -d '"' -f4 || true); \
    if [ -n "$PR_URL" ]; then \
        echo "Downloading TurboVNC from $PR_URL"; \
        wget -qO /tmp/turbovnc.deb "$PR_URL" || true; \
        if [ -f /tmp/turbovnc.deb ]; then apt-get update || true; dpkg -i /tmp/turbovnc.deb || apt-get -f install -y; fi; \
    else \
        echo "TurboVNC release not found via GitHub API; attempting known package URL fallback"; \
        # fallback: try known Ubuntu-friendly package names (best-effort)
        set +e; \
        wget -qO /tmp/turbovnc.deb "https://sourceforge.net/projects/turbovnc/files/latest/download" || true; \
        if [ -f /tmp/turbovnc.deb ]; then apt-get update || true; dpkg -i /tmp/turbovnc.deb || apt-get -f install -y; fi; \
        set -e; \
        echo "If TurboVNC wasn't installed, you can enable runtime install by setting INSTALL_TURBOVNC=1 when starting the container"; \
    fi

    # Ensure a newer libstdc++ is available (some AppImages bundle binaries linked
    # against newer GLIBCXX symbols). We add the ubuntu-toolchain PPA and install
    # libstdc++6 from it if available.
    RUN set -eux; \
            apt-get update; \
            if command -v add-apt-repository >/dev/null 2>&1; then \
                add-apt-repository -y ppa:ubuntu-toolchain-r/test || true; \
                apt-get update || true; \
                apt-get install -y --no-install-recommends libstdc++6 || true; \
            fi

# Download latest Prism Launcher AppImage at build time (best-effort)
RUN set -eux; \
    PR_URL=$(curl -s https://api.github.com/repos/PrismLauncher/PrismLauncher/releases/latest | \
        grep "browser_download_url" | grep AppImage | head -n1 | cut -d '"' -f4 || true); \
    if [ -n "$PR_URL" ]; then \
        mkdir -p /home/developer/bin; \
        wget -qO /home/developer/PrismLauncher.AppImage "$PR_URL"; \
        chmod +x /home/developer/PrismLauncher.AppImage; \
    else \
        echo "Warning: PrismLauncher AppImage URL not found at build time. Download it later into /home/developer/PrismLauncher.AppImage"; \
    fi

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY noVNC_index.html /opt/noVNC/index.html
COPY novnc_proxy /workspaces/vmtest/novnc_proxy
# Copy all noVNC assets (HTML, JS, CSS, images, etc.)
COPY noVNC/ /opt/noVNC/
# If you have placed a Lunar AppImage in the repo root as `lunarclient.AppImage`,
# copy it into the image so the container has it available at runtime.
COPY lunarclient.AppImage /home/developer/lunarclient.AppImage
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod -R +x /usr/local/bin/scripts || true \
    && chown -R developer:developer /home/developer /opt/noVNC /usr/local/bin/scripts || true \
    && chmod +x /home/developer/lunarclient.AppImage 2>/dev/null || true

# Install novnc_proxy npm dependencies as the developer user (best-effort)
RUN if [ -d /workspaces/vmtest/novnc_proxy ]; then \
            su - developer -c "cd /workspaces/vmtest/novnc_proxy && npm install --no-audit --no-fund" || true; \
        fi

EXPOSE 8080 5900 5901

VOLUME ["/home/developer/.minecraft", "/home/developer/.local/share"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
