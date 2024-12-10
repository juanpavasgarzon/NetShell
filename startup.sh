#!/bin/bash

# startup.sh
#
# Description:
#
#     Creates a new .NET solution with Clean Architecture structure including API, Domain,
#     Application, Infrastructure, Shared, and Tests projects. Also sets up Docker support
#     and project references.
#
# Usage:
#
#     ./startup.sh <project_name> [<project_path>]
#
# Options:
#
#     -h, --help        Show this help message and exit.
#
# Arguments:
#
#     project_name    - Name of the project/solution to create (required).
#     project_path    - Path where the project should be created (optional, defaults to current directory).
#
# Project Structure Created:
#
#     [ProjectName]/
#     ├── [ProjectName].API/            - Web API project.
#     ├── [ProjectName].Domain/         - Domain layer.
#     ├── [ProjectName].Application/    - Application layer.
#     ├── [ProjectName].Infrastructure/ - Infrastructure layer.
#     ├── [ProjectName].Shared/         - Shared components.
#     ├── [ProjectName].Tests/          - Unit tests.
#     ├── docker-compose.yml            - Docker compose configuration.
#     └── Dockerfile                     - Docker build configuration.
#
# Functions:
#
#     print_usage               - Displays usage information.
#     validate_inputs           - Validates command-line arguments.
#     add_rollback_path         - Adds a path to the rollback list for cleanup on failure.
#     rollback                  - Removes created files/directories in case of failure.
#     create_project_structure  - Creates the project directories and .NET projects.
#     add_project_references    - Sets up project references between layers.
#     create_solution_file       - Creates and configures the .NET solution file.
#     create_support_files       - Creates Docker-related configuration files.
#     restore_packages          - Restores NuGet packages for the solution.
#     main                      - Main execution function.
#
# Error Handling:
#
#     - Uses errexit, nounset, and pipefail for strict error checking.
#     - Implements rollback functionality to clean up on failure.
#     - Uses trap to catch errors and trigger rollback.

set -o errexit
set -o nounset
set -o pipefail

# Colors for terminal output
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# Variables to hold project name and path
PROJECT_NAME="${1:-}"
SERVICE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
PROJECT_PATH="${2:-$(pwd)}"
ROLLBACK_PATHS=()

# Prints usage information
function print_usage {
    printf "${GREEN}Usage:${RESET}\n"
    printf "    ./startup.sh <project_name> [<project_path>]\n\n"
    printf "${GREEN}Options:${RESET}\n"
    printf "    -h, --help        Show this help message and exit.\n\n"
    printf "${GREEN}Arguments:${RESET}\n"
    printf "    project_name    - Name of the project/solution to create (required).\n"
    printf "    project_path    - Path where the project should be created (optional, defaults to current directory).\n"
    exit 0
}

# Validates input arguments
function validate_inputs {
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            print_usage
        fi
    done

    if [[ -z "${PROJECT_NAME:-}" ]]; then
        printf "${RED}Error: Project name is required.${RESET}\n"
        print_usage
    fi

}

# Adds a path to the rollback list
function add_rollback_path {
    local path="$1"
    ROLLBACK_PATHS+=("$path")
}

# Rolls back changes by removing created files/directories
function rollback {
    printf "${RED}An error occurred. Rolling back changes...${RESET}\n"
    for path in "${ROLLBACK_PATHS[@]}"; do
        if [[ -e "$path" ]]; then
            printf "${YELLOW}Removing: $path${RESET}\n"
            rm -rf "$path"
        fi
    done
    printf "${GREEN}Rollback completed.${RESET}\n"
}

# Creates project directories and initializes .NET projects
function create_project_structure {
    local base_path="$PROJECT_PATH/$PROJECT_NAME"

    printf "${BLUE}Creating project structure at '$base_path'${RESET}\n"
    mkdir -p "$base_path"
    add_rollback_path "$base_path"
    cd "$base_path"

    local projects=(
        "$PROJECT_NAME.API:webapi"
        "$PROJECT_NAME.Domain:classlib"
        "$PROJECT_NAME.Application:classlib"
        "$PROJECT_NAME.Infrastructure:classlib"
        "$PROJECT_NAME.Shared:classlib"
        "$PROJECT_NAME.Tests:xunit"
    )

    for project in "${projects[@]}"; do
        local name type
        name="${project%%:*}"
        type="${project##*:}"
        printf "${GREEN}Creating %s Layer: %s${RESET}\n" "$type" "$name"
        dotnet new "$type" -o "$name"
        add_rollback_path "$base_path/$name"
    done
}

