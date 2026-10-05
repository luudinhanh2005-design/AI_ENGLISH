import sys
if sys.platform == 'win32' and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
import json
import random
import os

# Output paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TRAIN_FILE = os.path.join(SCRIPT_DIR, "dataset_train.jsonl")
VAL_FILE = os.path.join(SCRIPT_DIR, "dataset_val.jsonl")

# 1. CORE GRAMMAR CORRECTION PATTERNS (Vietnamese Learner Specific)
GRAMMAR_PATTERNS = [
    # Subject-verb agreement
    {
        "incorrect": "She go to school by bus everyday.",
        "corrected": "She goes to school by bus every day.",
        "rule": "Chủ ngữ số ít 'She' ở thì hiện tại đơn đi với động từ thêm -es: 'goes'. Đồng thời 'every day' (hàng ngày) viết tách biệt.",
        "type": "Subject-Verb Agreement",
        "level": "A1"
    },
    {
        "incorrect": "My brother have three cars.",
        "corrected": "My brother has three cars.",
        "rule": "Chủ ngữ ngôi thứ ba số ít 'My brother' dùng 'has' thay vì 'have'.",
        "type": "Subject-Verb Agreement",
        "level": "A1"
    },
    {
        "incorrect": "Everyone in the room are listening to music.",
        "corrected": "Everyone in the room is listening to music.",
        "rule": "Đại từ bất định 'Everyone' luôn đi với động từ số ít 'is'.",
        "type": "Subject-Verb Agreement",
        "level": "B1"
    },
    {
        "incorrect": "Neither my friend nor I are ready for the exam.",
        "corrected": "Neither my friend nor I am ready for the exam.",
        "rule": "Cấu trúc 'Neither... nor' chia theo chủ ngữ gần nhất ('I' đi với 'am').",
        "type": "Subject-Verb Agreement",
        "level": "B2"
    },
    # Tenses
    {
        "incorrect": "Yesterday I go to the cinema with my girlfriend.",
        "corrected": "Yesterday I went to the cinema with my girlfriend.",
        "rule": "Trạng từ thời gian 'Yesterday' chỉ quá khứ nên dùng động từ cột 2: 'went'.",
        "type": "Past Simple Tense",
        "level": "A1"
    },
    {
        "incorrect": "I have seen that movie yesterday evening.",
        "corrected": "I saw that movie yesterday evening.",
        "rule": "Có mốc thời gian xác định trong quá khứ ('yesterday evening') phải dùng Quá khứ đơn 'saw', không dùng Hiện tại hoàn thành.",
        "type": "Past Simple vs Present Perfect",
        "level": "A2"
    },
    {
        "incorrect": "I live in Hanoi since 2018.",
        "corrected": "I have lived in Hanoi since 2018.",
        "rule": "Hành động bắt đầu trong quá khứ kéo dài đến hiện tại có 'since 2018' phải dùng Hiện tại hoàn thành: 'have lived'.",
        "type": "Present Perfect Tense",
        "level": "A2"
    },
    {
        "incorrect": "When I arrived, the meeting already started.",
        "corrected": "When I arrived, the meeting had already started.",
        "rule": "Hành động xảy ra và kết thúc trước một hành động khác trong quá khứ dùng Quá khứ hoàn thành: 'had already started'.",
        "type": "Past Perfect Tense",
        "level": "B1"
    },
    # Prepositions
    {
        "incorrect": "I am very interested on learning English.",
        "corrected": "I am very interested in learning English.",
        "rule": "Tính từ 'interested' luôn đi kèm giới từ 'in' (interested in sth/doing sth).",
        "type": "Prepositions",
        "level": "A2"
    },
    {
        "incorrect": "It depends of the weather tomorrow.",
        "corrected": "It depends on the weather tomorrow.",
        "rule": "Động từ 'depend' đi kèm giới từ 'on' (hoặc 'upon'), không dùng 'of'.",
        "type": "Prepositions",
        "level": "A2"
    },
    {
        "incorrect": "I arrived to the airport at 9 PM.",
        "corrected": "I arrived at the airport at 9 PM.",
        "rule": "Đến một địa điểm cụ thể dùng 'arrive at' (hoặc 'arrive in' cho thành phố/quốc gia), không dùng 'arrive to'.",
        "type": "Prepositions",
        "level": "B1"
    },
    {
        "incorrect": "She is married with a doctor.",
        "corrected": "She is married to a doctor.",
        "rule": "Kết hôn với ai dùng 'married to', không dùng 'married with'.",
        "type": "Prepositions",
        "level": "A2"
    },
    # Articles & Countable/Uncountable
    {
        "incorrect": "Can you give me an advice about my career?",
        "corrected": "Can you give me some advice about my career?",
        "rule": "'Advice' là danh từ không đếm được, không dùng 'an advice'. Hãy dùng 'some advice' hoặc 'a piece of advice'.",
        "type": "Countable vs Uncountable",
        "level": "B1"
    },
    {
        "incorrect": "I need many informations about the university.",
        "corrected": "I need a lot of information about the university.",
        "rule": "'Information' không đếm được và không có dạng số nhiều 'informations'. Dùng 'a lot of information'.",
        "type": "Countable vs Uncountable",
        "level": "A2"
    },
    {
        "incorrect": "He is engineer at a big company.",
        "corrected": "He is an engineer at a big company.",
        "rule": "Danh từ chỉ nghề nghiệp số ít đếm được phải có mạo từ: 'an engineer' (bắt đầu bằng nguyên âm 'e').",
        "type": "Articles",
        "level": "A1"
    },
    # Collocations & Phrasal Verbs
    {
        "incorrect": "I usually make homework after dinner.",
        "corrected": "I usually do homework after dinner.",
        "rule": "Cụm cố định (collocation) là 'do homework', không dùng 'make homework'.",
        "type": "Collocations",
        "level": "A1"
    },
    {
        "incorrect": "We had a heavy discussion about the project.",
        "corrected": "We had an intense discussion about the project.",
        "rule": "Trong tiếng Anh tự nhiên, thảo luận sôi nổi/căng thẳng dùng 'an intense discussion' hoặc 'heated discussion', không dùng 'heavy'.",
        "type": "Collocations",
        "level": "B2"
    },
    {
        "incorrect": "I look forward to hear from you soon.",
        "corrected": "I look forward to hearing from you soon.",
        "rule": "Sau cụm 'look forward to', động từ luôn ở dạng V-ing: 'hearing'.",
        "type": "Gerund / Verb Form",
        "level": "B1"
    }
]

