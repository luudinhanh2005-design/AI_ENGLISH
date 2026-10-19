# Service nap va chay mo hinh AI da fine-tune tren GPU cuc bo
import os
import sys
import logging
import threading
import time
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)

# Ngat torchvision de tranh xung dot C++ binary
sys.modules['torchvision'] = None
sys.modules['torchvision.io'] = None
sys.modules['torchvision.ops'] = None

class LocalLLMService:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(LocalLLMService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self.model = None
        self.tokenizer = None
        self.device = None
        self.is_loaded = False
        self.is_loading = False
        self.load_error: Optional[str] = None
        self.last_load_seconds: Optional[float] = None
        self._load_attempted = False
        self._load_lock = threading.Lock()
        self._model_lock = threading.RLock()
        self.model_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "ai_models", "english_tutor_model"))
        self._initialized = True

    def load_model(self, force: bool = False):
        """Nap mo hinh vao GPU neu chua nap.

        ``force`` cho phep thu lai sau mot loi tam thoi. Mac dinh loi load
        duoc cache de tranh moi request deu treo vi nap lai model.
        """
        if self.is_loaded:
            return True

        with self._load_lock:
            if self.is_loaded:
                return True
            if self._load_attempted and self.load_error and not force:
                return False

            self.is_loading = True
            self._load_attempted = True
            started_at = time.monotonic()
            try:
                import torch
                try:
                    from transformers.models.auto import AutoTokenizer, AutoModelForCausalLM
                    from transformers import BitsAndBytesConfig
                except Exception:
                    from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
                from peft import PeftModel

                if not os.path.exists(self.model_dir):
                    raise FileNotFoundError(f"Khong tim thay model tai: {self.model_dir}")

                self.device = "cuda" if torch.cuda.is_available() else "cpu"
                logger.info(f"Bat dau nap Local LLM len thiet bi: {self.device}...")

                self.tokenizer = AutoTokenizer.from_pretrained(self.model_dir, trust_remote_code=True)

                base_model_name = "unsloth/Qwen2.5-3B-Instruct-bnb-4bit"
                try:
                    base_model = AutoModelForCausalLM.from_pretrained(
                        base_model_name,
                        device_map="auto",
                        trust_remote_code=True,
                    )
                except Exception as e:
                    logger.warning(f"Chuyen sang base Qwen goc: {e}")
                    bnb_config = BitsAndBytesConfig(
                        load_in_4bit=True,
                        bnb_4bit_quant_type="nf4",
                        bnb_4bit_compute_dtype=torch.float16,
                    )
                    base_model = AutoModelForCausalLM.from_pretrained(
                        "Qwen/Qwen2.5-3B-Instruct",
                        quantization_config=bnb_config,
                        device_map="auto",
                        trust_remote_code=True,
                    )

                self.model = PeftModel.from_pretrained(base_model, self.model_dir)
                self.model.eval()
                self.is_loaded = True
                self.load_error = None
                logger.info("Nap Local English Tutor LLM thanh cong!")
                return True
            except Exception as e:
                import traceback
                self.load_error = f"{e}\n{traceback.format_exc()}"
                logger.error(f"Loi khi nap Local LLM: {self.load_error}")
                return False
            finally:
                self.is_loading = False
                self.last_load_seconds = round(time.monotonic() - started_at, 2)

    def status(self) -> Dict[str, object]:
        """Tra ve trang thai model de chan doan tu API/UI."""
        return {
            "is_loaded": self.is_loaded,
            "is_loading": self.is_loading,
            "device": str(self.device) if self.device else None,
            "model_dir": self.model_dir,
            "load_error": self.load_error,
            "last_load_seconds": self.last_load_seconds,
        }

    def generate_chat_response(
        self, 
        messages: List[Dict[str, str]], 
        max_tokens: int = 300, 
        temperature: float = 0.7,
        timeout_seconds: Optional[float] = None,
    ) -> str:
        """Sinh cau tra loi tu model (serialized de tranh tranh chap GPU)."""
        with self._model_lock:
            if not self.is_loaded:
                success = self.load_model()
                if not success:
                    raise RuntimeError("Mo hinh AI cuc bo chua san sang.")

            import torch

            has_system = any(m.get("role") == "system" for m in messages)
            full_messages = []
            if not has_system:
                full_messages.append({
                    "role": "system",
                    "content": (
                        "You are Sarah, a warm, patient, and friendly native English tutor. "
                        "You MUST ALWAYS reply and converse in natural, engaging ENGLISH so the learner can practice English speaking and conversation. "
                        "Do NOT reply in Vietnamese unless the user explicitly asks for a Vietnamese translation. "
                        "Always end your reply with an engaging follow-up question in English to keep the conversation going."
                    )
                })
            full_messages.extend(messages)

            text = self.tokenizer.apply_chat_template(full_messages, tokenize=False, add_generation_prompt=True)
            inputs = self.tokenizer([text], return_tensors="pt").to(self.model.device)

            generation_kwargs = {
                "max_new_tokens": max_tokens,
                "top_p": 0.9,
                "repetition_penalty": 1.1,
                "do_sample": temperature > 0,
                "pad_token_id": self.tokenizer.eos_token_id,
            }
            if temperature > 0:
                generation_kwargs["temperature"] = temperature

            if timeout_seconds and timeout_seconds > 0:
                from transformers import StoppingCriteria, StoppingCriteriaList

                class _DeadlineStoppingCriteria(StoppingCriteria):
                    def __init__(self) -> None:
                        self.started_at = time.monotonic()

                    def __call__(self, input_ids, scores, **kwargs) -> bool:
                        return time.monotonic() - self.started_at >= timeout_seconds

                generation_kwargs["stopping_criteria"] = StoppingCriteriaList(
                    [_DeadlineStoppingCriteria()]
                )

            with torch.no_grad():
                generated_ids = self.model.generate(**inputs, **generation_kwargs)

            generated_ids = [
                output_ids[len(input_ids):] for input_ids, output_ids in zip(inputs.input_ids, generated_ids)
            ]
            response = self.tokenizer.batch_decode(generated_ids, skip_special_tokens=True)[0]
            return response.strip()

    def check_grammar(self, sentence: str) -> str:
        """Sua loi ngu phap bang model da duoc fine-tune"""
        messages = [
            {"role": "user", "content": f'Can you check this sentence: "{sentence}"'}
        ]
        return self.generate_chat_response(messages, max_tokens=256, temperature=0.3)

local_llm_service = LocalLLMService()
