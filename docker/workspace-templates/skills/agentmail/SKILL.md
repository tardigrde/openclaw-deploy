---
name: agentmail
description: Send and receive emails as an AI agent via AgentMail
user-invocable: true
metadata: {"openclaw": {}}
---

Use this skill when asked to send an email, check an inbox, read messages, or reply to threads.

Auth is via `AGENTMAIL_API_KEY` (already in the container environment). The default inbox is `openclaw@agentmail.to`.

## SDK usage

The `agentmail` npm package is installed globally. Use it in a Node.js one-liner or a temp script:

```js
const { AgentMailClient } = require('agentmail');
const client = new AgentMailClient({ apiKey: process.env.AGENTMAIL_API_KEY });
```

## Common operations

**Create or get the inbox** (idempotent — safe to call each time):
```js
const inbox = await client.inboxes.create({ username: 'openclaw' });
// inbox.emailAddress → "openclaw@agentmail.to"
```

**Send an email:**
```js
await client.messages.send('openclaw@agentmail.to', {
  to: [{ email: 'recipient@example.com' }],
  subject: 'Hello from OpenClaw',
  text: 'Message body here.',
  // html: '<p>Or HTML body.</p>',
});
```

**List threads in the inbox:**
```js
const { items } = await client.threads.list('openclaw@agentmail.to');
```

**Read a thread (all messages):**
```js
const thread = await client.threads.get('openclaw@agentmail.to', threadId);
```

**Reply to a thread:**
```js
await client.messages.reply('openclaw@agentmail.to', threadId, {
  text: 'My reply.',
});
```

## Running a snippet

Write to a temp file and execute, or use `-e` for short snippets:

```bash
node -e "
(async () => {
  const { AgentMailClient } = require('agentmail');
  const client = new AgentMailClient({ apiKey: process.env.AGENTMAIL_API_KEY });
  const result = await client.threads.list('openclaw@agentmail.to');
  console.log(JSON.stringify(result, null, 2));
})();
"
```

## Notes

- Inbound email triggers are not set up — the agent reads emails on demand by listing threads.
- If `AGENTMAIL_API_KEY` is empty, report it to the user and stop.
- Keep emails concise and professional. Confirm recipient/subject with the user before sending unless clearly specified.
