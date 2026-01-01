"""
Utilities for interacting with AWS Bedrock Knowledge Base
See https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started-api-ex-python.html
    https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started-api-ex-cli.html
    https://docs.aws.amazon.com/bedrock/latest/userguide/service_code_examples_bedrock-runtime_anthropic_claude.html
    https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/bedrock-runtime
"""
import boto3
import json
import uuid
import time
from botocore.exceptions import ClientError
from typing import Dict, List, Optional

try:
    from config.logging_config import get_logger
except ImportError:
    from ..config.logging_config import get_logger

logger = get_logger(__name__)


class BedrockKnowledgeBase:
    """Handles interactions with AWS Bedrock Knowledge Base"""

    def __init__(self, config, prompt_engine=None):
        """
        Initialize Bedrock client and configuration

        Args:
            config: ConfigManager instance
            prompt_engine: Optional PromptEngine instance for advanced prompts
        """
        self.region = config.get('AWS_REGION')
        self.kb_id = config.get('KNOWLEDGE_BASE_ID')
        self.model_id = config.get('MODEL_ID')
        self.s3_bucket = config.get('S3_BUCKET_NAME')
        self.max_tokens = config.get('MAX_TOKENS', 1000)
        self.temperature = config.get('TEMPERATURE', 0.7)

        # See https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started-api-ex-python.html
        # TODO os.environ['AWS_BEARER_TOKEN_BEDROCK'] = "${api-key}"

        self.prompt_engine = prompt_engine

        logger.info(f"Initializing Bedrock Knowledge Base client (region: {self.region}, KB ID: {self.kb_id})")

        # Initialize AWS clients
        try:
            # Check for AWS credentials
            session = boto3.Session()
            credentials = session.get_credentials()
            if credentials is None:
                logger.warning("No AWS credentials found. Please configure AWS credentials using one of:")
                logger.warning("  1. AWS credentials file: ~/.aws/credentials")
                logger.warning("  2. Environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
                logger.warning("  3. IAM role (if running on EC2/ECS/Lambda)")
                logger.warning("  4. AWS SSO: aws sso login")

            self.bedrock_agent = boto3.client('bedrock-agent-runtime', region_name=self.region)
            self.bedrock = boto3.client('bedrock', region_name=self.region)
            self.s3 = boto3.client('s3', region_name=self.region)
            self.bedrock_agent_client = boto3.client('bedrock-agent', region_name=self.region)
            logger.info("AWS Bedrock clients initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize AWS clients: {str(e)}", exc_info=True)
            raise

    def query(self, question: str, session_id: Optional[str] = None,
             conversation_history: Optional[List[Dict]] = None,
             query_type: Optional[str] = None,
             use_advanced_prompts: bool = True) -> Dict:
        """
        Query the Knowledge Base with a question

        Args:
            question: User's question
            session_id: Optional session ID for conversation context
            conversation_history: Previous conversation history for context
            query_type: Type of query (general, technical, summary, comparison)
            use_advanced_prompts: Whether to use advanced prompt engineering

        Returns:
            Dictionary with answer, sources, and metadata
        """
        if not self.kb_id:
            logger.error("Knowledge Base ID not configured")
            raise ValueError("Knowledge Base ID not configured")

        start_time = time.time()
        logger.debug(f"Querying KB: '{question[:100]}...' (session: {session_id[:8] if session_id else 'new'})")

        try:
            # Validate input
            if not question or not isinstance(question, str):
                raise ValueError("Question must be a non-empty string")

            question = question.strip()
            if not question:
                raise ValueError("Question cannot be empty or whitespace only")

            # Validate KB ID
            if not self.kb_id or not isinstance(self.kb_id, str) or not self.kb_id.strip():
                raise ValueError("Knowledge Base ID is not configured or invalid")

            # Validate model ID
            if not self.model_id or not isinstance(self.model_id, str) or not self.model_id.strip():
                raise ValueError("Model ID is not configured or invalid")

            # Enhance query with conversation history if available
            enhanced_question = question  # Already stripped above
            if use_advanced_prompts and self.prompt_engine and conversation_history:
                logger.debug(f"Enhancing query with {len(conversation_history)} previous exchanges")
                enhanced_question = self.prompt_engine.enhance_query(question, conversation_history)
                if not enhanced_question or not isinstance(enhanced_question, str):
                    logger.warning("Enhanced question is invalid, using original question")
                    enhanced_question = question
                enhanced_question = enhanced_question.strip()  # Ensure no leading/trailing whitespace
                if not enhanced_question:
                    logger.warning("Enhanced question is empty after stripping, using original question")
                    enhanced_question = question

            # Detect query type if not provided
            if not query_type and use_advanced_prompts and self.prompt_engine:
                query_type = self.prompt_engine.detect_query_type(question)
                logger.debug(f"Detected query type: {query_type}")

            # Validate session ID format if provided (pattern: [0-9a-zA-Z._:-]+)
            if session_id:
                import re
                if not re.match(r'^[0-9a-zA-Z._:-]+$', session_id):
                    logger.warning(f"Invalid session ID format: {session_id}. Creating new session.")
                    session_id = None

            # Helper function to build retrieveAndGenerateConfiguration
            def build_retrieve_config(model_arn_value):
                """Build retrieveAndGenerateConfiguration for new sessions"""
                return {
                    'type': 'KNOWLEDGE_BASE',
                    'knowledgeBaseConfiguration': {
                        'knowledgeBaseId': str(self.kb_id).strip(),
                        'modelArn': str(model_arn_value).strip(),
                        'retrievalConfiguration': {
                            'vectorSearchConfiguration': {
                                'numberOfResults': 5
                            }
                        },
                        'orchestrationConfiguration': {
                            'promptTemplate': {
                                'textPromptTemplate': """Review the following retrieved documents and prepare a comprehensive context to help answer the user's question. Organize the information logically and include all relevant details.

Retrieved Documents:
$search_results$

User Question:
$query$

Conversation History:
$conversation_history$

Output Format Instructions:
$output_format_instructions$

Organized Context:"""
                            }
                        },
                        'generationConfiguration': {
                            'promptTemplate': {
                                'textPromptTemplate': """Use the following pieces of context to answer the question at the end. If you don't know the answer, just say that you don't know, don't try to make up an answer.

Context:
$search_results$

Question: $query$

Answer:"""
                            }
                        }
                    }
                }

            # Helper function to construct model ARN
            def get_model_arn():
                """Construct foundation model ARN from model_id"""
                if self.model_id.startswith('arn:aws:bedrock:'):
                    if ':inference-profile/' in self.model_id:
                        logger.warning(f"Inference profile ARN provided, but foundation model ARN is required. Will attempt conversion in retry logic.")
                        return self.model_id
                    else:
                        logger.debug(f"Using provided foundation model ARN: {self.model_id}")
                        return self.model_id
                else:
                    # Construct foundation model ARN using the full model ID (including version suffix)
                    # According to foundation-models.txt, the modelArn format is:
                    # arn:aws:bedrock:<region>::foundation-model/<full-model-id>
                    model_arn = f"arn:aws:bedrock:{self.region}::foundation-model/{self.model_id}"
                    logger.debug(f"Constructed foundation model ARN: {model_arn}")
                    return model_arn

            # Prepare the query parameters according to AWS Bedrock API documentation:
            # https://docs.aws.amazon.com/bedrock/latest/APIReference/API_agent-runtime_RetrieveAndGenerate.html
            # Required: input
            # Optional: retrieveAndGenerateConfiguration, sessionConfiguration, sessionId
            params = {
                'input': {
                    'text': enhanced_question
                }
            }

            # Always include retrieveAndGenerateConfiguration for both new and existing sessions
            model_arn = get_model_arn()
            params['retrieveAndGenerateConfiguration'] = build_retrieve_config(model_arn)

            # If sessionId is provided from UI, preserve it and include it in the request
            # This allows continuing the conversation while ensuring configuration is always present
            if session_id:
                params['sessionId'] = session_id
                logger.debug(f"Using session ID from UI: {session_id[:8]}... with retrieveAndGenerateConfiguration")
            else:
                logger.debug(f"Creating new session with model ARN: {model_arn}")

            # Validate parameters structure before API call
            # Required: input must be present
            if 'input' not in params or 'text' not in params['input']:
                raise ValueError("Missing required 'input' parameter with 'text' field")

            # retrieveAndGenerateConfiguration must always be present
            if 'retrieveAndGenerateConfiguration' not in params:
                raise ValueError("Missing required 'retrieveAndGenerateConfiguration'")

            # Query the Knowledge Base
            logger.debug(f"Calling Bedrock retrieve_and_generate API")
            logger.debug(f"Params keys: {list(params.keys())}")
            logger.debug(f"Has sessionId: {'sessionId' in params}")
            logger.debug(f"Has retrieveAndGenerateConfiguration: {'retrieveAndGenerateConfiguration' in params}")
            if 'retrieveAndGenerateConfiguration' in params:
                logger.debug(f"retrieveAndGenerateConfiguration type: {params['retrieveAndGenerateConfiguration'].get('type')}")
                logger.debug(f"KB ID in config: {params['retrieveAndGenerateConfiguration'].get('knowledgeBaseConfiguration', {}).get('knowledgeBaseId')}")
                logger.debug(f"Model ARN in config: {params['retrieveAndGenerateConfiguration'].get('knowledgeBaseConfiguration', {}).get('modelArn')}")
            logger.debug(f"Input text length: {len(params.get('input', {}).get('text', ''))}")
            # Sanitize params for logging (hide full input text)
            sanitized_params = {}
            for k, v in params.items():
                if k == 'input':
                    sanitized_params[k] = {'text': f'[text length: {len(v.get("text", ""))}]'}
                else:
                    sanitized_params[k] = v
            logger.debug(f"Full params structure (sanitized): {json.dumps(sanitized_params, default=str, indent=2)}")

            try:
                # Log exact parameters being sent (for debugging)
                if session_id:
                    logger.debug(f"API call with existing session - params: input (text length: {len(params['input']['text'])}), sessionId: {session_id[:8]}...")
                else:
                    logger.debug(f"API call with new session - params: input (text length: {len(params['input']['text'])}), retrieveAndGenerateConfiguration present")

                response = self.bedrock_agent.retrieve_and_generate(**params)
            except ClientError as e:
                error_code = e.response.get('Error', {}).get('Code', 'Unknown')
                error_message = e.response.get('Error', {}).get('Message', str(e))

                logger.error(f"Bedrock API error: code={error_code}, message={error_message}")


                # If it's a validation error related to model identifier, try alternative model formats
                if (error_code == 'ValidationException' and
                      'retrieveAndGenerateConfiguration' in params):
                    is_model_error = (
                        'invalid' in error_message.lower() or
                        'model' in error_message.lower() or
                        'identifier' in error_message.lower()
                    )

                    if is_model_error:
                        current_model_arn = params['retrieveAndGenerateConfiguration']['knowledgeBaseConfiguration']['modelArn']
                        logger.warning(f"Validation error with model: {current_model_arn}. Error: {error_message}")
                        logger.warning("Trying alternative model identifier formats...")

                        # Try alternative model ARN formats in order of likelihood
                        # Use foundation model ARN format with full model ID (including version suffix)
                        # According to foundation-models.txt, modelArn format is:
                        # arn:aws:bedrock:<region>::foundation-model/<full-model-id>
                        model_arn_attempts = []

                        # Try 1: Foundation model ARN format with full model ID (as per foundation-models.txt)
                        foundation_arn = f"arn:aws:bedrock:{self.region}::foundation-model/{self.model_id}"
                        if foundation_arn != current_model_arn:
                            model_arn_attempts.append(foundation_arn)

                        # Try 2: Alternative Claude 3.5 Sonnet versions (if current model doesn't work)
                        if 'claude-3-5-sonnet' in self.model_id.lower():
                            # Try the older version that supports ON_DEMAND
                            alt_model = 'anthropic.claude-3-5-sonnet-20240620-v1:0'
                            if alt_model != self.model_id:
                                alt_foundation_arn = f"arn:aws:bedrock:{self.region}::foundation-model/{alt_model}"
                                if alt_foundation_arn != current_model_arn and alt_foundation_arn not in model_arn_attempts:
                                    model_arn_attempts.append(alt_foundation_arn)

                        # Try 3: Base model ID without version suffix (fallback)
                        if ':' in self.model_id:
                            base_model_id = self.model_id.split(':')[0]
                            base_foundation_arn = f"arn:aws:bedrock:{self.region}::foundation-model/{base_model_id}"
                            if base_foundation_arn != current_model_arn and base_foundation_arn not in model_arn_attempts:
                                model_arn_attempts.append(base_foundation_arn)

                        # Try each alternative format
                        retry_success = False
                        last_error = None
                        for i, alt_model_arn in enumerate(model_arn_attempts):
                            try:
                                params['retrieveAndGenerateConfiguration']['knowledgeBaseConfiguration']['modelArn'] = alt_model_arn
                                logger.info(f"Retry attempt {i+1}/{len(model_arn_attempts)}: Trying model identifier: {alt_model_arn}")
                                response = self.bedrock_agent.retrieve_and_generate(**params)
                                logger.info(f"✓ Successfully retried with model identifier: {alt_model_arn}")
                                retry_success = True
                                break  # Success, exit retry loop
                            except Exception as retry_e:
                                retry_error_msg = str(retry_e)
                                logger.debug(f"Retry {i+1} failed: {retry_error_msg}")
                                last_error = retry_e

                        if not retry_success:
                            # All retry attempts failed
                            logger.error(f"✗ All {len(model_arn_attempts)} retry attempts failed.")
                            logger.error(f"Original model identifier: {current_model_arn}")
                            logger.error(f"Tried alternatives: {model_arn_attempts}")
                            logger.error(f"Last error: {last_error}", exc_info=True)
                            logger.error(f"Original params: {json.dumps(params, default=str, indent=2)}")
                            raise Exception(f"AWS Error ({error_code}): {error_message}. Tried {len(model_arn_attempts)} alternative model formats, all failed.")
                    else:
                        # Not a model error, raise the original error
                        logger.error(f"Bedrock API call failed. Params: {json.dumps(params, default=str, indent=2)}", exc_info=True)
                        raise Exception(f"AWS Error ({error_code}): {error_message}")
                else:
                    # Not a handled error case, raise the original error
                    logger.error(f"Bedrock API call failed. Params: {json.dumps(params, default=str, indent=2)}", exc_info=True)
                    raise Exception(f"AWS Error ({error_code}): {error_message}")
            except Exception as e:
                logger.error(f"Bedrock API call failed. Params: {json.dumps(params, default=str, indent=2)}", exc_info=True)
                raise

            # Calculate response time
            response_time_ms = int((time.time() - start_time) * 1000)
            logger.info(f"KB query completed in {response_time_ms}ms")

            # Extract answer and sources
            answer = response.get('output', {}).get('text', 'No answer found')
            citations = response.get('citations', [])

            # Format sources with enhanced information
            sources = []
            for citation in citations:
                retrieved_references = citation.get('retrievedReferences', [])
                for ref in retrieved_references:
                    location = ref.get('location', {})
                    s3_location = location.get('s3Location', {})

                    source_info = {
                        'content': ref.get('content', {}).get('text', ''),
                        'location': location,
                        's3_uri': s3_location.get('uri', ''),
                        's3_key': s3_location.get('uri', '').split('/')[-1] if s3_location.get('uri') else '',
                        'score': ref.get('score', 0),
                        'type': ref.get('content', {}).get('type', 'text')
                    }
                    sources.append(source_info)

            # Extract session ID from response
            response_session_id = response.get('sessionId') or params.get('sessionId')

            return {
                'answer': answer,
                'sources': sources,
                'session_id': response_session_id,
                'response_time_ms': response_time_ms,
                'query_type': query_type or 'general',
                'enhanced_question': enhanced_question if enhanced_question != question else None,
                'metadata': {
                    'model': self.model_id,
                    'kb_id': self.kb_id,
                    'sources_count': len(sources),
                    'timestamp': time.time()
                }
            }

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            logger.error(f"AWS Bedrock error ({error_code}): {error_message}")

            # Provide helpful error messages for common authentication issues
            if error_code in ('UnrecognizedClientException', 'InvalidClientTokenId', 'SignatureDoesNotMatch'):
                helpful_msg = (
                    f"AWS Authentication Error ({error_code}): {error_message}\n"
                    "Please configure AWS credentials using one of the following methods:\n"
                    "  1. AWS credentials file: ~/.aws/credentials\n"
                    "  2. Environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY\n"
                    "  3. IAM role (if running on EC2/ECS/Lambda)\n"
                    "  4. AWS SSO: aws sso login\n"
                    "  5. AWS CLI: aws configure"
                )
                raise Exception(helpful_msg)

            raise Exception(f"AWS Error ({error_code}): {error_message}")
        except Exception as e:
            logger.error(f"Failed to query knowledge base: {str(e)}", exc_info=True)
            raise Exception(f"Failed to query knowledge base: {str(e)}")

    def upload_to_s3(self, file_path: str, s3_key: str) -> bool:
        """
        Upload a file to S3 bucket

        Args:
            file_path: Local file path
            s3_key: S3 object key

        Returns:
            True if successful
        """
        logger.info(f"Uploading file to S3: {s3_key} (bucket: {self.s3_bucket})")
        try:
            self.s3.upload_file(file_path, self.s3_bucket, s3_key)
            logger.info(f"File uploaded successfully to S3: {s3_key}")
            return True
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            logger.error(f"Failed to upload to S3 ({s3_key}) ({error_code}): {error_message}", exc_info=True)

            # Provide helpful error messages for common authentication issues
            if error_code in ('UnrecognizedClientException', 'InvalidClientTokenId', 'SignatureDoesNotMatch'):
                helpful_msg = (
                    f"AWS Authentication Error ({error_code}): {error_message}\n"
                    "Please configure AWS credentials. See error details in logs."
                )
                raise Exception(helpful_msg)

            raise Exception(f"Failed to upload to S3: {error_message}")

    def get_status(self) -> Dict:
        """
        Get Knowledge Base status and statistics

        Returns:
            Dictionary with KB status information
        """
        logger.debug(f"Getting KB status for {self.kb_id}")
        try:
            # Get Knowledge Base details
            kb_response = self.bedrock_agent_client.get_knowledge_base(
                knowledgeBaseId=self.kb_id
            )
            logger.debug("KB details retrieved successfully")

            kb_details = kb_response.get('knowledgeBase', {})

            # Get data sources
            data_sources = []
            try:
                ds_response = self.bedrock_agent_client.list_data_sources(
                    knowledgeBaseId=self.kb_id
                )
                data_sources = ds_response.get('dataSourceSummaries', [])
            except Exception:
                pass

            # Count objects in S3 (approximate)
            s3_count = 0
            try:
                paginator = self.s3.get_paginator('list_objects_v2')
                for page in paginator.paginate(Bucket=self.s3_bucket, Prefix='documents/'):
                    s3_count += len(page.get('Contents', []))
            except Exception:
                pass

            return {
                'knowledge_base_id': self.kb_id,
                'status': kb_details.get('status', 'UNKNOWN'),
                'name': kb_details.get('name', ''),
                'description': kb_details.get('description', ''),
                'data_sources': len(data_sources),
                's3_documents': s3_count,
                'storage_type': kb_details.get('storageConfiguration', {}).get('type', ''),
                'created_at': kb_details.get('createdAt', '').isoformat() if kb_details.get('createdAt') else None
            }

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            logger.error(f"Failed to get KB status ({error_code}): {error_message}", exc_info=True)

            # Provide helpful error messages for common authentication issues
            if error_code in ('UnrecognizedClientException', 'InvalidClientTokenId', 'SignatureDoesNotMatch'):
                helpful_msg = (
                    f"AWS Authentication Error ({error_code}): {error_message}\n"
                    "Please configure AWS credentials using one of the following methods:\n"
                    "  1. AWS credentials file: ~/.aws/credentials\n"
                    "  2. Environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY\n"
                    "  3. IAM role (if running on EC2/ECS/Lambda)\n"
                    "  4. AWS SSO: aws sso login\n"
                    "  5. AWS CLI: aws configure"
                )
                raise Exception(helpful_msg)

            raise Exception(f"Failed to get KB status: {error_message}")

    def start_ingestion_job(self, data_source_id: str) -> Dict:
        """
        Start a data source ingestion job

        Args:
            data_source_id: Data source ID

        Returns:
            Ingestion job details
        """
        logger.info(f"Starting ingestion job for data source: {data_source_id} (KB: {self.kb_id})")
        try:
            response = self.bedrock_agent_client.start_ingestion_job(
                knowledgeBaseId=self.kb_id,
                dataSourceId=data_source_id
            )
            job_id = response.get('ingestionJob', {}).get('ingestionJobId')
            logger.info(f"Ingestion job started successfully: {job_id}")
            return response.get('ingestionJob', {})
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            logger.error(f"Failed to start ingestion job ({error_code}): {error_message}", exc_info=True)

            # Provide helpful error messages for common authentication issues
            if error_code in ('UnrecognizedClientException', 'InvalidClientTokenId', 'SignatureDoesNotMatch'):
                helpful_msg = (
                    f"AWS Authentication Error ({error_code}): {error_message}\n"
                    "Please configure AWS credentials. See error details in logs."
                )
                raise Exception(helpful_msg)

            raise Exception(f"Failed to start ingestion job: {error_message}")

    def list_documents(self) -> List[Dict]:
            """
            List all documents in the knowledge base S3 bucket with their sizes
            
            Returns:
                List of dictionaries with 'name' and 'size' keys
            """
            logger.debug(f"Listing documents from S3 bucket: {self.s3_bucket}")
            documents = []
            
            try:
                paginator = self.s3.get_paginator('list_objects_v2')
                for page in paginator.paginate(Bucket=self.s3_bucket, Prefix='documents/'):
                    for obj in page.get('Contents', []):
                        # Extract document name from S3 key (remove 'documents/' prefix)
                        s3_key = obj.get('Key', '')
                        if s3_key.startswith('documents/'):
                            doc_name = s3_key.replace('documents/', '', 1)
                        else:
                            doc_name = s3_key.split('/')[-1]  # Fallback to filename
                        
                        size_bytes = obj.get('Size', 0)
                        
                        documents.append({
                            'name': doc_name,
                            'size': size_bytes
                        })
                
                logger.info(f"Found {len(documents)} documents in knowledge base")
                return documents
            except ClientError as e:
                error_code = e.response.get('Error', {}).get('Code', 'Unknown')
                error_message = e.response.get('Error', {}).get('Message', str(e))
                logger.error(f"Failed to list documents from S3 ({error_code}): {error_message}", exc_info=True)
                raise Exception(f"Failed to list documents: {error_message}")
            except Exception as e:
                logger.error(f"Failed to list documents: {str(e)}", exc_info=True)
                raise Exception(f"Failed to list documents: {str(e)}")

    def health_check(self) -> bool:
            """
            Check if Bedrock service is accessible
            
            Returns:
                True if service is healthy
            """
            logger.debug(f"Performing health check for KB: {self.kb_id}")
            try:
                # Simple check - try to describe the knowledge base
                self.bedrock_agent_client.get_knowledge_base(knowledgeBaseId=self.kb_id)
                logger.debug("Health check passed")
                return True
            except Exception as e:
                logger.warning(f"Health check failed: {str(e)}")
                return False

