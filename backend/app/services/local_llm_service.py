# Service nap va chay mo hinh AI da fine-tune tren GPU cuc bo
import os
import sys
import logging
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
        self.model_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "ai_models", "english_tutor_model"))
        self._initialized = True

    def load_model(self):
        """Nap mo hinh vao GPU neu chua nap"""
        if self.is_loaded:
            return True
            
        if not os.path.exists(self.model_dir):
            logger.warning(f"Chua tim thay thu muc model tai: {self.model_dir}")
            return False

        try:
            import torch
            from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
            from peft import PeftModel

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
            logger.info("Nap Local English Tutor LLM thanh cong!")
            return True
        except Exception as e:
            logger.error(f"Loi khi nap Local LLM: {e}")
            return False

    def generate_chat_response(
        self, 
        messages: List[Dict[str, str]], 
        max_tokens: int = 300, 
        temperature: float = 0.7
    ) -> str:
        """Sinh cau tra loi tu model"""
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
                "content": "You are Sarah, a warm, patient, and friendly English tutor for Vietnamese learners. "
                "You are completely fluent in both Vietnamese and English. "
                "When the user speaks or asks in Vietnamese, ALWAYS respond, explain grammar, and guide them warmly in natural Vietnamese. "
                "Provide the correct English sentences clearly, point out mistakes, and explain the grammatical reasons in Vietnamese so the learner understands easily."
            })
        full_messages.extend(messages)

        text = self.tokenizer.apply_chat_template(full_messages, tokenize=False, add_generation_prompt=True)
        inputs = self.tokenizer([text], return_tensors="pt").to(self.model.device)

        with torch.no_grad():
            generated_ids = self.model.generate(
                **inputs,
                max_new_tokens=max_tokens,
                temperature=temperature,
                top_p=0.9,
                repetition_penalty=1.1
            )

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
