# KISS-Claw Test Scenarios

This directory contains scenario definitions for testing the complete KISS-Claw orchestration loop: orchestrator → executor → verificator → improver.

## Directory Structure

```
tests/scenarios/
├── schema.json              # JSON Schema for scenario validation
├── hello-world/             # Example scenario
│   ├── scenario.yaml        # Scenario definition
│   └── expected/
│       └── hello.sh.gold    # Golden reference output
└── README.md                # This file
```

## Writing a Scenario

Each scenario is a directory containing:

1. **scenario.yaml** - The scenario definition file
2. **expected/** - Directory containing golden reference files for output validation

### scenario.yaml Format

A scenario definition uses YAML and contains the following fields:

```yaml
name: unique-scenario-name                    # Required: kebab-case identifier
description: |                                # Required: Human-readable description
  Multi-line description of what this tests.

request: |                                    # Required: The orchestrator request
  What should the system create or do?

expected_outputs:                             # Required: Expected output files
  - file: output-filename.ext                 # Required: Output file path
    content_match: 'regex.*pattern'           # Optional: Regex to match file content
    must_exist: true                          # Optional: File must exist (default: true)
    is_executable: true                       # Optional: File must be executable
    golden_file: expected/ref.gold            # Optional: Path to golden reference

timeout: 300                                  # Optional: Timeout in seconds (default: 300)

tags:                                         # Optional: Categorization tags
  - basic
  - orchestrator
  - integration

environment:                                  # Optional: Environment variables
  VAR_NAME: value

setup:                                        # Optional: Setup before scenario
  fixtures:
    - path: file/to/create
      content: |
        File content here
  scripts:
    - "echo 'Setup script'"

teardown:                                     # Optional: Cleanup after scenario
  cleanup_files:
    - file/to/remove
    - dir/to/remove
  scripts:
    - "echo 'Cleanup script'"
```

## Tag Categories

Valid tags for organizing scenarios:

- **basic** - Simple, foundational tests
- **advanced** - Complex scenarios
- **orchestrator** - Tests the orchestrator component
- **executor** - Tests the executor component
- **verificator** - Tests the verificator component
- **improver** - Tests the improver component
- **integration** - Full end-to-end integration tests
- **edge-case** - Edge cases and boundary conditions
- **performance** - Performance and stress tests
- **error-handling** - Error conditions and recovery

## Output Validation

### content_match (Regex)

Use regex patterns to validate file content. Examples:

```yaml
content_match: 'echo.*Hello.*World'    # Must contain echo and message
content_match: '#!/bin/bash'           # Must start with shebang
content_match: '^\s*function\s+\w+\(' # Must contain function definition
```

### is_executable

If `is_executable: true`, the file must have executable permissions (e.g., bash scripts).

### golden_file

If specified, the actual output is compared against the golden reference file. The golden file should be stored in `expected/` subdirectory using `.gold` extension.

Example:
```yaml
expected_outputs:
  - file: hello.sh
    golden_file: expected/hello.sh.gold
```

## Example Scenario

### hello-world/scenario.yaml

```yaml
name: hello-world
description: |
  Create a simple bash script that outputs "Hello, World!".
  Validates full orchestrator → executor → verificator → improver loop.

request: |
  Create a bash script named "hello.sh" that outputs "Hello, World!"
  when executed. The script should be executable and follow bash best practices.

expected_outputs:
  - file: hello.sh
    content_match: 'echo.*Hello.*World'
    must_exist: true
    is_executable: true
    golden_file: expected/hello.sh.gold

timeout: 300

tags:
  - basic
  - orchestrator
  - integration
```

### hello-world/expected/hello.sh.gold

```bash
#!/bin/bash
echo "Hello, World!"
```

## Running Scenarios

Scenarios are executed by the test framework. Each scenario:

1. Creates an isolated working directory
2. Executes setup actions (fixtures, scripts)
3. Sends the `request` to the orchestrator
4. Validates outputs against `expected_outputs`
5. Executes teardown actions

## Best Practices

1. **Keep scenarios focused** - Each scenario should test one primary component or workflow
2. **Use descriptive requests** - The request field should be clear and self-contained
3. **Include golden files** - For critical outputs, provide golden reference files
4. **Minimal setup** - Only create fixtures necessary for the test
5. **Clean up properly** - Always define teardown to remove temporary files
6. **Tag appropriately** - Use tags to enable filtering and organization
7. **Realistic timeouts** - Set reasonable timeout values for your scenario

## Schema Validation

All scenario.yaml files are validated against `schema.json`. To validate:

```bash
# Validate a single scenario (if using a validator tool)
jsonschema -i tests/scenarios/hello-world/scenario.yaml tests/scenarios/schema.json
```

The schema is located at: `/home/omc/workspace/kiss-claw/tests/scenarios/schema.json`
