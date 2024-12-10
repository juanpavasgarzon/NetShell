
# startup.sh

## Description:

Creates a new .NET solution with Clean Architecture structure including API, Domain,
Application, Infrastructure, Shared, and Tests projects. Also sets up Docker support
and project references.

## Usage:

```bash
./startup.sh <project_name> [<project_path>]
```

### Options:

- `-h, --help`  
  Show this help message and exit.

### Arguments:

- `project_name`  
  Name of the project/solution to create (required).
- `project_path`  
  Path where the project should be created (optional, defaults to current directory).

## Project Structure Created:
```
ProjectName/
├── ProjectName.API/            - Web API project.
├── ProjectName.Domain/         - Domain layer.
├── ProjectName.Application/    - Application layer.
├── ProjectName.Infrastructure/ - Infrastructure layer.
├── ProjectName.Shared/         - Shared components.
├── ProjectName.Tests/          - Unit tests.
├── docker-compose.yml          - Docker compose configuration.
└── Dockerfile                   - Docker build configuration.
```

## Functions:

- **print_usage**  
  Displays usage information.
  
- **validate_inputs**  
  Validates command-line arguments.
  
- **add_rollback_path**  
  Adds a path to the rollback list for cleanup on failure.
  
- **rollback**  
  Removes created files/directories in case of failure.
  
- **create_project_structure**  
  Creates the project directories and .NET projects.
  
- **add_project_references**  
  Sets up project references between layers.
  
- **create_solution_file**  
  Creates and configures the .NET solution file.
  
- **create_support_files**  
  Creates Docker-related configuration files.
  
- **restore_packages**  
  Restores NuGet packages for the solution.
  
- **main**  
  Main execution function.

## Error Handling:
- Uses `errexit`, `nounset`, and `pipefail` for strict error checking.
- Implements rollback functionality to clean up on failure.
- Uses `trap` to catch errors and trigger rollback.
