import { createInterface } from "node:readline";
import plugin from "./herdr-tui-session.js";

const sessions = new Map([
  ["a", { id: "a" }],
  ["b", { id: "b" }],
  ["child-a", { id: "child-a", parentID: "a" }],
  ["child-b", { id: "child-b", parentID: "b" }],
]);
const statuses = new Map();
const listeners = new Set();
let route = { type: "session", sessionID: process.argv[2] };
const api = {
  ui: { router: { current: () => route } },
  data: {
    session: {
      get: (id) => sessions.get(id),
      family: () => [...sessions.keys()],
      status: (id) => statuses.get(id) ?? "idle",
      permission: { list: () => [] },
      form: { list: () => [] },
    },
    listen: (handler) => {
      listeners.add(handler);
      return () => listeners.delete(handler);
    },
  },
};

const dispose = plugin.setup(api);
console.log(JSON.stringify({ ready: true }));
try {
  for await (const line of createInterface({ input: process.stdin })) {
    const command = JSON.parse(line);
    switch (command.type) {
      case "event":
        for (const handler of listeners) handler({ details: { type: command.name, data: command.data } });
        break;
      case "status":
        statuses.set(command.sessionID, command.status);
        break;
      case "home":
        route = { type: "home" };
        break;
      case "select":
        route = { type: "session", sessionID: command.sessionID };
        break;
      case "dispose":
        dispose();
        break;
      default:
        throw new Error(`Unknown test command: ${command.type}`);
    }
    console.log(JSON.stringify({ acknowledged: command.id }));
  }
} finally {
  dispose();
}
