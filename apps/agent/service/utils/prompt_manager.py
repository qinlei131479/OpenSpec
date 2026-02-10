import os
import threading
from langfuse import Langfuse
import logging

logger = logging.getLogger(__name__)

class PromptManager:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super(PromptManager, cls).__new__(cls)
                    cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        try:
            self.langfuse = Langfuse()
            logger.info("Langfuse client initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize Langfuse client: {e}")
            self.langfuse = None
        
        self.default_label = os.getenv("PROMPT_LABEL", "latest")

    def get_prompt(self, prompt_name: str, label: str = None):
        """
        Get prompt from Langfuse.
        
        Args:
            prompt_name (str): The name of the prompt in Langfuse.
            label (str, optional): The label version of the prompt. Defaults to env PROMPT_LABEL or "latest".
            
        Returns:
            Prompt object from Langfuse or None if client is not initialized or error occurs.
        """
        if not self.langfuse:
            logger.warning("Langfuse client is not initialized. Returning None for prompt.")
            return None

        target_label = label or self.default_label
        try:
            return self.langfuse.get_prompt(prompt_name, label=target_label)
        except Exception as e:
            logger.error(f"Failed to fetch prompt '{prompt_name}' with label '{target_label}': {e}")
            raise e
