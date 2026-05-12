# n8n Docker Setup — AI Instructions

This project runs a local n8n instance with custom Python packages available in the Code node.

## Architecture

Two containers defined in `docker-compose.yml`:
- **n8n-main** (`n8nio/n8n:latest`) — the n8n application, port 5678
- **n8n-runners** (custom build from `./Dockerfile`) — executes Python/JS code from Code nodes

The runners image is built from `n8nio/runners:latest`. Python packages are installed inside `/opt/runners/task-runner-python` using `uv`.

## How to add a new Python package

When the user asks to add a package (e.g. "add opencv", "add my custom package"), do both steps — missing either one will cause a runtime error.

### Step 1 — Edit `Dockerfile`

Add the package to the `uv pip install` command:

```dockerfile
FROM n8nio/runners:latest

USER root

RUN cd /opt/runners/task-runner-python && uv pip install \
    pymupdf \
    new_package_name_here

COPY n8n-task-runners.json /etc/n8n-task-runners.json

USER runner
```

### Step 2 — Edit `n8n-task-runners.json`

Add the package's **Python import name** (not the pip name) to `N8N_RUNNERS_EXTERNAL_ALLOW` for the Python runner entry. Comma-separated, no spaces.

```json
"N8N_RUNNERS_EXTERNAL_ALLOW": "fitz,new_import_name"
```

> The pip name and the import name often differ. Known mappings:
> - `pymupdf` → import as `fitz`
> - `opencv-python` → import as `cv2`
> - `pillow` → import as `PIL`
> - `scikit-learn` → import as `sklearn`
> - `beautifulsoup4` → import as `bs4`
>
> If unsure, check PyPI or ask the user for the import name before editing.

### Step 3 — Tell the user to rebuild

After editing both files, instruct the user to run:

```bash
docker compose down
docker compose build
docker compose up -d
```

## Key files

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the runners image; add pip packages here |
| `docker-compose.yml` | Container definitions and environment variables |
| `n8n-task-runners.json` | Runner ports and Python/JS package allowlist |
| `.env` | `N8N_RUNNERS_AUTH_TOKEN` — must match in both containers |

## Port map (internal)

| Port | Used by |
|---|---|
| 5678 | n8n web UI (exposed to host) |
| 5679 | Task broker (n8n-main ↔ n8n-runners, internal) |
| 5680 | Launcher health check |
| 5681 | JavaScript runner health check |
| 5682 | Python runner health check |

Do not change these ports — conflicts cause the runners container to restart-loop.

## Common errors and their fixes

| Error | Fix |
|---|---|
| `Security violations detected - Import of external package disallowed` | Import name missing from `N8N_RUNNERS_EXTERNAL_ALLOW` in `n8n-task-runners.json` |
| `Python runner unavailable` | `n8n-runners` container is not running; check `docker ps` and `docker logs n8n-runners` |
| Runners stuck in `Restarting` | Parse error in `n8n-task-runners.json` — check for numbers where strings are expected (ports must be strings) |
| `health-check-server-port conflicts` | Two runner entries sharing a port; JS=5681, Python=5682 |
