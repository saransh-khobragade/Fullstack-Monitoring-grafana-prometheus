#!/bin/bash

# Docker build script for the User Management application

# Available services
AVAILABLE_SERVICES=(
  "frontend" "backend" "postgres" "pgadmin"
  # Observability stack
  "prometheus" "grafana" "loki" "promtail" "tempo" "pyroscope" "otel-collector" "postgres-exporter"
  # Group alias (expands later)
  "monitoring"
)

# Ensure lockfiles are up-to-date before docker builds (avoids --frozen-lockfile errors)
preinstall_if_needed() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        return 0
    fi
    if [ -f "$dir/package.json" ]; then
        # If yarn.lock missing or package.json newer than yarn.lock, run yarn install
        if [ ! -f "$dir/yarn.lock" ] || [ "$dir/package.json" -nt "$dir/yarn.lock" ]; then
            echo "📦 Running yarn install in $dir (updating lockfile)..."
            (cd "$dir" && yarn install --no-progress) || {
                echo "❌ yarn install failed in $dir"; exit 1;
            }
        fi
    fi
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [SERVICE1] [SERVICE2] ... [OPTIONS]"
    echo ""
    echo "Services:"
    echo "  frontend   - React frontend with Nginx"
    echo "  backend    - NestJS API server"
    echo "  postgres   - PostgreSQL database"
    echo "  pgadmin    - PgAdmin database management"
    echo "  monitoring - Essential monitoring (Prometheus + Grafana only)"
    echo "  all        - Build all services"
    echo ""
    echo "Options:"
    echo "  --no-cache    Build without using cache"
    echo "  --logs        Show logs after starting"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive menu"
    echo "  $0 frontend backend   # Build only frontend and backend"
    echo "  $0 backend --no-cache # Build backend without cache"
    echo "  $0 all --logs         # Build all and show logs"
}

# Function to check if service is valid
is_valid_service() {
    local service=$1
    if [[ "$service" == "all" ]]; then
        return 0
    fi
    for valid_service in "${AVAILABLE_SERVICES[@]}"; do
        if [[ "$valid_service" == "$service" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to show interactive menu
show_interactive_menu() {
    echo "Select service to build:"
    echo "1) frontend"
    echo "2) backend" 
    echo "3) postgres"
    echo "4) pgadmin"
    echo "5) monitoring (Prometheus, Grafana, Loki, Promtail, Tempo, Pyroscope, OTel Collector, Postgres Exporter)"
    echo "6) postgres-exporter"
    echo "7) all"
    echo ""
    
    read -p "Choice (1-6): " choice
    
    case $choice in
        1)
            SERVICES_TO_BUILD=("frontend")
            ;;
        2)
            SERVICES_TO_BUILD=("backend")
            ;;
        3)
            SERVICES_TO_BUILD=("postgres")
            ;;
        4)
            SERVICES_TO_BUILD=("pgadmin")
            ;;
        5)
            SERVICES_TO_BUILD=("monitoring")
            ;;
        6)
            SERVICES_TO_BUILD=("postgres-exporter")
            ;;
        7)
            SERVICES_TO_BUILD=("all")
            ;;
        *)
            echo "Invalid option. Building all services."
            SERVICES_TO_BUILD=("all")
            ;;
    esac
}

# Parse command line arguments
SERVICES_TO_BUILD=()
BUILD_OPTIONS=()
SHOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        --no-cache)
            BUILD_OPTIONS+=("--no-cache")
            shift
            ;;
        --logs)
            SHOW_LOGS=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if is_valid_service "$1"; then
                SERVICES_TO_BUILD+=("$1")
            else
                echo "Invalid service: $1"
                echo "Available services: ${AVAILABLE_SERVICES[*]} all"
                exit 1
            fi
            shift
            ;;
    esac
done

# Show interactive menu if no services specified
if [ ${#SERVICES_TO_BUILD[@]} -eq 0 ]; then
    show_interactive_menu
fi

# Convert "all" to actual services
if [[ " ${SERVICES_TO_BUILD[*]} " =~ " all " ]]; then
    SERVICES_TO_BUILD=(
      frontend backend postgres pgadmin
      prometheus grafana loki promtail tempo pyroscope otel-collector postgres-exporter
    )
fi

# Expand monitoring to individual services
if [[ " ${SERVICES_TO_BUILD[*]} " =~ " monitoring " ]]; then
    # Remove monitoring token and add full observability stack
    SERVICES_TO_BUILD=(${SERVICES_TO_BUILD[@]/monitoring})
    SERVICES_TO_BUILD+=(prometheus grafana loki promtail tempo pyroscope otel-collector postgres-exporter)
fi

echo "Building services: ${SERVICES_TO_BUILD[*]}"

# Build and start services
# Pre-install to avoid docker --frozen-lockfile failures
if [[ " ${SERVICES_TO_BUILD[*]} " =~ " backend " ]] || [[ " ${SERVICES_TO_BUILD[*]} " =~ " all " ]]; then
    preinstall_if_needed "backend"
    echo "🔧 Building backend locally (to update dist/ for mounted volume)..."
    (cd backend && yarn build) || { echo "❌ Backend build failed"; exit 1; }
fi
if [[ " ${SERVICES_TO_BUILD[*]} " =~ " frontend " ]] || [[ " ${SERVICES_TO_BUILD[*]} " =~ " all " ]]; then
    preinstall_if_needed "frontend"
fi

BUILD_CMD="docker-compose up --build -d"

# Add build options
for option in "${BUILD_OPTIONS[@]}"; do
    BUILD_CMD+=" $option"
done

# Add specific services
for service in "${SERVICES_TO_BUILD[@]}"; do
    BUILD_CMD+=" $service"
done

echo "Executing: $BUILD_CMD"
eval $BUILD_CMD

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Services started successfully!"
echo ""
echo "Frontend:   http://localhost:3000"
echo "Backend API: http://localhost:8080"
echo "Grafana:    http://localhost:3001"
echo "Prometheus: http://localhost:9090"
echo "Pyroscope:  http://localhost:4040"
echo "PgAdmin:    http://localhost:5050"
echo ""

# Show logs if requested
if [ "$SHOW_LOGS" = true ]; then
    echo "Showing logs..."
    if [ ${#SERVICES_TO_BUILD[@]} -eq ${#AVAILABLE_SERVICES[@]} ]; then
        docker-compose logs -f
    else
        docker-compose logs -f "${SERVICES_TO_BUILD[@]}"
    fi
fi