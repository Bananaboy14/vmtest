Getting started

1. Install Docker and Docker Compose.
2. Clone the repo and run:

```bash
git clone <repo>
cd vmtest
docker compose up --build -d
```

3. Open the UI at `http://localhost:8080/vnc.html` (or use the port forwarded by your host).

Troubleshooting
- If the web UI says it cannot connect to the server, try opening the UI with the host parameter:

  `http://localhost:8080/vnc.html?host=localhost&port=8080`

- If you are loading vnc.html inside an HTTPS page, enable TLS in `docker-compose.yml` by setting `NOVNC_TLS=1` and rebuild.

Contributions
- Open a PR with improvements. If adding GPU passthrough instructions, include host platform notes.
