# Vision Pipeline Repair: Actual Image-to-LLM Integration

**Date:** 2026-10-09
**Project:** Karen
**Area:** Architecture_and_Design / Backend_and_API

## Issue Description
The Karen desktop perception pipeline was failing to perform visual interpretation of screenshots. When `capture_desktop_context` was dispatched, the backend retrieved a valid image path from the GNOME Wayland portal. However, instead of passing the image content to the LLM, the backend merely passed the local filesystem path string (e.g. `/tmp/...png`) embedded within the tool call result JSON. Since the Groq text model cannot access local filesystem paths and the path was fed to the standard chat model, vision was entirely non-functional and the model would simply hallucinate what the "screenshot" might contain based on text cues.

## Resolution
1. **Tool Result Extraction**: Intercepted the tool result for `capture_desktop_context` in the `run_agentic` agent loop. The `image_path` is explicitly removed from the JSON payload fed to the LLM to prevent path hallucinations and security leaks.
2. **Image Processing**: Introduced a new `process_screenshot` routine that reads the file at `image_path`, validates it as a recognized image, resizes it using a Triangle filter to enforce a maximum dimension of 2048x2048, and encodes it into a JPEG base64 payload.
3. **Multimodal Injection**: Implemented support for Llama-3.2 multimodal messages. If a screenshot is captured successfully, a new `user` message with `image_url` parts is constructed and appended to the message history, accompanied by strict instructions limiting the model to actual visible observations.
4. **Dynamic Model Switching**: When vision payloads are present, the request model is dynamically switched to `GROQ_VISION_MODEL` (defaulting to `llama-3.2-90b-vision-preview`), ensuring compatibility.
5. **Data Cleanup**: Ensured the temporary screenshot file is deleted immediately after encoding, reducing long-lived persistence of sensitive visual data.
6. **Testing**: Integrated unit tests for correct image byte retrieval, encoding validity, invalid payload rejection, and automatic cleanup.

Resolved By: Antigravity
