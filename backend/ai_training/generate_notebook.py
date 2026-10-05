import sys
if sys.platform == 'win32' and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
IPYNB_PATH = os.path.join(SCRIPT_DIR, "train_colab.ipynb")

cells = [
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "# 🚀 Huấn Luyện AI Gia Sư Tiếng Anh (EnglishAI Tutor) bằng Unsloth & QLoRA\n",
            "\n",
            "Notebook này được tối ưu để chạy trên **Google Colab (GPU T4 Miễn phí)**.\n",
            "Mô hình nền tảng: **Qwen2.5-3B-Instruct** (Siêu thông minh, phản hồi tiếng Anh/Việt xuất sắc, chạy cực nhẹ trên card GTX 1660 Ti sau khi xuất GGUF).\n",
            "\n",
            "⏱️ **Thời gian huấn luyện:** ~15 - 20 phút.\n",
            "💾 **Đầu ra:** File `english_ai_tutor_q4.gguf` nạp vào **Ollama** trên máy tính của bạn."
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 1: Cài đặt Unsloth & Thư viện phụ thuộc"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "%%capture\n",
            "!pip install \"unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git\"\n",
            "!pip install --no-deps \"xformers<0.0.29\" \"trl<0.9.0\" peft accelerate bitsandbytes"
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 2: Tải Mô hình nền tảng Qwen 2.5 3B (Đã nén 4-bit)"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "from unsloth import FastLanguageModel\n",
            "import torch\n",
            "\n",
            "max_seq_length = 2048\n",
            "dtype = None # Tự động phát hiện Float16 hoặc Bfloat16\n",
            "load_in_4bit = True # Giảm 80% VRAM\n",
            "\n",
            "model, tokenizer = FastLanguageModel.from_pretrained(\n",
            "    model_name = \"unsloth/Qwen2.5-3B-Instruct-bnb-4bit\",\n",
            "    max_seq_length = max_seq_length,\n",
            "    dtype = dtype,\n",
            "    load_in_4bit = load_in_4bit,\n",
            ")\n",
            "print(\"✅ Mô hình nền tảng đã nạp thành công!\")"
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 3: Áp dụng kỹ thuật QLoRA (Chỉ train các adapter trọng số)"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "model = FastLanguageModel.get_peft_model(\n",
            "    model,\n",
            "    r = 16,\n",
            "    target_modules = [\"q_proj\", \"k_proj\", \"v_proj\", \"o_proj\",\n",
            "                      \"gate_proj\", \"up_proj\", \"down_proj\"],\n",
            "    lora_alpha = 16,\n",
            "    lora_dropout = 0,\n",
            "    bias = \"none\",\n",
            "    use_gradient_checkpointing = \"unsloth\",\n",
            "    random_state = 3407,\n",
            ")\n",
            "print(\"✅ LoRA Adapters đã sẵn sàng!\")"
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 4: Tải lên và Định dạng tập dữ liệu (dataset_train.jsonl)"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "from datasets import load_dataset\n",
            "from google.colab import files\n",
            "import os\n",
            "\n",
            "# Nếu chưa có file trên Colab, mở cửa sổ upload\n",
            "if not os.path.exists(\"dataset_train.jsonl\"):\n",
            "    print(\"Vui lòng chọn file dataset_train.jsonl để tải lên Colab:\")\n",
            "    uploaded = files.upload()\n",
            "\n",
            "dataset = load_dataset(\"json\", data_files=\"dataset_train.jsonl\", split=\"train\")\n",
            "\n",
            "# Cấu trúc ChatML của Qwen 2.5\n",
            "prompt_template = \"\"\"<|im_start|>system\n",
            "{system}<|im_end|>\n",
            "<|im_start|>user\n",
            "{instruction}\n",
            "\n",
            "{input}<|im_end|>\n",
            "<|im_start|>assistant\n",
            "{output}<|im_end|>\"\"\"\n",
            "\n",
            "def formatting_prompts_func(examples):\n",
            "    systems = examples[\"system\"]\n",
            "    instructions = examples[\"instruction\"]\n",
            "    inputs = examples[\"input\"]\n",
            "    outputs = examples[\"output\"]\n",
            "    texts = []\n",
            "    for sys, inst, inp, outp in zip(systems, instructions, inputs, outputs):\n",
            "        text = prompt_template.format(system=sys, instruction=inst, input=inp, output=outp)\n",
            "        texts.append(text)\n",
            "    return { \"text\" : texts }\n",
            "\n",
            "dataset = dataset.map(formatting_prompts_func, batched = True)\n",
            "print(f\"✅ Đã chuẩn bị {len(dataset)} mẫu dữ liệu huấn luyện!\")"
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 5: Bắt đầu Huấn Luyện (Training)"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "from trl import SFTTrainer\n",
            "from transformers import TrainingArguments\n",
            "from unsloth import is_bfloat16_supported\n",
            "\n",
            "trainer = SFTTrainer(\n",
            "    model = model,\n",
            "    tokenizer = tokenizer,\n",
            "    train_dataset = dataset,\n",
            "    dataset_text_field = \"text\",\n",
            "    max_seq_length = max_seq_length,\n",
            "    dataset_num_proc = 2,\n",
            "    packing = False,\n",
            "    args = TrainingArguments(\n",
            "        per_device_train_batch_size = 2,\n",
            "        gradient_accumulation_steps = 4,\n",
            "        warmup_steps = 10,\n",
            "        max_steps = 150, # Train khoảng 150 bước (~15 phút)\n",
            "        learning_rate = 2e-4,\n",
            "        fp16 = not is_bfloat16_supported(),\n",
            "        bf16 = is_bfloat16_supported(),\n",
            "        logging_steps = 10,\n",
            "        optim = \"adamw_8bit\",\n",
            "        weight_decay = 0.01,\n",
            "        lr_scheduler_type = \"linear\",\n",
            "        seed = 3407,\n",
            "        output_dir = \"outputs\",\n",
            "    ),\n",
            ")\n",
            "\n",
            "print(\"🚀 Bắt đầu quá trình huấn luyện...\")\n",
            "trainer_stats = trainer.train()\n",
            "print(\"🎉 Huấn luyện thành công!\")"
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 6: Thử Nghiệm Mô Hình Sau Khi Train"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "FastLanguageModel.for_inference(model) # Tăng tốc suy luận 2x\n",
            "\n",
            "test_prompt = \"\"\"<|im_start|>system\n",
            "You are Sarah, a warm, patient, and friendly English tutor.<|im_end|>\n",
            "<|im_start|>user\n",
            "Can you check this sentence: \"She don't likes go to school\"<|im_end|>\n",
            "<|im_start|>assistant\n",
            "\"\"\"\n",
            "\n",
            "inputs = tokenizer([test_prompt], return_tensors = \"pt\").to(\"cuda\")\n",
            "outputs = model.generate(**inputs, max_new_tokens = 256, use_cache = True)\n",
            "response = tokenizer.batch_decode(outputs)\n",
            "print(response[0].split(\"<|im_start|>assistant\")[1].replace(\"<|im_end|>\", \"\"))"
        ]
    },
    {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "### Bước 7: Xuất Sang Định Dạng GGUF (Để nạp vào Ollama)"
        ]
    },
    {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Xuất model ra định dạng GGUF chuẩn nén Q4_K_M (Chỉ ~2.0 GB)\n",
            "print(\"📦 Đang đóng gói mô hình sang file GGUF cho Ollama...\")\n",
            "model.save_pretrained_gguf(\"english_ai_tutor\", tokenizer, quantization_method = \"q4_k_m\")\n",
            "print(\"✅ Đã tạo file: english_ai_tutor-unsloth.Q4_K_M.gguf\")\n",
            "\n",
            "# Tải file về máy tính của bạn\n",
            "files.download(\"english_ai_tutor-unsloth.Q4_K_M.gguf\")"
        ]
    }
]

notebook = {
    "cells": cells,
    "metadata": {
        "accelerator": "GPU",
        "colab": {
            "gpuType": "T4",
            "provenance": []
        },
        "language_info": {
            "name": "python"
        }
    },
    "nbformat": 4,
    "nbformat_minor": 0
}

with open(IPYNB_PATH, "w", encoding="utf-8") as f:
    json.dump(notebook, f, ensure_ascii=False, indent=2)

print(f"✅ Generated Jupyter Notebook -> {IPYNB_PATH}")
