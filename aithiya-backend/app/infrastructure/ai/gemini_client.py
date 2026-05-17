from fastapi import Request
from google import genai


def get_genai_client(request: Request) -> genai.Client:
    return request.app.state.genai_client
