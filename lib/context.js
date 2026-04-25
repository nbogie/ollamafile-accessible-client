// In-memory conversation history per session. No TTL / eviction in v1 —
// single user, process restart clears everything.

const sessions = new Map();

export function append(sessionId, message) {
  const messages = sessions.get(sessionId);
  if (messages) {
    messages.push(message);
  } else {
    sessions.set(sessionId, [message]);
  }
}

export function get(sessionId) {
  return sessions.get(sessionId) ?? [];
}

export function clear(sessionId) {
  sessions.delete(sessionId);
}
