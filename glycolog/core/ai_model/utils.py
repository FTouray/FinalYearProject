import os


def create_model_dir():
    """
    Ensures the model_weights directory exists.
    """
    if not os.path.exists("ai_model/model_weights"):
        os.makedirs("ai_model/model_weights")
