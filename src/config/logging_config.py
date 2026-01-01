"""
Logging configuration for the application
"""
import os
import sys
import logging
import logging.config
import logging.handlers
from pathlib import Path


def setup_logging(app_name: str = 'bedrock-chatbot', log_level: str = None, use_file_logging: bool = None, config_file: str = None):
    """
    Set up logging configuration for the application
    
    Args:
        app_name: Application name for log files
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
                   If None, uses LOG_LEVEL env var or defaults to INFO
        use_file_logging: Whether to write logs to files. If None, uses LOG_TO_FILE env var
                         (default: True if env var not set, False if set to 'false')
        config_file: Path to logging configuration file. If None, looks for logging.ini in src directory
    
    Returns:
        Root logger instance
    """
    # Determine log level
    if log_level is None:
        log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    
    level = getattr(logging, log_level, logging.INFO)
    
    # Determine if file logging should be used
    if use_file_logging is None:
        log_to_file = os.getenv('LOG_TO_FILE', 'true').lower() == 'true'
    else:
        log_to_file = use_file_logging
    
    # Find logging config file
    if config_file is None:
        # Check environment variable first
        config_file = os.getenv('LOG_CONFIG_FILE')
        if not config_file:
            # Look for logging.ini in src directory (where this module is)
            src_dir = Path(__file__).parent.parent
            config_file = src_dir / 'logging.ini'
    
    config_file = Path(config_file)
    
    # Try to load from config file if it exists
    if config_file.exists():
        try:
            # Read and modify config file based on environment variables
            import configparser
            config = configparser.ConfigParser()
            config.read(config_file)
            
            # Override log level from environment
            if 'logger_root' in config:
                config['logger_root']['level'] = log_level
            
            # Modify handlers based on file logging preference
            handlers_list = []
            if log_to_file:
                handlers_list = ['consoleHandler', 'fileHandler', 'errorFileHandler']
                # Create logs directory if it doesn't exist
                log_dir = Path('logs')
                log_dir.mkdir(exist_ok=True)
                
                # Update file paths with app_name
                if 'handler_fileHandler' in config:
                    config['handler_fileHandler']['args'] = f"('logs/{app_name}.log', 'a', 10485760, 5)"
                if 'handler_errorFileHandler' in config:
                    config['handler_errorFileHandler']['args'] = f"('logs/{app_name}-errors.log', 'a', 10485760, 5)"
            else:
                handlers_list = ['consoleHandler']
                # Use detailed formatter for console when file logging is disabled
                if 'handler_consoleHandler' in config:
                    config['handler_consoleHandler']['formatter'] = 'detailedFormatter'
            
            # Ensure console handler uses stdout
            if 'handler_consoleHandler' in config:
                # StreamHandler defaults to stderr, but we want stdout
                # This is handled in the handler class itself
                pass
            
            config['logger_root']['handlers'] = ','.join(handlers_list)
            
            # Convert config to dict for dictConfig
            logging_config_dict = _configparser_to_dict(config)
            
            # Apply configuration
            logging.config.dictConfig(logging_config_dict)
            
            root_logger = logging.getLogger()
            root_logger.info(f"Logging configured from file: {config_file}")
            if log_to_file:
                root_logger.info(f"File logging enabled: logs/{app_name}.log")
            else:
                root_logger.info("File logging disabled - logs will only be written to stdout")
            
            # Set logging levels for third-party libraries
            logging.getLogger('boto3').setLevel(logging.WARNING)
            logging.getLogger('botocore').setLevel(logging.WARNING)
            logging.getLogger('urllib3').setLevel(logging.WARNING)
            logging.getLogger('werkzeug').setLevel(logging.INFO)
            
            return root_logger
            
        except Exception as e:
            # Fall back to programmatic configuration if config file fails
            print(f"Warning: Failed to load logging config from {config_file}: {e}", file=sys.stderr)
            print("Falling back to programmatic configuration", file=sys.stderr)
    
    # Fallback: Programmatic configuration (original implementation)
    return _setup_logging_programmatic(app_name, level, log_to_file)