# 2. PERSONA PROMPTS & INTERACTION STYLES
PERSONAS = {
    "sarah": {
        "system": "You are Sarah, a warm, patient, and friendly English tutor. Your tone is conversational, encouraging, and helpful. You help learners build confidence in spoken and everyday English.",
        "greetings": [
            "Hi there! It's so wonderful to chat with you today! 😊",
            "Hello! How has your day been so far?",
            "Hey! Glad you're here to practice English with me!"
        ],
        "encouragements": [
            "You're doing great! Don't worry about small mistakes, they help us learn.",
            "I love how much effort you're putting into practicing!",
            "Your English is improving every day, keep it up!"
        ]
    },
    "harrison": {
        "system": "You are Mr. Harrison, a sharp, executive Business English coach. Your tone is professional, polished, and direct. You focus on corporate communications, negotiations, presentation phrases, and workplace etiquette.",
        "greetings": [
            "Good day. Let's focus on refining your business communication today.",
            "Welcome. Clear and concise English is a key asset in any career. What topic are we tackling today?",
            "Hello. Ready to polish your executive communication skills?"
        ],
        "encouragements": [
            "In a business context, precision is key. This refinement will make you sound much more professional.",
            "That's a solid point. With this phrasing adjustment, your message will have much higher impact in meetings.",
            "Excellent executive phrasing."
        ]
    },
    "emma": {
        "system": "You are Emma, an experienced British IELTS & Academic examiner. Your tone is articulate, analytical, and structured. You emphasize advanced lexical resource, complex grammatical accuracy, and coherence.",
        "greetings": [
            "Good day! Let us work on elevating your lexical resource and grammatical range today.",
            "Welcome! To achieve a band 7.0 or higher in IELTS, precision and coherence are paramount. Let us begin.",
            "Hello! Let's examine your arguments and elevate your academic expression."
        ],
        "encouragements": [
            "To push this towards Band 7.5+, consider replacing common descriptors with more nuanced academic terminology.",
            "Notice how this inversion adds sophisticated grammatical variety to your response.",
            "Splendid structure! Let's examine the cohesion between your supporting arguments."
        ]
    }
}

# 3. TOPICS FOR ROLEPLAY DIALOGUES
CONVERSATION_TOPICS = [
    {
        "topic": "Hobby & Free Time",
        "questions": [
            "What do you usually like to do in your free time?",
            "Have you taken up any new hobbies recently?",
            "Do you prefer outdoor activities or relaxing at home on weekends?"
        ]
    },
    {
        "topic": "Travel & Holidays",
        "questions": [
            "What was the most memorable place you have ever visited?",
            "If you could travel anywhere tomorrow, where would you go?",
            "Do you prefer traveling alone or with a group of friends?"
        ]
    },
    {
        "topic": "Job & Career",
        "questions": [
            "Could you tell me a little bit about what you do for a living?",
            "What is the most challenging aspect of your daily work?",
            "Where do you see yourself professionally in the next three years?"
        ]
    },
    {
        "topic": "Technology & AI",
        "questions": [
            "How do you think artificial intelligence is changing the way we learn?",
            "Do you spend too much time on smartphones or social media?",
            "What technological invention could you not live without?"
        ]
    }
]

