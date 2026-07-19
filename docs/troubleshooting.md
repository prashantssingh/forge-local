# Troubleshooting

Start with:

```sh
./scripts/check-health.sh
```

The script returns a non-zero status when a required check fails. Use `--with-qdrant` only when the optional memory profile is expected to run.

## Ollama is not installed

Run:

```sh
./scripts/setup-ollama.sh
```

Install native Ollama for macOS from [ollama.com/download/mac](https://ollama.com/download/mac), or use an existing native CLI installation. ForgeLocal intentionally does not install it automatically. Reopen the terminal if the `ollama` command remains unavailable after installation. CLI-only installations are supported by the bootstrap fallback described below.

## Ollama is installed but not responding

Check the API:

```sh
curl -fsS http://127.0.0.1:11434/api/tags
```

Open the Ollama app, or start the server in a separate terminal:

```sh
OLLAMA_CONTEXT_LENGTH=8192 ollama serve
```

If Ollama was installed as a Homebrew CLI without `Ollama.app`, the one-command bootstrap automatically starts this native server in the background. It records:

```text
.forge-local-runtime/ollama.pid
.forge-local-runtime/ollama.log
```

Inspect the log if startup fails:

```sh
tail -n 100 .forge-local-runtime/ollama.log
```

If the port is already in use, an Ollama instance may already be running. Do not start a second server; inspect the existing process and app first.

## Docker is not running

Open Docker Desktop and wait until it reports that the engine is running. Verify:

```sh
docker info
docker compose version
```

The scripts require the Compose v2 form, `docker compose`.

## Docker cannot reach native Ollama

Open WebUI uses `http://host.docker.internal:11434`, not container-local `127.0.0.1`. Verify Ollama on the host first, then test from the running container:

```sh
curl -fsS http://127.0.0.1:11434/api/tags
docker compose exec open-webui curl -fsS http://host.docker.internal:11434/api/tags
```

Check `.env` contains:

```text
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

Then recreate Open WebUI without deleting its volume:

```sh
./scripts/stop-webui.sh
./scripts/start-webui.sh
```

## Open WebUI cannot see models

List installed models:

```sh
ollama list
```

Pull the defaults if missing:

```sh
./scripts/pull-models.sh
```

Then restart Open WebUI and check its logs:

```sh
docker compose logs --tail=100 open-webui
```

Do not add an Ollama container to Compose. Fix the host connection instead.

## Open WebUI is not reachable

Check container and port state:

```sh
docker compose ps
docker compose logs --tail=100 open-webui
```

The default URL is `http://localhost:3000`. If port 3000 is already used, set a different loopback port in `.env`, for example `WEBUI_PORT=3001`, and restart the service.

The first start may take longer while Docker downloads the image. The scaffold does not perform that download during static validation.

## The Mac becomes slow or starts swapping

1. Stop generating and close unused local-model sessions.
2. Check loaded models:

   ```sh
   ollama ps
   ```

3. Switch to the 7B fallback.
4. Reduce prompt size, attached files, and context.
5. Stop optional Qdrant and other unused containers.
6. Watch Activity Monitor's Memory Pressure and Swap Used values.

Sustained swapping makes inference slower and the entire system less stable. A smaller model is the correct fallback, not more concurrent workers.

## Model responses are too slow

- Use `qwen2.5-coder:7b`.
- Ask for one small outcome instead of a repository-wide task.
- Include fewer files in Aider.
- Start a fresh session after summarizing durable context.
- Ensure another model is not still loaded with `ollama ps`.
- Close memory-intensive applications.

The first response after loading a model is normally slower.

## Out-of-memory or model-load failure

Stop the request and use:

```sh
ollama run qwen2.5-coder:7b
```

Do not use `qwen3-coder:30b` on this hardware as a normal fallback; it is larger, not lighter. If an experimental pull consumes disk space, review `ollama list` and the current Ollama documentation before deliberately removing a model.

## Switch Aider to the 7B model

For one launch:

```sh
PRIMARY_MODEL=qwen2.5-coder:7b ./aider/aider-start.sh
```

Or change `PRIMARY_MODEL` in the local `.env`. Keep `OLLAMA_API_BASE` pointed at the native host API.

## Aider is not installed

Follow [Aider's installation guide](https://aider.chat/docs/install.html). A common official installation path is:

```sh
python -m pip install aider-install
aider-install
```

Installing packages requires internet access. Perform it yourself outside an agent run or record explicit approval.

## Aider cannot connect to Ollama

Verify all three layers:

```sh
ollama list
curl -fsS http://127.0.0.1:11434/api/tags
OLLAMA_API_BASE=http://127.0.0.1:11434 aider --model ollama_chat/qwen2.5-coder:14b --help
```

Use `ollama_chat/`, not the Docker-only `host.docker.internal` address. Run `./aider/aider-start.sh` for the preflight checks.

## Why not Ollama in Docker on macOS

Docker Desktop runs Linux containers inside a virtual machine. The native Ollama application is the supported design here because it can use the Apple Silicon acceleration path directly. A containerized Ollama would add a virtualization boundary and is not the default for Metal-accelerated inference.

## Qdrant does not start or respond

Qdrant is optional. Confirm it was explicitly started:

```sh
./scripts/start-webui.sh --with-qdrant
./scripts/check-health.sh --with-qdrant
docker compose --profile memory logs --tail=100 qdrant
```

Its REST endpoint is loopback-only at `http://localhost:6333` by default. No MVP workflow depends on it, so leave it stopped while diagnosing the core stack.

## Agent workflow is stuck

Inspect the run:

```sh
./scripts/agent-status.sh RUN_ID
```

Check:

- Is `STOPPED.md` present?
- Is the plan actually approved?
- Is the Builder on an `agent/<run-id>` branch?
- Is a required human-only action waiting for approval?
- Has the same failure happened three times?
- Is a report missing the exact next action?

Record the blocker in `run-status.md`. Do not grant broader permissions just to make progress.

## Agent changed too many files

Stop immediately:

```sh
./scripts/agent-stop.sh RUN_ID "Changed-file limit exceeded"
git status --short
git diff --stat
git diff
```

Do not let the Builder clean up its own unreviewed scope expansion without a new plan. Decide which changes, if any, belong in a smaller replacement task.

## Recover from a bad agent change

Because implementation happens on a branch, first preserve and inspect evidence:

```sh
git branch --show-current
git status --short
git diff --stat
git diff
```

If the branch should be abandoned, switch back without merging:

```sh
git switch main
git status --short
```

Keep the agent branch until you confirm no useful work needs recovery. If you later decide to delete it, list the exact target first:

```sh
git branch --list 'agent/*'
```

Branch deletion and discarding uncommitted work are destructive human actions. Do not use `git reset --hard`, broad `git clean`, or recursive deletion as routine recovery.

## Run reports contain secrets or large logs

Stop the run and do not commit the material. Remove it from the working tree only after identifying the exact file and deciding whether it exists in Git history. Rotate any exposed credential. The `.gitignore` excludes runtime logs but cannot protect text pasted into tracked Markdown.
