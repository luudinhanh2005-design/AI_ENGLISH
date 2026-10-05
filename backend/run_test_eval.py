import sys
import os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

# Bypass torchvision mismatch
sys.modules['torchvision'] = None
sys.modules['torchvision.io'] = None
sys.modules['torchvision.ops'] = None

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from peft import PeftModel

ADAPTER_DIR = r"D:\AI ENGLISH\backend\ai_models\english_tutor_model"
BASE_MODEL = "unsloth/Qwen2.5-3B-Instruct-bnb-4bit"

print("==================================================")
print("[INFO] KIEM TRA MO HINH AI TUTOR VUA TRAIN")
print(f"[DEVICE] Thiet bi: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}")
print("==================================================")

print("\n1. Dang nap Tokenizer tu folder adapter...")
tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR, trust_remote_code=True)

print("\n2. Dang nap Base Model Qwen 2.5 3B (4-bit)...")
try:
    base_model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        device_map="auto",
        trust_remote_code=True,
    )
except Exception as e:
    print(f"[WARN] Thu nap ban goc Qwen/Qwen2.5-3B-Instruct do: {e}")
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

print("\n3. Dang gan trong so LoRA vua train...")
model = PeftModel.from_pretrained(base_model, ADAPTER_DIR)
model.eval()
print("[OK] DA NAP MO HINH THANH CONG VAO GPU!")

test_cases = [
    {
        "type": "SUA LOI NGU PHAP (Grammar Correction)",
        "prompt": "Can you check this sentence: \"She don't likes go to school\""
    },
    {
        "type": "HOI THOAI GIAO TIEP (Conversation Tutor)",
        "prompt": "Hi Sarah! I am nervous about my job interview tomorrow. Can you help me practice?"
    }
]

for i, tc in enumerate(test_cases, 1):
    print(f"\n--------------------------------------------------")
    print(f"Test {i}: {tc['type']}")
    print(f"User: {tc['prompt']}")
    print("Sarah (AI dang suy nghi...):")
    
    messages = [
        {"role": "system", "content": "You are Sarah, a warm, patient, and friendly English tutor."},
        {"role": "user", "content": tc["prompt"]}
    ]
    
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer([text], return_tensors="pt").to(model.device)
    
    with torch.no_grad():
        generated_ids = model.generate(
            **inputs,
            max_new_tokens=256,
            temperature=0.7,
            top_p=0.9,
            repetition_penalty=1.1
        )
    
    generated_ids = [
        output_ids[len(input_ids):] for input_ids, output_ids in zip(inputs.input_ids, generated_ids)
    ]
    response = tokenizer.batch_decode(generated_ids, skip_special_tokens=True)[0]
    print(response.strip())

print("\n==================================================")
print("[DONE] HOAN TAT THU NGHIEM CHAT LUONG MO HINH!")
print("==================================================")
