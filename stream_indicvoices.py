from datasets import load_dataset

# Pass your Hugging Face token here
dataset = load_dataset(
    "ai4bharat/IndicVoices",
    "hindi",
    split="train",
    streaming=True,
    token="YOUR_HF_TOKEN_HERE"  # Replace with your actual token
)

# Fetch and inspect samples sequentially without storing files locally
for i, sample in enumerate(dataset):
    print(f"--- Sample {i + 1} ---")
    print("Transcript:", sample.get("text", "N/A"))
    print("Audio Sampling Rate:", sample["audio"]["sampling_rate"])
    print("Audio Array Length:", len(sample["audio"]["array"]))
    
    if i == 2:
        break