# Sets up project references between layers
function add_project_references {
    local base_path="$PROJECT_PATH/$PROJECT_NAME"
    printf "\n${BLUE}Adding project references...${RESET}\n"

    dotnet add "$base_path/$PROJECT_NAME.API/$PROJECT_NAME.API.csproj" reference \
        "$base_path/$PROJECT_NAME.Domain/$PROJECT_NAME.Domain.csproj" \
        "$base_path/$PROJECT_NAME.Application/$PROJECT_NAME.Application.csproj" \
        "$base_path/$PROJECT_NAME.Infrastructure/$PROJECT_NAME.Infrastructure.csproj"

    dotnet add "$base_path/$PROJECT_NAME.Application/$PROJECT_NAME.Application.csproj" reference \
        "$base_path/$PROJECT_NAME.Domain/$PROJECT_NAME.Domain.csproj"

    dotnet add "$base_path/$PROJECT_NAME.Infrastructure/$PROJECT_NAME.Infrastructure.csproj" reference \
        "$base_path/$PROJECT_NAME.Domain/$PROJECT_NAME.Domain.csproj"
}

# Creates and configures the solution file
function create_solution_file {
    local solution_path="$PROJECT_PATH/$PROJECT_NAME/$PROJECT_NAME.sln"
    printf "${BLUE}Creating solution file...${RESET}\n"
    dotnet new sln -n "$PROJECT_NAME"
    add_rollback_path "$solution_path"

    local layers=(
        "$PROJECT_NAME.API"
        "$PROJECT_NAME.Domain"
        "$PROJECT_NAME.Application"
        "$PROJECT_NAME.Infrastructure"
        "$PROJECT_NAME.Shared"
        "$PROJECT_NAME.Tests"
    )

    printf "${GREEN}Adding projects to solution${RESET}\n"
    for layer in "${layers[@]}"; do
        dotnet sln "$solution_path" add "$PROJECT_PATH/$PROJECT_NAME/$layer"
    done
}

# Creates Docker-related configuration files
function create_support_files {
    local base_path="$PROJECT_PATH/$PROJECT_NAME"

    printf "\n${BLUE}Creating Docker Compose File...${RESET}\n"
    cat >"$base_path/docker-compose.yml" <<EOF
services:
  $SERVICE_NAME:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${SERVICE_NAME}-container
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    ports:
      - "8000:80"
EOF
    add_rollback_path "$base_path/docker-compose.yml"

    printf "\n${BLUE}Creating Dockerfile...${RESET}\n"
    cat >"$base_path/Dockerfile" <<EOF
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app
COPY . ./
RUN dotnet restore "$PROJECT_NAME.sln"
RUN dotnet publish "$PROJECT_NAME.API/$PROJECT_NAME.API.csproj" -c Release -o /app/out
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build-env /app/out .
EXPOSE 80
ENTRYPOINT ["dotnet", "$PROJECT_NAME.API.dll"]
EOF
    add_rollback_path "$base_path/Dockerfile"
}

# Restores NuGet packages
function restore_packages {
    printf "\n${BLUE}Restoring NuGet packages...${RESET}\n"
    dotnet restore "$PROJECT_PATH/$PROJECT_NAME/$PROJECT_NAME.sln"
}

# Main function to orchestrate script execution
function main {
    trap rollback ERR

    # Validate inputs before proceeding
    validate_inputs "$@"

    # Assign PROJECT_NAME and PROJECT_PATH after validation
    PROJECT_NAME="$1"
    PROJECT_PATH="${2:-$(pwd)}"

    # Execute main script functions
    create_project_structure
    create_solution_file
    add_project_references
    create_support_files
    restore_packages

    printf "${GREEN}Project '%s' created successfully in '%s'${RESET}\n" "$PROJECT_NAME" "$PROJECT_PATH"
}

main "$@"