def generate_samples(count=1200):
    dataset = []
    
    # Template types:
    # 1. Grammar Correction explicit request
    # 2. Conversational response with subtle correction
    # 3. Writing review & vocabulary upgrade
    
    for i in range(count):
        persona_key = random.choice(["sarah", "harrison", "emma"])
        persona = PERSONAS[persona_key]
        item = random.choice(GRAMMAR_PATTERNS)
        topic = random.choice(CONVERSATION_TOPICS)
        
        mode = random.choice(["correction", "conversation", "writing_upgrade"])
        
        if mode == "correction":
            user_msg = f"Can you check this sentence for me: \"{item['incorrect']}\""
            
            if persona_key == "sarah":
                resp_text = (
                    f"Of course! Here is a friendly review for you 😊:\n\n"
                    f"👉 **Câu chuẩn:** \"{item['corrected']}\"\n\n"
                    f"💡 **Giải thích:** {item['rule']}\n"
                    f"Đừng lo nhé, đây là lỗi rất phổ biến khi mới học! Hãy thử đặt lại 1 câu khác tương tự để nhớ lâu hơn nào!"
                )
            elif persona_key == "harrison":
                resp_text = (
                    f"Let's refine that for professional clarity:\n\n"
                    f"• **Original:** \"{item['incorrect']}\"\n"
                    f"• **Professional standard:** \"{item['corrected']}\"\n\n"
                    f"📌 **Key Rule ({item['type']}):** {item['rule']}\n"
                    f"In executive communication, grammatical precision builds instant credibility."
                )
            else: # emma
                resp_text = (
                    f"Let us examine the grammatical accuracy of your utterance:\n\n"
                    f"• **Criterion:** {item['type']} (CEFR {item['level']})\n"
                    f"• **Accurate version:** \"{item['corrected']}\"\n\n"
                    f"🔍 **Examiner Note:** {item['rule']}\n"
                    f"Eliminating these systematic slips is essential to comfortably secure a Band 7.0+ in Grammatical Range and Accuracy."
                )
            
            # Format according to ChatML / ShareGPT / Alpaca
            dataset.append({
                "system": persona["system"],
                "instruction": f"Act as {persona_key.title()}, an English tutor. Analyze the user's sentence, correct mistakes, and explain in Vietnamese.",
                "input": user_msg,
                "output": resp_text
            })
            
        elif mode == "conversation":
            # Realistic conversation where learner speaks with a mistake
            q = random.choice(topic["questions"])
            user_msg = f"{item['incorrect']} Also, I really enjoy {topic['topic'].lower()}."
            
            if persona_key == "sarah":
                resp_text = (
                    f"That sounds so nice! By the way, a tiny tip for your sentence: instead of \"{item['incorrect']}\", "
                    f"we usually say **\"{item['corrected']}\"** ({item['rule']}).\n\n"
                    f"Anyway, {q} I'd love to hear more about your thoughts!"
                )
            elif persona_key == "harrison":
                resp_text = (
                    f"Understood. Before we proceed, a quick refinement: adjust to **\"{item['corrected']}\"** ({item['rule']}).\n\n"
                    f"Returning to the agenda: {q}"
                )
            else:
                resp_text = (
                    f"A pertinent observation. First, do note the grammatical point: **\"{item['corrected']}\"** ({item['rule']}).\n\n"
                    f"To develop this idea further from an analytical perspective: {q}"
                )
            
            dataset.append({
                "system": persona["system"],
                "instruction": f"You are {persona_key.title()}. Converse naturally, provide a gentle correction with Vietnamese explanation, and continue the conversation.",
                "input": user_msg,
                "output": resp_text
            })
            
        else: # writing_upgrade
            adv_pairs = [
                ("very good", "exceptional / outstanding"),
                ("big problem", "pressing dilemma / substantial challenge"),
                ("help people", "empower individuals / assist the community"),
                ("think that", "am firmly of the opinion that / maintain that"),
                ("make it easy", "facilitate / streamline"),
            ]
            simple_word, adv_word = random.choice(adv_pairs)
            user_msg = f"How can I upgrade this phrase to sound more natural and academic: \"This is a {simple_word} for our society\"?"
            
            resp_text = (
                f"Great question! In English writing and IELTS, upgrading vocabulary makes a substantial difference:\n\n"
                f"• **Current:** \"This is a {simple_word}...\"\n"
                f"• **Advanced alternatives (Band 7.5+):** \"This poses a **{adv_word}** for our society.\"\n\n"
                f"💡 **Why this works:** '{adv_word}' replaces generic words with precise academic collocation, elevating your Lexical Resource score!"
            )
            
            dataset.append({
                "system": persona["system"],
                "instruction": "Provide academic vocabulary upgrades and explain how to improve writing quality.",
                "input": user_msg,
                "output": resp_text
            })

    return dataset

# Execute generation
all_data = generate_samples(1200)
random.shuffle(all_data)

# Split 90% train, 10% validation
split_idx = int(len(all_data) * 0.9)
train_data = all_data[:split_idx]
val_data = all_data[split_idx:]

with open(TRAIN_FILE, "w", encoding="utf-8") as f:
    for entry in train_data:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

with open(VAL_FILE, "w", encoding="utf-8") as f:
    for entry in val_data:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

print(f"✅ Generated {len(train_data)} training samples -> {TRAIN_FILE}")
print(f"✅ Generated {len(val_data)} validation samples -> {VAL_FILE}")
