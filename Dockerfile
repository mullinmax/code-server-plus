FROM lscr.io/linuxserver/code-server:latest

# 1. Install dependencies + openssh-client
RUN apt-get update \
    && apt-get install -y \
       apt-transport-https \
       ca-certificates \
       curl \
       gnupg-agent \
       software-properties-common \
       jq \
       dbus \
       policykit-1 \
       openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r systemd-journal || true \
    && useradd -r -g systemd-journal systemd-network || true

# 2. Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Docker Compose
RUN LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name') \
    && curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE}/docker-compose-$(uname -s)-$(uname -m)" \
       -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# 4. Prevent resolv.conf errors
RUN ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || echo "Skipping /etc/resolv.conf setup"

# 5. Create the SSH‐agent entrypoint script
RUN cat << 'EOF' > /usr/local/bin/entrypoint.sh
#!/usr/bin/env sh
set -e

# Start ssh-agent and export environment vars
eval "$(ssh-agent -s)"

# (Optional) Add your private key — remove the '|| true' if you want it to fail if missing
ssh-add /root/.ssh/id_rsa || true

# Hand off to the original init (linuxserver uses /init under the hood)
exec /init "$@"
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

# 6. Use our entrypoint (will still run /init, then CMD from the base image)
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]