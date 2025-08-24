# noVNC Ubuntu with Prism Launcher

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

Notes and caveats:
- This image runs a headless X server provided by Xvfb. It may not provide full GPU acceleration; performance depends on the host.
- For better OpenGL support, consider mapping the host GPU devices or using a docker image with GPU passthrough.
- The container runs a non-root user `developer`.
# vmtest