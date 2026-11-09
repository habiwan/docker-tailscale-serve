#!/usr/bin/env bash
# /usr/local/bin/docker-tailscale-serve.sh
# Dynamically syncs 'tailscale serve' rules with running Docker containers.

cleanup() {
    echo "[$(date)] Stopping script, resetting tailscale serve rules..."
    tailscale serve reset
    exit 0
}

# Trap termination signals so it cleans up if systemd stops it
trap cleanup SIGTERM SIGINT

while true; do
    # Ensure docker daemon is running and tailscale is up
    if ! docker info &>/dev/null || ! tailscale status &>/dev/null; then
        sleep 5
        continue
    fi

    # 1. Collect all currently exposed host ports from running docker containers
    active_docker_ports=""
    running_containers=$(docker ps -q)

    for cid in $running_containers; do
        cname=$(docker inspect --format='{{.Name}}' "$cid" | sed 's/^\///')
        ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{range $conf}}{{.HostPort}} {{end}}{{end}}{{end}}' "$cid")

        for hport in $ports; do
            if [ -n "$hport" ] && [ "$hport" != "<nil>" ]; then
                active_docker_ports="$active_docker_ports $hport"

                # Check if this port is already served by tailscale
                if ! tailscale serve status 2>/dev/null | grep -q ":$hport"; then
                    # Determine protocol (HTTPS vs HTTP)
                    # Corrected Tailscale Serve Syntax inside the loop:
                    if [[ "$hport" =~ ^(443|8443|9443)$ ]] || [[ "$cname" =~ (portainer|authentik|vaultwarden|gitea|proxy) && "$hport" =~ ^(443|8443|9443|9000)$ ]]; then
                        echo "[$(date)] Enabling HTTPS serve for $cname on port $hport"
                        tailscale serve --bg --https="$hport" https+insecure://127.0.0.1:"$hport"
                    else
                        echo "[$(date)] Enabling HTTP serve for $cname on port $hport"
                        tailscale serve --bg --https="$hport" "$hport"
                    fi
                fi
            fi
        done
    done

    # 2. Cleanup stale tailscale serve rules whose ports are NO LONGER active in docker
    served_ports=$(tailscale serve status 2>/dev/null | grep -oP 'https://[^ ]+:\K[0-9]+' || true)
    # Also check http served ports if any...

    for sport in $(tailscale serve status 2>/dev/null | grep -oP 'https?://[^ ]+:\K[0-9]+' | sort -u); do
        if ! echo "$active_docker_ports" | grep -qw "$sport"; then
            echo "[$(date)] Container port $sport is no longer active. Removing tailscale serve rule..."
            tailscale serve --https="$sport" off 2>/dev/null || tailscale serve "$sport" off 2>/dev/null
        fi
    done

    sleep 15
done
