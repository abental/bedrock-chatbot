"""
Advanced prompt engineering for Bedrock Knowledge Base
"""
from typing import Dict, List, Optional
from datetime import datetime
import json

try:
    from config.logging_config import get_logger
except ImportError:
    from ..config.logging_config import get_logger

logger = get_logger(__name__)


class PromptEngine:
    """Advanced prompt engineering with system prompts, few-shot examples, and templates"""
    
    def __init__(self, config):
        """
        Initialize prompt engine
        
        Args:
            config: ConfigManager instance
        """
        logger.debug("Initializing PromptEngine")
        self.config = config
        self.system_prompt = self._load_system_prompt()
        self.few_shot_examples = self._load_few_shot_examples()
        self.prompt_templates = self._load_prompt_templates()
        logger.info(f"PromptEngine initialized ({len(self.prompt_templates)} templates, {len(self.few_shot_examples)} examples)")
    
    def _load_system_prompt(self) -> str:
        """Load system prompt from config or use default"""
        default_prompt = """You are a helpful AI assistant with access to a knowledge base. 
Your role is to provide accurate, helpful, and well-structured answers based on the retrieved context.

Guidelines:
- Always base your answers on the provided context from the knowledge base
- If the context doesn't contain relevant information, clearly state that
- Cite specific sources when referencing information
- Provide clear, concise, and well-organized responses
- If asked about something not in the knowledge base, politely indicate the limitation
- Use markdown formatting for better readability when appropriate"""
        
        return self.config.get('SYSTEM_PROMPT', default_prompt)
    
    def _load_few_shot_examples(self) -> List[Dict]:
        """Load few-shot examples for prompt engineering"""
        default_examples = [
            {
                "question": "What is the main topic?",
                "context": "The document discusses machine learning fundamentals...",
                "answer": "Based on the context, the main topic is machine learning fundamentals, covering..."
            },
            {
                "question": "How does X work?",
                "context": "X operates by first... then...",
                "answer": "According to the retrieved context, X works through a multi-step process: 1) First... 2) Then..."
            }
        ]
        
        examples_json = self.config.get('FEW_SHOT_EXAMPLES', '[]')
        try:
            if isinstance(examples_json, str):
                return json.loads(examples_json)
            elif isinstance(examples_json, list):
                return examples_json
            else:
                return default_examples
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            # Log error but don't fail - use defaults
            logger.warning(f"Failed to parse few-shot examples: {e}, using defaults")
            return default_examples
    
    def _load_prompt_templates(self) -> Dict[str, str]:
        """Load prompt templates for different query types"""
        return {
            'general': """Context:
{context}

Question: {question}

Please provide a comprehensive answer based on the context above.""",
            
            'technical': """Technical Context:
{context}

Technical Question: {question}

Provide a detailed technical explanation based on the context, including any relevant specifications, procedures, or technical details.""",
            
            'summary': """Context:
{context}

Question: {question}

Provide a concise summary based on the context above.""",
            
            'comparison': """Context:
{context}

Question: {question}

Compare and contrast the relevant information from the context to answer the question."""
        }
    
    def build_prompt(self, question: str, context: List[Dict], 
                    query_type: str = 'general',
                    include_system_prompt: bool = True,
                    include_examples: bool = False) -> str:
        """
        Build an advanced prompt with system instructions and context
        
        Args:
            question: User's question
            context: Retrieved context from knowledge base
            query_type: Type of query (general, technical, summary, comparison)
            include_system_prompt: Whether to include system prompt
            include_examples: Whether to include few-shot examples
        
        Returns:
            Formatted prompt string
        """
        # Format context
        context_text = self._format_context(context)
        
        # Get template
        template = self.prompt_templates.get(query_type, self.prompt_templates['general'])
        
        # Build prompt parts
        prompt_parts = []
        
        if include_system_prompt:
            prompt_parts.append(f"System Instructions:\n{self.system_prompt}\n")
        
        if include_examples and self.few_shot_examples:
            examples_text = self._format_examples(self.few_shot_examples[:2])  # Use 2 examples
            prompt_parts.append(f"Examples:\n{examples_text}\n")
        
        # Add main prompt
        main_prompt = template.format(
            context=context_text,
            question=question
        )
        prompt_parts.append(main_prompt)
        
        return "\n\n".join(prompt_parts)
    
    def _format_context(self, context: List[Dict]) -> str:
        """Format retrieved context for prompt"""
        if not context:
            return "No context available."
        
        formatted = []
        for i, item in enumerate(context, 1):
            content = item.get('content', '')
            location = item.get('location', {})
            score = item.get('score', 0)
            
            context_item = f"[Source {i}]"
            if location:
                s3_uri = location.get('s3Location', {}).get('uri', '')
                if s3_uri:
                    context_item += f" (from {s3_uri})"
            
            context_item += f"\n{content}\n"
            formatted.append(context_item)
        
        return "\n---\n".join(formatted)
    
    def _format_examples(self, examples: List[Dict]) -> str:
        """Format few-shot examples"""
        formatted = []
        for i, example in enumerate(examples, 1):
            formatted.append(f"Example {i}:")
            formatted.append(f"Q: {example.get('question', '')}")
            formatted.append(f"Context: {example.get('context', '')}")
            formatted.append(f"A: {example.get('answer', '')}")
            formatted.append("")
        
        return "\n".join(formatted)
    
    def detect_query_type(self, question: str) -> str:
        """
        Detect query type based on question patterns
        
        Returns:
            Query type (general, technical, summary, comparison)
        """
        question_lower = question.lower()
        
        # Technical keywords
        if any(word in question_lower for word in ['how', 'implement', 'configure', 'setup', 'technical', 'specification']):
            logger.debug(f"Detected query type: technical")
            return 'technical'
        
        # Summary keywords
        if any(word in question_lower for word in ['summarize', 'summary', 'overview', 'brief']):
            logger.debug(f"Detected query type: summary")
            return 'summary'
        
        # Comparison keywords
        if any(word in question_lower for word in ['compare', 'difference', 'versus', 'vs', 'better']):
            logger.debug(f"Detected query type: comparison")
            return 'comparison'
        
        logger.debug(f"Detected query type: general")
        return 'general'
    
    def enhance_query(self, question: str, conversation_history: Optional[List[Dict]] = None) -> str:
        """
        Enhance query with conversation context
        
        Args:
            question: Current question
            conversation_history: Previous questions and answers
        
        Returns:
            Enhanced question
        """
        if not conversation_history:
            logger.debug("No conversation history, returning original question")
            return question
        
        logger.debug(f"Enhancing query with {len(conversation_history)} previous exchanges")
        # Add context from recent conversation
        recent_context = []
        for item in conversation_history[-3:]:  # Last 3 exchanges
            recent_context.append(f"Previous question: {item.get('question', '')}")
            recent_context.append(f"Previous answer: {item.get('answer', '')[:200]}...")
        
        if recent_context:
            enhanced = "Context from previous conversation:\n" + "\n".join(recent_context)
            enhanced += f"\n\nCurrent question: {question}"
            logger.debug("Query enhanced with conversation context")
            return enhanced
        
        return question

