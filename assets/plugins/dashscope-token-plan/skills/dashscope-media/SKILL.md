---
name: dashscope-media
description: Generate images, videos, or speech through the active Alibaba Model Studio Token Plan using the vendor-documented endpoints.
allowed-tools: Bash
---

# DashScope Token Plan media

Use this skill only when the user requests image generation, video generation,
or speech synthesis from the active Model Studio Token Plan. The session
provides `CROUTER_DASHSCOPE_TOKEN_PLAN_KEY`; never print, persist, or place it
in a command-line argument.

Follow Alibaba Model Studio's documented contracts:

- Images: POST to
  `https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation`.
  Default to `qwen-image-2.0` and `1024*1024` only when the user did not choose
  a model or size. The result URL is under
  `output.choices[*].message.content[*].image`.
- Videos: submit with `X-DashScope-Async: enable` to
  `https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis`,
  then poll `/api/v1/tasks/<task_id>` every 15 seconds. Defaults are
  `happyhorse-1.1-t2v`, `720P`, `16:9`, and five seconds.
- Speech: POST to
  `https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer`.
  Defaults are `qwen-audio-3.0-tts-plus`, `longanhuan_v3.6`, MP3, and 24 kHz.

Build request JSON with a JSON encoder rather than shell interpolation. Send
`Authorization: Bearer $CROUTER_DASHSCOPE_TOKEN_PLAN_KEY`; use curl failure
handling, validate returned URLs before downloading, choose a new timestamped
path in the current project, and never overwrite an existing file. For an
asynchronous task, report failure details without exposing request headers.
