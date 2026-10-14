# Karen Bug Fixes: 2026-10-09
- Implemented ContextEngine state debouncing to prevent database spam when CPU drops to 0 temporarily.
- Removed time prefix formatting from assistant messages in the Groq prompt to prevent the model from learning to repeat the time prefix.

## Resolved By
Antigravity
