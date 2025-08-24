# noVNC Ubuntu with Prism Launcher

A small Docker-based setup that provides an Ubuntu 22.04 XFCE desktop exposed over noVNC and pre-installs the Prism Launcher AppImage (if available). Use this to share a reproducible environment for launching Minecraft via Prism.

This repository contains a Docker setup to run an Ubuntu 22.04 desktop exposed over noVNC. It includes a lightweight Xfce session, x11vnc, and noVNC. The Prism Launcher AppImage is downloaded at build time if available, and you can place it at `/home/developer/PrismLauncher.AppImage` inside the container to run it.

Files:
- `Dockerfile` — builds the Ubuntu 22.04 image with desktop, VNC, and noVNC.
- `entrypoint.sh` — starts X, x11vnc, and noVNC.
- `docker-compose.yml` — convenience compose file to build and run the container.

Quick start:

1. Build and start with docker-compose in this directory:

```bash
docker compose up --build -d
```

2. Open your browser to `http://localhost:8080/vnc.html`.

3. If Prism Launcher did not download at build time, copy the AppImage into the running container or into `data/` before starting:

```bash
# download locally and copy into container
wget -O PrismLauncher.AppImage "<url-from-github-release>"
docker cp PrismLauncher.AppImage novnc-ubuntu:/home/developer/PrismLauncher.AppImage
docker exec -it novnc-ubuntu chown developer:developer /home/developer/PrismLauncher.AppImage
```

4. From the noVNC desktop, open a terminal and run:

```bash
./PrismLauncher.AppImage
```

Sharing this repository

1. Push this repo to GitHub (example):

```bash
# create remote
git remote add origin git@github.com:<your-username>/vmtest.git
git push -u origin main
```

2. Your friends can then clone and run:

```bash
git clone https://github.com/<your-username>/vmtest.git
cd vmtest
docker compose up --build -d
open http://localhost:8080/vnc.html
```

Notes and caveats:
- This image runs a headless X server provided by Xvfb. It may not provide full GPU acceleration; performance depends on the host.
- For better OpenGL support, consider mapping the host GPU devices or using a docker image with GPU passthrough.
- The container runs a non-root user `developer`.
# vmtest