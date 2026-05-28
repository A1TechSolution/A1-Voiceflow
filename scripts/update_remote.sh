#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$SCRIPT_DIR/lib/setup_common.sh"
BOOTSTRAP_LIB=""

if [[ ! -f "$LIB_PATH" ]]; then
    BOOTSTRAP_LIB="$(mktemp)"
    curl -fsSL -o "$BOOTSTRAP_LIB" "https://raw.githubusercontent.com/Ali-Hamas/A1-Voiceflow/main/scripts/lib/setup_common.sh"
    LIB_PATH="$BOOTSTRAP_LIB"
fi

cleanup() {
    if [[ -n "$BOOTSTRAP_LIB" ]]; then
        rm -f "$BOOTSTRAP_LIB"
    fi
}
trap cleanup EXIT

# shellcheck disable=SC1090
. "$LIB_PATH"

REPO="Ali-Hamas/A1-Voiceflow"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  A1 Voiceflow Remote Update                        ║"
echo "║  Refresh deployment files and validate runtime config        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

[[ -f docker-compose.yaml ]] || a1-voiceflow_fail "docker-compose.yaml not found in $(pwd)"
[[ -f .env ]] || a1-voiceflow_fail ".env not found in $(pwd)"

if [[ -f docker-compose.override.yaml ]]; then
    echo -e "${YELLOW}Build-mode install detected (docker-compose.override.yaml present).${NC}"
    echo ""
    echo -e "${YELLOW}This script is for prebuilt installs only. For build mode, update via git:${NC}"
    echo ""
    echo -e "  ${BLUE}git fetch${NC}"
    echo -e "  ${BLUE}git checkout <tag>      # or: git pull${NC}"
    echo -e "  ${BLUE}git submodule update --init --recursive${NC}"
    echo -e "  ${BLUE}./remote_up.sh --build${NC}"
    echo ""
    echo -e "${YELLOW}See https://voiceflow-docs.a1techsolution.com/deployment/update#updating-a-source-build${NC}"
    exit 1
fi

_caller_FASTAPI_WORKERS="${FASTAPI_WORKERS:-}"
_caller_TARGET_VERSION="${TARGET_VERSION:-}"

DOGRAH_DEPLOY_PROJECT_DIR="$(pwd)"
a1-voiceflow_load_env_file .env

[[ -n "${TURN_SECRET:-}" ]] || a1-voiceflow_fail "TURN_SECRET not found in .env"

if [[ -n "$_caller_FASTAPI_WORKERS" ]]; then
    FASTAPI_WORKERS="$_caller_FASTAPI_WORKERS"
fi

if [[ -z "${FASTAPI_WORKERS:-}" ]]; then
    if [[ -t 0 ]]; then
        echo ""
        echo -e "${YELLOW}FASTAPI_WORKERS not set in .env. Number of uvicorn workers nginx will load-balance:${NC}"
        read -p "[4]: " FASTAPI_WORKERS
        FASTAPI_WORKERS="${FASTAPI_WORKERS:-4}"
    else
        FASTAPI_WORKERS="4"
    fi
fi

[[ "$FASTAPI_WORKERS" =~ ^[1-9][0-9]*$ ]] || a1-voiceflow_fail "FASTAPI_WORKERS must be a positive integer (got: $FASTAPI_WORKERS)"

TARGET_VERSION="${_caller_TARGET_VERSION:-${TARGET_VERSION:-}}"

if [[ -z "$TARGET_VERSION" ]]; then
    a1-voiceflow_info "Fetching latest release tag from GitHub..."
    LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | grep -E '"tag_name":' | head -1 \
        | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || true)

    if [[ -z "$LATEST_TAG" ]]; then
        a1-voiceflow_warn "Could not auto-discover latest tag - defaulting to 'main'."
        LATEST_TAG="main"
    fi

    if [[ -t 0 ]]; then
        echo ""
        echo -e "${YELLOW}Target version. Accepted forms: bare semver (1.28.0), v-prefixed (v1.28.0),${NC}"
        echo -e "${YELLOW}full git tag (a1-voiceflow-v1.28.0), or 'main' for bleeding edge.${NC}"
        read -p "[$LATEST_TAG]: " TARGET_VERSION
        TARGET_VERSION="${TARGET_VERSION:-$LATEST_TAG}"
    else
        TARGET_VERSION="$LATEST_TAG"
    fi
fi

if [[ "$TARGET_VERSION" == "latest" ]]; then
    TARGET_VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | grep -E '"tag_name":' | head -1 \
        | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || true)
    [[ -n "$TARGET_VERSION" ]] || a1-voiceflow_fail "could not resolve 'latest' to a release tag"
fi

TRY_TAGS=("$TARGET_VERSION")
case "$TARGET_VERSION" in
    main|HEAD)
        ;;
    a1-voiceflow-*)
        ;;
    v*)
        TRY_TAGS+=("a1-voiceflow-$TARGET_VERSION")
        ;;
    *)
        TRY_TAGS+=("a1-voiceflow-v$TARGET_VERSION" "v$TARGET_VERSION" "a1-voiceflow-$TARGET_VERSION")
        ;;
esac

a1-voiceflow_info "Validating target version: $TARGET_VERSION..."
RESOLVED_TAG=""
for tag in "${TRY_TAGS[@]}"; do
    if curl -fsI "https://raw.githubusercontent.com/$REPO/$tag/docker-compose.yaml" >/dev/null 2>&1; then
        RESOLVED_TAG="$tag"
        break
    fi
done

[[ -n "$RESOLVED_TAG" ]] || a1-voiceflow_fail "could not find a git tag matching '$TARGET_VERSION'"

