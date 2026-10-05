import os
import sys
import torch

print(f"Python: {sys.version}")
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA Available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU Device: {torch.cuda.get_device_name(0)}")

try:
    import transformers
    print(f"Transformers: {transformers.__version__}")
except ImportError:
    print("Transformers: NOT INSTALLED")

try:
    import peft
    print(f"PEFT: {peft.__version__}")
except ImportError:
    print("PEFT: NOT INSTALLED")

try:
    import bitsandbytes
    print(f"bitsandbytes: {bitsandbytes.__version__}")
except ImportError:
    print("bitsandbytes: NOT INSTALLED")
