# Logging Configuration File

## Overview

The application supports logging configuration via a `logging.ini` file located in the `src/` directory. This allows you to configure logging behavior without modifying code.

## Configuration File Location

- **Default**: `src/logging.ini`
- **Custom**: Can be specified via `LOG_CONFIG_FILE` environment variable

## File Format

The `logging.ini` file uses Python's standard INI format for logging configuration:

```ini
[loggers]
keys=root

[handlers]
keys=consoleHandler,fileHandler,errorFileHandler

[formatters]
keys=simpleFormatter,detailedFormatter

[logger_root]
level=INFO
handlers=consoleHandler,fileHandler,errorFileHandler

[handler_consoleHandler]
class=StreamHandler
level=INFO
formatter=simpleFormatter
args=()

[handler_fileHandler]
class=RotatingFileHandler
level=INFO
formatter=detailedFormatter
args=('logs/bedrock-chatbot.log', 'a', 10485760, 5)

[handler_errorFileHandler]
class=RotatingFileHandler
level=ERROR
formatter=detailedFormatter
args=('logs/bedrock-chatbot-errors.log', 'a', 10485760, 5)

[formatter_simpleFormatter]
format=%(asctime)s - %(levelname)s - %(message)s
datefmt=%Y-%m-%d %H:%M:%S

[formatter_detailedFormatter]
format=%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s
datefmt=%Y-%m-%d %H:%M:%S
```

## Configuration Sections

### [loggers]
Defines which loggers are configured. Typically just `root`.

### [handlers]
Lists all handler names (consoleHandler, fileHandler, errorFileHandler).

### [formatters]
Lists all formatter names (simpleFormatter, detailedFormatter).

### [logger_root]
Root logger configuration:
- `level`: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `handlers`: Comma-separated list of handler names

### [handler_*]
Handler configurations:
- `class`: Handler class name (StreamHandler, RotatingFileHandler)
- `level`: Minimum log level for this handler
- `formatter`: Formatter to use
- `args`: Tuple of arguments for handler constructor

**Handler Args:**
- `StreamHandler`: `()` (uses stderr by default, stdout if configured)
- `RotatingFileHandler`: `('path/to/file.log', 'a', maxBytes, backupCount)`
  - Example: `('logs/app.log', 'a', 10485760, 5)` = 10MB files, 5 backups

### [formatter_*]
Formatter configurations:
- `format`: Log message format string
- `datefmt`: Date/time format

## Environment Variable Overrides

The following environment variables can override config file settings:

- `LOG_LEVEL`: Overrides logger level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `LOG_TO_FILE`: Controls file logging (true/false)
  - `true`: Use file handlers (default)
  - `false`: Only console/stdout logging
- `LOG_CONFIG_FILE`: Path to custom logging config file

## Examples

### Change Log Level to DEBUG
```ini
[logger_root]
level=DEBUG
```

Or via environment variable:
```bash
export LOG_LEVEL=DEBUG
```

### Disable File Logging (stdout only)
```bash
export LOG_TO_FILE=false
```

### Custom Log Format
```ini
[formatter_detailedFormatter]
format=%(asctime)s [%(levelname)8s] %(name)s:%(lineno)d - %(message)s
datefmt=%Y-%m-%d %H:%M:%S
```

### Change File Rotation Size
```ini
[handler_fileHandler]
args=('logs/bedrock-chatbot.log', 'a', 52428800, 10)
```
This sets 50MB files with 10 backups.

## How It Works

1. Application starts and calls `setup_logging()`
2. Looks for `logging.ini` in `src/` directory (or custom path)
3. Reads and parses the INI file
4. Applies environment variable overrides
5. Configures logging handlers and formatters
6. Falls back to programmatic configuration if file is missing or invalid

## Fallback Behavior

If `logging.ini` is not found or cannot be parsed:
- Falls back to programmatic configuration
- Uses environment variables for settings
- Logs a warning to stderr

## Best Practices

1. **Version Control**: Commit `logging.ini` to version control
2. **Environment-Specific**: Use environment variables for environment-specific overrides
3. **File Logging**: Enable file logging in production, disable in containers
4. **Rotation**: Configure appropriate file sizes and backup counts
5. **Formats**: Use detailed format for files, simple for console

## File Structure

```
src/
├── logging.ini          # Logging configuration file
├── config/
│   └── logging_config.py  # Logging setup code
└── logs/                # Log files (created automatically)
    ├── bedrock-chatbot.log
    └── bedrock-chatbot-errors.log
```