if [[ "$RESOLVED_TAG" != "$TARGET_VERSION" ]]; then
    a1-voiceflow_success "✓ Resolved '$TARGET_VERSION' to git tag '$RESOLVED_TAG'"
fi

TARGET_VERSION="$RESOLVED_TAG"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$TARGET_VERSION"
IMAGE_TAG=""

case "$TARGET_VERSION" in
    a1-voiceflow-v*) IMAGE_TAG="${TARGET_VERSION#a1-voiceflow-v}" ;;
    v*) IMAGE_TAG="${TARGET_VERSION#v}" ;;
    main|HEAD) IMAGE_TAG="" ;;
    *) [[ "$TARGET_VERSION" =~ ^[0-9] ]] && IMAGE_TAG="$TARGET_VERSION" ;;
esac

if [[ -n "$IMAGE_TAG" ]]; then
    if curl -fsI "https://hub.docker.com/v2/repositories/a1-voiceflowai/a1-voiceflow-api/tags/$IMAGE_TAG/" >/dev/null 2>&1; then
        a1-voiceflow_success "✓ Image tag :$IMAGE_TAG found on Docker Hub"
    else
        a1-voiceflow_warn "Warning: image tag :$IMAGE_TAG not found on Docker Hub - leaving images at :latest"
        IMAGE_TAG=""
    fi
fi

echo ""
echo -e "${GREEN}Update plan:${NC}"
echo -e "  Server IP:        ${BLUE}$(a1-voiceflow_infer_server_ip "$(pwd)" || echo "unknown")${NC}"
echo -e "  Target version:   ${BLUE}$TARGET_VERSION${NC}"
echo -e "  FastAPI workers:  ${BLUE}$FASTAPI_WORKERS${NC}  (ports 8000..$((8000 + FASTAPI_WORKERS - 1)))"
echo ""
echo -e "${YELLOW}Files that will be replaced (backups saved with suffix .bak.$TIMESTAMP):${NC}"
echo "  - docker-compose.yaml   (pulled from GitHub at $TARGET_VERSION)"
echo "  - remote_up.sh          (startup wrapper / preflight)"
echo "  - scripts/run_a1-voiceflow_init.sh"
echo "  - scripts/lib/setup_common.sh"
echo "  - deploy/templates/*.template"
echo "  - .env                  (canonical remote keys synchronized)"
echo "  - legacy nginx.conf / turnserver.conf backups will be kept if those files still exist"
echo ""

if [[ -t 0 && "${DOGRAH_UPDATE_YES:-}" != "1" ]]; then
    read -p "Proceed? [y/N]: " confirm
    if ! [[ "$confirm" =~ ^[Yy] ]]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}[1/3] Backing up existing files...${NC}"
for f in \
    docker-compose.yaml \
    nginx.conf \
    turnserver.conf \
    .env \
    remote_up.sh \
    scripts/run_a1-voiceflow_init.sh \
    scripts/lib/setup_common.sh \
    deploy/templates/nginx.remote.conf.template \
    deploy/templates/turnserver.remote.conf.template
do
    if [[ -f "$f" ]]; then
        mkdir -p "$(dirname "$f")"
        cp -p "$f" "$f.bak.$TIMESTAMP"
        echo -e "  ${GREEN}✓ $f → $f.bak.$TIMESTAMP${NC}"
    fi
done

echo -e "${BLUE}[2/3] Downloading deployment bundle at $TARGET_VERSION...${NC}"
curl -fsSL -o docker-compose.yaml "$RAW_BASE/docker-compose.yaml"
a1-voiceflow_download_remote_support_bundle "$(pwd)" "$TARGET_VERSION"
rm -f nginx.conf turnserver.conf

if [[ -n "$IMAGE_TAG" ]]; then
    sed -i.tmp -E "s#(a1-voiceflow-(api|ui)):latest#\1:$IMAGE_TAG#g" docker-compose.yaml
    rm -f docker-compose.yaml.tmp
    a1-voiceflow_success "✓ docker-compose.yaml updated; images pinned to :$IMAGE_TAG"
else
    a1-voiceflow_success "✓ docker-compose.yaml updated (image tags left at :latest)"
fi

echo -e "${BLUE}[3/3] Synchronizing environment and validating init-based remote config...${NC}"
a1-voiceflow_set_env_key .env FASTAPI_WORKERS "$FASTAPI_WORKERS"
a1-voiceflow_prepare_remote_install "$(pwd)"
docker compose config -q
a1-voiceflow_success "✓ Remote init configuration validated"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   Update Prepared!                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Backups: ${BLUE}*.bak.$TIMESTAMP${NC}"
echo ""
echo -e "${YELLOW}To apply, restart through the validated wrapper:${NC}"
echo ""
echo -e "  ${BLUE}./remote_up.sh${NC}"
echo ""
echo -e "${YELLOW}To roll back, restore the backups and re-run the wrapper:${NC}"
echo ""
echo -e "  ${BLUE}for f in docker-compose.yaml nginx.conf turnserver.conf .env remote_up.sh scripts/run_a1-voiceflow_init.sh scripts/lib/setup_common.sh deploy/templates/nginx.remote.conf.template deploy/templates/turnserver.remote.conf.template; do${NC}"
echo -e "  ${BLUE}  [[ -f \"\$f.bak.$TIMESTAMP\" ]] && cp \"\$f.bak.$TIMESTAMP\" \"\$f\"${NC}"
echo -e "  ${BLUE}done${NC}"
echo -e "  ${BLUE}./remote_up.sh${NC}"
echo ""