def _configparser_to_dict(config):
    """Convert ConfigParser object to dict for logging.config.dictConfig"""
    config_dict = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {},
        'handlers': {},
        'loggers': {}
    }
    
    # Parse formatters
    if 'formatters' in config:
        for formatter_name in config['formatters'].get('keys', '').split(','):
            formatter_name = formatter_name.strip()
            if formatter_name and formatter_name in config:
                formatter_section = config[formatter_name]
                config_dict['formatters'][formatter_name] = {
                    'format': formatter_section.get('format', '%(message)s'),
                    'datefmt': formatter_section.get('datefmt', '%Y-%m-%d %H:%M:%S')
                }
    
    # Parse handlers
    if 'handlers' in config:
        for handler_name in config['handlers'].get('keys', '').split(','):
            handler_name = handler_name.strip()
            if handler_name and handler_name in config:
                handler_section = config[handler_name]
                handler_class = handler_section.get('class', 'StreamHandler')
                
                # Handle class names with module paths
                if '.' not in handler_class:
                    if handler_class == 'StreamHandler':
                        handler_class = 'logging.StreamHandler'
                    elif handler_class == 'RotatingFileHandler' or handler_class == 'handlers.RotatingFileHandler':
                        handler_class = 'logging.handlers.RotatingFileHandler'
                
                handler_config = {
                    'class': handler_class,
                    'level': handler_section.get('level', 'INFO'),
                    'formatter': handler_section.get('formatter', 'simpleFormatter')
                }
                
                # Parse args
                args_str = handler_section.get('args', '')
                if args_str:
                    try:
                        # Parse args string (e.g., "('logs/app.log', 'a', 10485760, 5)")
                        # Use ast.literal_eval for safe evaluation
                        import ast
                        args_config = ast.literal_eval(args_str)
                        handler_config['args'] = args_config
                    except Exception:
                        # If parsing fails, use empty tuple
                        handler_config['args'] = ()
                else:
                    # For StreamHandler, default to stdout if no args specified
                    if handler_class == 'logging.StreamHandler':
                        handler_config['args'] = (sys.stdout,)
                    else:
                        handler_config['args'] = ()
                
                config_dict['handlers'][handler_name] = handler_config
    
    # Parse loggers
    if 'loggers' in config:
        for logger_name in config['loggers'].get('keys', '').split(','):
            logger_name = logger_name.strip()
            if logger_name and logger_name in config:
                logger_section = config[logger_name]
                handlers = logger_section.get('handlers', '').split(',')
                config_dict['loggers'][logger_name] = {
                    'level': logger_section.get('level', 'INFO'),
                    'handlers': [h.strip() for h in handlers if h.strip()]
                }
    
    return config_dict


def _setup_logging_programmatic(app_name: str, level: int, log_to_file: bool):
    """Fallback programmatic logging configuration"""
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    
    # Remove existing handlers
    root_logger.handlers.clear()
    
    # Create formatters
    detailed_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    simple_formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler (stdout) - always enabled
    console_handler = logging.StreamHandler()
    console_handler.setLevel(level)
    # Use detailed formatter for console if file logging is disabled, simple otherwise
    if not log_to_file:
        console_handler.setFormatter(detailed_formatter)
    else:
        console_handler.setFormatter(simple_formatter)
    root_logger.addHandler(console_handler)
    
    # File handlers - only if file logging is enabled
    if log_to_file:
        # Create logs directory if it doesn't exist
        log_dir = Path('logs')
        log_dir.mkdir(exist_ok=True)
        
        # File handler (all logs)
        file_handler = logging.handlers.RotatingFileHandler(
            log_dir / f'{app_name}.log',
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5
        )
        file_handler.setLevel(level)
        file_handler.setFormatter(detailed_formatter)
        root_logger.addHandler(file_handler)
        
        # Error file handler (errors only)
        error_handler = logging.handlers.RotatingFileHandler(
            log_dir / f'{app_name}-errors.log',
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5
        )
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(detailed_formatter)
        root_logger.addHandler(error_handler)
        
        root_logger.info(f"File logging enabled: logs/{app_name}.log")
    else:
        root_logger.info("File logging disabled - logs will only be written to stdout")
    
    # Set logging levels for third-party libraries
    logging.getLogger('boto3').setLevel(logging.WARNING)
    logging.getLogger('botocore').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('werkzeug').setLevel(logging.INFO)
    
    return root_logger


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance for a module
    
    Args:
        name: Logger name (typically __name__)
    
    Returns:
        Logger instance
    """
    return logging.getLogger(name)

