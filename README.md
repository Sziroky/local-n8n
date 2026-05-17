# n8n Local Docker Setup

Local n8n instance with Python and PyMuPDF support, running on Docker Desktop with WSL2.

## Table of Contents

- [Requirements](#requirements)
- [Stack](#stack)
- [Why two containers?](#why-two-containers)
- [File structure](#file-structure)
- [Running](#running)
- [Adding new Python packages](#adding-new-python-packages)
- [Runner configuration](#runner-configuration-n8n-task-runnersjson)
- [Secrets](#secrets-env)
- [AI assistant context](#ai-assistant-context-agentsmd)
- [Links](#links)
- [Known issues and solutions](#known-issues-and-solutions)

---

## Requirements

- Docker Desktop with WSL2
- An inference server e.g. [Ollama](https://ollama.com)
- `data/` directory with `n8n/` and `output/` subfolders for volumes

## Stack

| Container | Image | Port | Role |
|---|---|---|---|
| `n8n-main` | `n8nio/n8n:latest` | `5678` | Main n8n application |
| `n8n-runners` | `n8nio/runners:latest` (custom build) | — | Python/JS code execution |

## Why two containers?

Since n8n v2.x, user code (Code node) runs in a separate process — the **task runner**. This isolates code execution from the main n8n process: if your code crashes, n8n keeps running. The two containers communicate over an internal broker on port 5679. Details: [Task Runners docs](https://docs.n8n.io/hosting/configuration/task-runners/)

## File structure

```
n8n/
├── Dockerfile                  # Custom runners image with extra Python packages
├── docker-compose.yml          # Both container definitions
├── n8n-task-runners.json       # Runner config (ports, package allowlist)
├── rebuild.ps1                 # Shortcut: down → build → up
├── AGENTS.md                   # AI assistant context guide
├── .env                        # Secrets (not committed!)
└── data\
    ├── n8n\                    # n8n data (workflows, credentials) — volume
    └── output\                 # Workflow output files — volume
```

## Running

```powershell
# First run or after changing the Dockerfile
.\rebuild.ps1

# Subsequent runs (no Dockerfile changes)
docker compose up -d

# Stop
docker compose down
```

n8n available at: **http://localhost:5678**

## Adding new Python packages

Two files must be updated — missing either one causes a runtime error.

### Step 1 — Install the package in the Dockerfile

```dockerfile
RUN cd /opt/runners/task-runner-python && uv pip install \
    pymupdf \
    your_new_package    # ← add here
```

### Step 2 — Add the import name to the allowlist in `n8n-task-runners.json`

```json
"N8N_RUNNERS_EXTERNAL_ALLOW": "fitz,your_import_name"
```

> **Note:** The allowlist uses the Python **import name**, not the pip package name.
> Common mappings: `pymupdf` → `fitz`, `opencv-python` → `cv2`, `pillow` → `PIL`, `scikit-learn` → `sklearn`, `beautifulsoup4` → `bs4`.

### Step 3 — Rebuild and restart

```powershell
.\rebuild.ps1
```

## Runner configuration (`n8n-task-runners.json`)

Based on the default n8n runner config. Source: [GitHub n8n-io/n8n](https://github.com/n8n-io/n8n/blob/master/docker/images/runners/n8n-task-runners.json)

| Port | Used by |
|---|---|
| 5680 | Launcher health check |
| 5681 | JavaScript runner |
| 5682 | Python runner |

Ports must be unique strings — do not change them.

## Secrets (`.env`)

```env
N8N_RUNNERS_AUTH_TOKEN=your_secret_token
```

The token must be identical in both containers (`n8n-main` and `n8n-runners`). Copy `.env.example` to `.env` and set your value.

## AI assistant context (`AGENTS.md`)

[AGENTS.md](AGENTS.md) contains a structured guide for AI assistants (Claude, Copilot, Cursor, etc.). If you ask an AI to add a package or fix a runner error, point it to that file — it covers the full architecture, file roles, and common error fixes without needing to analyse the whole project.

## Links

| Resource | Link |
|---|---|
| n8n documentation | https://docs.n8n.io |
| Task Runners configuration | https://docs.n8n.io/hosting/configuration/task-runners/#task-runners |
| Default runners config (GitHub) | https://github.com/n8n-io/n8n/blob/master/docker/images/runners/n8n-task-runners.json |
| n8n community forum | https://community.n8n.io |
| Multiple runners port conflict (forum) | https://community.n8n.io/t/health-check-server-port-is-required-with-multiple-runners/274028/2 |
| PyMuPDF documentation | https://pymupdf.readthedocs.io |
| Ollama | https://ollama.com |

## Known issues and solutions

### `Python runner unavailable`
Make sure the `n8n-runners` container is running (`docker ps`) and that `N8N_RUNNERS_ENABLED=true` and `N8N_RUNNERS_MODE=external` are set in `n8n-main`.

### `Security violations detected - Import of external package disallowed`
The package import name is missing from `N8N_RUNNERS_EXTERNAL_ALLOW` in `n8n-task-runners.json`. Add it and run `.\rebuild.ps1`.

### `health-check-server-port conflicts with launcher`
The launcher occupies port 5680. JavaScript runner must use 5681 and Python 5682. Do not change these ports.

### Runners stuck in `Restarting` state
Check logs: `docker logs n8n-runners`. Most common cause is a JSON parse error in `n8n-task-runners.json` (e.g. a number instead of a string for a port value).
