import os


def create_model_dir():
    """
    Ensures the model_weights directory exists.
    """
    model_dir = os.path.join("core", "ai_model", "model_weights")

    if not os.path.exists(model_dir):
        os.makedirs(model_dir)
        print(f"Created model directory: {model_dir}")
    else:
        print(f"Model directory already exists: {model_dir}")
