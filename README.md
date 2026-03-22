# Matrix ↔ Discord bridge starter

This repository is a deployment starter for running a Matrix/Discord bridge with [`t2bot/matrix-appservice-discord`](https://github.com/t2bot/matrix-appservice-discord).

It gives you:

- a `docker-compose.yml` that runs the bridge with persistent storage;
- a sample bridge config wired for environment-variable substitution;
- a bootstrap script that generates a Synapse registration file; and
- a setup guide for creating the Discord bot and connecting it to your Matrix homeserver.

## Prerequisites

Before starting, make sure you have:

1. a Matrix homeserver with appservice support enabled (Synapse is the most common option);
2. a public DNS name and TLS certificate for the homeserver and bridge-facing URLs;
3. Docker and Docker Compose;
4. a Discord server where you can install a bot; and
5. a Discord application + bot token from the Discord developer portal.

> The upstream bridge documentation notes that `domain` and `homeserverUrl` should use your public hostname, not localhost, because webhook/avatar handling depends on publicly resolvable URLs.

## Repository layout

- `docker-compose.yml` – bridge container definition.
- `.env.example` – environment variables you should customize.
- `config/config.sample.yaml` – sample bridge config used by the container.
- `scripts/generate-registration.sh` – generates `data/discord-registration.yaml` using the official bridge image.

## Quick start

If you already know how you want to deploy the stack, the shortest path is:

1. Copy `.env.example` to `.env`.
2. Fill in your Matrix and Discord values.
3. Run `./scripts/generate-registration.sh`.
4. Copy `data/discord-registration.yaml` into Synapse and register it in `homeserver.yaml`.
5. Start the container with `docker compose up -d`.
6. Watch logs with `docker compose logs -f matrix-discord-bridge`.

The detailed workflows below walk through the same process in a production-friendly order.

## Step 1: Get the files onto the machine that will run the bridge

Choose a directory on the Docker host where you want to keep the bridge files. In the examples below, the bridge lives in `/opt/matrix-discord-bridge`.

### Option A: Clone the repository with Git

```bash
mkdir -p /opt/matrix-discord-bridge
cd /opt/matrix-discord-bridge
git clone <your-repo-url> .
```

### Option B: Copy the files manually

If you are not using Git on the server, create the folders yourself and copy these files into place:

```text
/opt/matrix-discord-bridge/
├── .env.example
├── docker-compose.yml
├── config/
│   └── config.sample.yaml
└── scripts/
    └── generate-registration.sh
```

Ways to copy the files include:

- `scp` from your workstation to the server;
- uploading them in your cloud provider's file manager;
- a Portainer stack created from a Git repository; or
- copying and pasting file contents into Portainer's web editor.

If you manually create the files on Linux, make the helper script executable:

```bash
chmod +x /opt/matrix-discord-bridge/scripts/generate-registration.sh
```

## Step 2: Prepare the working directory

Change into the project directory and create the runtime files the bridge will use:

```bash
cd /opt/matrix-discord-bridge
cp .env.example .env
mkdir -p data
```

After this step you should have:

```text
/opt/matrix-discord-bridge/
├── .env
├── .env.example
├── data/
├── docker-compose.yml
├── config/
│   └── config.sample.yaml
└── scripts/
    └── generate-registration.sh
```

## Step 3: Fill in the environment file

### Configuration walkthrough

This section is meant to help you decide what every important setting should be before you start the container.

### 1. Pick your Matrix identity values

These settings tell the bridge what Matrix homeserver it belongs to.

#### `MATRIX_DOMAIN`

Set this to the Matrix server name users see in Matrix IDs.

Examples:

- `matrix.example.com`
- `chat.example.org`

If one of your users logs in as `@alice:matrix.example.com`, then `MATRIX_DOMAIN` should usually be `matrix.example.com`.

#### `MATRIX_HOMESERVER_URL`

Set this to the full public base URL of the homeserver.

Examples:

- `https://matrix.example.com`
- `https://chat.example.org`

Use the public HTTPS URL that clients and remote services can reach. Avoid `http://localhost` or a private container hostname unless the bridge is guaranteed to use the exact same internal network path and you understand the tradeoffs.

### 2. Decide how the bridge should appear inside Matrix

These values control the appservice identity and the naming pattern for bridged users and aliases.

#### `APPSERVICE_ID`

A short identifier for the appservice. `discord` is a sensible default and usually does not need to change.

#### `APPSERVICE_BOT_LOCALPART`

The localpart for the bridge bot account, without the leading `@` and without the homeserver name.

Example:

- `discordbot` becomes `@discordbot:matrix.example.com`

#### `APPSERVICE_SENDER_LOCALPART`

The sender localpart written into the registration file. In most setups this should match `APPSERVICE_BOT_LOCALPART`.

#### `APPSERVICE_USER_PREFIX`

The prefix used for virtual Matrix users representing Discord users.

Example:

- `_discord_` may produce users such as `@_discord_someuser:matrix.example.com`

Pick a prefix that is unlikely to clash with real users.

#### `APPSERVICE_ALIAS_PREFIX`

The prefix used for bridged room aliases.

Example:

- `discord` may produce aliases like `#discord_some-channel:matrix.example.com`

### 3. Set the bridge listener values

These settings define where the bridge process listens inside the container.

#### `BRIDGE_PORT`

The host port published by Docker Compose. `9005` is the default in this repo.

#### `BRIDGE_BIND_ADDRESS`

The address the bridge binds to inside the container. Leave this as `0.0.0.0` unless you have a very specific reason to restrict it.

### 4. Create the Discord application and bot credentials

You will need two values from Discord:

#### `DISCORD_BOT_TOKEN`

Get this from the **Bot** page in the Discord developer portal. This is the secret the bridge uses to log into Discord.

#### `DISCORD_CLIENT_ID`

Get this from the application's **General Information** page. This is typically used when generating bot invite links and for bridge-side Discord integration logic.

#### `DISCORD_GUILD_ID`

This starter keeps it as an optional documentation value so you can record the main Discord server you plan to bridge. If you only run one guild, putting the ID here makes operations easier later.

### 5. Generate the secrets used between Synapse and the bridge

These secrets should be long, random, and unique.

#### `APPSERVICE_AS_TOKEN`

Used by the appservice when authenticating to Synapse.

#### `APPSERVICE_HS_TOKEN`

Used by Synapse when sending requests to the bridge.

#### `PROVISIONING_SECRET`

Reserved for provisioning features. Even if you leave provisioning disabled today, set this to a strong value so the file is ready for future use.

A convenient approach is to run this three times:

```bash
openssl rand -hex 32
```

### 6. Review the generated config behavior

When you run `./scripts/generate-registration.sh`, the repo renders `config/config.sample.yaml` into `data/config.yaml` using the values from `.env`.

That means:

- update `.env` first;
- rerun the generation script after changing important environment-driven settings; and
- keep a backup of `.env` and `data/` once the bridge is working.

### Configuration reference

Use this table when filling out `.env`.

| Variable | Required | What it controls | How to choose a value |
| --- | --- | --- | --- |
| `MATRIX_DOMAIN` | Yes | Matrix server name used in user IDs and aliases. | Your public Matrix domain, such as `matrix.example.com`. |
| `MATRIX_HOMESERVER_URL` | Yes | Base URL the bridge uses to talk to Synapse. | The public HTTPS URL of the homeserver. |
| `BRIDGE_PORT` | Usually | Docker-published bridge port. | Keep `9005` unless you have a port conflict. |
| `BRIDGE_BIND_ADDRESS` | Usually | Bind address inside the container. | Keep `0.0.0.0`. |
| `DISCORD_BOT_TOKEN` | Yes | Auth token for the Discord bot. | Copy from the Discord developer portal. |
| `DISCORD_CLIENT_ID` | Yes | Discord application client ID. | Copy from the application details page. |
| `DISCORD_GUILD_ID` | Optional | Administrative reference for your main guild. | Use your Discord server ID if helpful. |
| `APPSERVICE_ID` | Yes | Synapse appservice identifier. | Usually `discord`. |
| `APPSERVICE_BOT_LOCALPART` | Yes | Matrix localpart of the bridge bot account. | Usually `discordbot`. |
| `APPSERVICE_SENDER_LOCALPART` | Yes | Sender localpart written in the registration file. | Usually the same as `APPSERVICE_BOT_LOCALPART`. |
| `APPSERVICE_USER_PREFIX` | Yes | Prefix for virtual Matrix users representing Discord users. | Choose a unique prefix like `_discord_`. |
| `APPSERVICE_ALIAS_PREFIX` | Yes | Prefix for bridged room aliases. | Choose a readable unique value like `discord`. |
| `APPSERVICE_AS_TOKEN` | Yes | Appservice-to-Synapse auth token. | Generate a strong random string. |
| `APPSERVICE_HS_TOKEN` | Yes | Synapse-to-appservice auth token. | Generate a different strong random string. |
| `PROVISIONING_SECRET` | Recommended | Secret for provisioning endpoints. | Generate a third strong random string. |


Open `.env` in your preferred editor and replace every placeholder with real values.

```bash
nano /opt/matrix-discord-bridge/.env
```

### Minimum values you should set

- `MATRIX_DOMAIN` – the public Matrix server name, such as `matrix.example.com`.
- `MATRIX_HOMESERVER_URL` – the public HTTPS URL of the homeserver, such as `https://matrix.example.com`.
- `DISCORD_BOT_TOKEN` – your Discord bot token.
- `DISCORD_CLIENT_ID` – your Discord application client ID.
- `APPSERVICE_AS_TOKEN` – a long random secret for the appservice.
- `APPSERVICE_HS_TOKEN` – another long random secret for Synapse-to-bridge auth.
- `PROVISIONING_SECRET` – a third random secret if you later enable provisioning.

### Suggested way to generate secrets

Use OpenSSL if it is available:

```bash
openssl rand -hex 32
```

Run it once for each secret and paste the results into `.env`.

## Step 4: Create the Discord bot

1. Open the Discord developer portal and create a new application.
2. Add a bot user to the application.
3. Enable the permissions your bridge needs in Discord, especially:
   - View Channels
   - Send Messages
   - Manage Webhooks
   - Embed Links
   - Attach Files
   - Read Message History
4. Copy the bot token into `.env` as `DISCORD_BOT_TOKEN`.
5. Copy the application client ID into `.env` as `DISCORD_CLIENT_ID`.
6. Invite the bot to your Discord server.

You can build an invite URL with this pattern:

```text
https://discord.com/oauth2/authorize?client_id=YOUR_CLIENT_ID&scope=bot&permissions=536879168
```

Adjust permissions if your server needs a stricter profile.

## Step 5: Generate the Synapse appservice registration

The bridge must create a registration file before Synapse can trust it.

From the project directory, run:

```bash
cd /opt/matrix-discord-bridge
./scripts/generate-registration.sh
```

What this script does:

1. loads values from `.env`;
2. checks that `envsubst` is installed;
3. checks that Docker is installed;
4. renders `config/config.sample.yaml` into `data/config.yaml`; and
5. runs the official bridge image to generate `data/discord-registration.yaml`.

### If `envsubst` is missing

Install the `gettext` package, because `envsubst` ships with it on most Linux distributions.

Examples:

```bash
# Debian/Ubuntu
apt-get update && apt-get install -y gettext

# RHEL/Rocky/AlmaLinux
sudo dnf install -y gettext
```

## Step 6: Register the bridge with Synapse

Copy `data/discord-registration.yaml` from the Docker host to the machine that runs Synapse if they are different servers.

Example using `scp`:

```bash
scp /opt/matrix-discord-bridge/data/discord-registration.yaml user@synapse-host:/etc/matrix-synapse/discord-registration.yaml
```

Then add the registration file path to `app_service_config_files` in Synapse's `homeserver.yaml`:

```yaml
app_service_config_files:
  - /etc/matrix-synapse/discord-registration.yaml
```

Restart Synapse so the appservice registration is loaded.

## Step 7A: Deploy with Docker Compose from the CLI

This is the most direct way to launch the bridge.

### Start the service

```bash
cd /opt/matrix-discord-bridge
docker compose up -d
```

### Confirm the container is running

```bash
docker compose ps
docker compose logs -f matrix-discord-bridge
```

### Stop, restart, and update later

```bash
# Stop
docker compose down

# Restart after config changes
docker compose up -d

# Pull a newer image and redeploy
docker compose pull
docker compose up -d
```

## Step 7B: Deploy with Portainer

If you prefer a web UI, Portainer can deploy the exact same stack.

### Portainer deployment method 1: Use a Git-backed stack

This is the cleanest option if this repository lives in Git.

1. Log in to Portainer.
2. Open **Stacks**.
3. Click **Add stack**.
4. Give the stack a name such as `matrix-discord-bridge`.
5. Choose **Repository** as the build method.
6. Paste your Git repository URL.
7. If the repo is private, add credentials or a Git token in Portainer.
8. Set the compose path to `docker-compose.yml`.
9. In the environment variables section, add the same values that would normally go into `.env`.
10. Deploy the stack.

### Portainer deployment method 2: Upload or paste the compose file manually

Use this method if the files are only on your local machine.

1. Log in to Portainer.
2. Open **Stacks**.
3. Click **Add stack**.
4. Name it `matrix-discord-bridge`.
5. Choose the **Web editor** option.
6. Paste the contents of `docker-compose.yml` into the editor.
7. Add all required environment variables in the stack environment section.
8. Deploy the stack.

### Important Portainer note about the mounted files

The compose file expects these host paths to exist:

- `./config/config.sample.yaml`
- `./data`

When Portainer deploys a stack, relative bind mounts are interpreted on the Docker host. That means you should make sure the project directory and files already exist on the host before deploying the stack.

A reliable pattern is:

1. SSH into the Docker host.
2. Create `/opt/matrix-discord-bridge`.
3. Copy the repository files into that directory.
4. Generate the registration file there.
5. In Portainer, deploy the stack from that same directory or from Git.

If your Portainer setup makes relative paths awkward, replace the relative mounts in `docker-compose.yml` with absolute host paths, for example:

```yaml
volumes:
  - /opt/matrix-discord-bridge/config/config.sample.yaml:/data/config.yaml:ro
  - /opt/matrix-discord-bridge/data:/data
```

### Managing the running stack in Portainer

After deployment:

1. Open the stack in Portainer.
2. Confirm the `matrix-discord-bridge` container is healthy/running.
3. Open the container logs from Portainer's UI.
4. If you change `.env` or the config file on disk, redeploy the stack.
5. If you update the image tag, pull and redeploy from Portainer.

## Matrix/Synapse setup notes

- The registration file generated by the script is written to `./data/discord-registration.yaml`.
- The rendered bridge config generated by the script is written to `./data/config.yaml`.
- The compose file mounts `./config/config.sample.yaml` into the container at `/data/config.yaml`.
- Persistent bridge data is stored in `./data`.
- If you run Synapse on another machine, copy both the registration file and any referenced URLs carefully so they match the public hostnames clients can reach.

## Bridging a Discord channel

Once the bridge is online and the bot has joined your server:

1. Find the Discord guild ID and channel ID.
2. In Matrix, join a room alias or portal room supported by the bridge configuration.
3. Follow the upstream bridge conventions for portal rooms and provisioning.

Because bridge capabilities can change between upstream releases, check the upstream README and config docs before enabling advanced features such as provisioning, webhooks, or metrics.

## Updating the bridge image

The compose file defaults to the official `halfshot/matrix-appservice-discord:latest` image. To update:

```bash
docker compose pull
docker compose up -d
```

If you prefer pinning a specific release, replace the image tag in `docker-compose.yml`.

## Troubleshooting

### The bot is offline in Discord

- Verify `DISCORD_BOT_TOKEN` is valid.
- Check `docker compose logs -f matrix-discord-bridge` or the Portainer log viewer.
- Make sure the container can reach both Discord and your Matrix homeserver.

### Synapse does not recognize the appservice

- Confirm the registration file path is listed in `app_service_config_files`.
- Restart Synapse after copying the file.
- Ensure the appservice sender localpart does not conflict with an existing account.

### Portainer says the stack deployed but the container exits immediately

- Verify the bind-mounted files exist on the Docker host.
- Confirm `.env` values are set in Portainer if you are not using a host `.env` file.
- Review the container logs in Portainer for YAML parsing or auth errors.

### Media, avatars, or webhooks do not work correctly

- Use public HTTPS URLs for `MATRIX_HOMESERVER_URL` and `MATRIX_DOMAIN`.
- Confirm your reverse proxy and certificates are valid.
- Ensure the bot has `Manage Webhooks` permission in the Discord channel.

## Next steps

- Pin the bridge image to a known-good version.
- Replace sample secrets with production-grade values.
- Back up the `data/` directory.
- Add monitoring using the bridge's metrics support if you run this in production.
- Review the upstream project for feature flags and release notes: <https://github.com/t2bot/matrix-appservice-discord>
