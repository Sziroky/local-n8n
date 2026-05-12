# n8n Local Docker Setup

Local n8n instance with Python and PyMuPDF support, running on Docker Desktop with WSL2.

## Stack

| Container | Image | Port | Role |
|---|---|---|---|
| `n8n-main` | `n8nio/n8n:latest` | `5678` | Main n8n application |
| `n8n-runners` | `n8nio/runners:latest` (custom build) | — | Python/JS code execution |

## Why two containers?

Since n8n v2.x, user code (Code node) runs in a separate process — the **task runner**. This isolates code execution from the main n8n process: if your code crashes, n8n keeps running. The two containers communicate over an internal broker on port 5679. Details: [Task Runners docs](https://docs.n8n.io/hosting/configuration/task-runners/)

## File structure

```
D:\Docker\n8n\
├── Dockerfile              # Custom runners image with extra Python packages
├── docker-compose.yml      # Both container definitions
├── n8n-task-runners.json   # Runner config (ports, package allowlist)
├── .env                    # Secrets (do not commit to git!)
└── data\
    ├── n8n\                # n8n data (workflows, credentials) - volume
    └── output\             # Workflow output files - volume
```

## Running

```bash
cd D:\Docker\n8n

# First run or after changing the Dockerfile
docker compose down
docker compose build
docker compose up -d

# Subsequent runs (no Dockerfile changes)
docker compose up -d

# Stop
docker compose down
```

n8n available at: **http://localhost:5678**

## Adding new Python packages

Two steps are required.

### Step 1 — Install the package in the Dockerfile

```dockerfile
FROM n8nio/runners:latest

USER root

RUN cd /opt/runners/task-runner-python && uv pip install \
    pymupdf \
    your_new_package    # ← add here

COPY n8n-task-runners.json /etc/n8n-task-runners.json

USER runner
```

### Step 2 — Add the package to the allowlist in `n8n-task-runners.json`

```json
{
  "task-runners": [
    {
      "runner-type": "python",
      ...
      "env-overrides": {
        "N8N_RUNNERS_EXTERNAL_ALLOW": "fitz,your_new_package"
      }
    }
  ]
}
```

> **Note:** The allowlist uses the Python **import name**, not the pip package name.
> For example, the `pymupdf` package is imported as `fitz`.

### Step 3 — Rebuild and restart

```bash
docker compose down
docker compose build
docker compose up -d
```

## Runner configuration (`n8n-task-runners.json`)

This file is based on the default n8n runner config. Source: [GitHub n8n-io/n8n](https://github.com/n8n-io/n8n/blob/master/docker/images/runners/n8n-task-runners.json)

Key details:
- The launcher occupies port `5680`
- JavaScript runner uses port `5681`
- Python runner uses port `5682`
- Ports must be unique and must not conflict with the launcher

## Secrets (`.env`)

```env
N8N_RUNNERS_AUTH_TOKEN=your_secret_token
```

The token must be identical in both containers (`n8n-main` and `n8n-runners`). Never commit `.env` to git.

## Useful commands

```bash
# n8n logs
docker logs n8n-main -f

# Runners logs
docker logs n8n-runners -f

# Shell into the runners container
docker exec -it n8n-runners sh

# Container status
docker ps

# Update n8n (no Dockerfile changes)
docker compose pull
docker compose up -d

# Update n8n (with Dockerfile changes)
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Useful links

| Resource | Link |
|---|---|
| n8n documentation | https://docs.n8n.io |
| Task Runners configuration | https://docs.n8n.io/hosting/configuration/task-runners/#task-runners |
| Default runners config (GitHub) | https://github.com/n8n-io/n8n/blob/master/docker/images/runners/n8n-task-runners.json |
| n8n community forum | https://community.n8n.io |
| Multiple runners port conflict (forum) | https://community.n8n.io/t/health-check-server-port-is-required-with-multiple-runners/274028/2 |
| PyMuPDF documentation | https://pymupdf.readthedocs.io |
| Ollama | http://localhost:11434 |

## Known issues and solutions

### `Python runner unavailable`
n8n v2.x requires an external task runner. Make sure the `n8n-runners` container is running (`docker ps`) and that `N8N_RUNNERS_ENABLED=true` and `N8N_RUNNERS_MODE=external` are set in `n8n-main`.

### `Security violations detected - Import of external package disallowed`
The package is not on the allowlist. Add the import name to `N8N_RUNNERS_EXTERNAL_ALLOW` in `n8n-task-runners.json` and rebuild the image.

### `health-check-server-port conflicts with launcher`
The launcher occupies port 5680. The JavaScript runner must use 5681 and Python 5682. Do not change these ports.

### Runners stuck in `Restarting` state
Check the logs: `docker logs n8n-runners`. The most common cause is a JSON parse error in `n8n-task-runners.json` (e.g. a number instead of a string for a port value).

## Next steps

- [ ] Import workflows from n8n Cloud
- [ ] Connect Ollama (`http://host.docker.internal:11434`)
- [ ] Code node with PyMuPDF for slicing PDF pages
- [ ] Recipe extraction via Ollama
- [ ] Save to local SQLite database
- [ ] Deploy to VPS (Hetzner/DigitalOcean)
