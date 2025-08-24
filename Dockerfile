FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates sudo wget curl git python3 python3-pip tzdata \
       xvfb x11vnc xfce4 xfce4-terminal dbus-x11 xinit xauth \
       openjdk-17-jre-headless libgl1-mesa-dri libgbm1 libgtk-3-0 openssl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash developer && echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Install noVNC and websockify
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify

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

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY noVNC_index.html /opt/noVNC/index.html
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R developer:developer /home/developer /opt/noVNC

EXPOSE 8080 5900

VOLUME ["/home/developer/.minecraft", "/home/developer/.local/share"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
