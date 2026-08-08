---
name: step-search
description: Use the active Step Plan's official StepSearch MCP for current web information and page retrieval.
---

# StepSearch

Use `crouter-stepfun-web-search` only when current information or a specific
web page is needed. Prefer `web_search` to find a small set of relevant
sources, then `web_fetch` for the exact pages needed. Cite the returned source
URLs, avoid retrieving an entire site, and do not expose MCP authorization
details. The MCP is scoped to this crouter StepFun session and uses its active
Token Plan credential.
