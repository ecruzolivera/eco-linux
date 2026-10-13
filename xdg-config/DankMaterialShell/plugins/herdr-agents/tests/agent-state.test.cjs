const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

// The same plain JS runs in QML and in this isolated Node context.
const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, "../AgentState.js"), "utf8"), logic);
const response = agents => JSON.stringify({ result: { type: "agent_list", agents } });
const agent = (state, pane = "w1:p1") => ({ pane_id: pane, agent: "opencode", agent_status: state });
const snapshot = states => logic.snapshotFromResponse(response(states.map((state, i) => agent(state, `w1:p${i}`))));

for (const [states, expected, filled] of [
    [["blocked"], "blocked", true],
    [["done"], "done", true],
    [["working"], "working", true],
    [["idle"], "idle", false],
    [["unknown"], "unknown", false],
    [["blocked", "done", "working", "idle"], "blocked", true],
    [["done", "working"], "done", true],
    [["working", "idle"], "working", true],
    [["idle", "idle"], "idle", false],
    [["idle", "unknown"], "unknown", false],
    [["working", "unknown"], "working", true],
    [["done", "unknown"], "done", true],
    [["blocked", "unknown"], "blocked", true],
    [["future-state"], "unknown", false]
]) {
    test(`${states.join(" + ")} => ${expected}, filled=${filled}`, () => {
        const result = snapshot(states);
        assert.equal(result.state, expected);
        assert.equal(result.filled, filled);
        assert.equal(result.visible, true);
        assert.equal(result.available, true);
    });
}

test("empty results hide the widget", () => {
    const result = snapshot([]);
    assert.equal(result.state, "empty");
    assert.equal(result.visible, false);
    assert.equal(result.filled, false);
});

for (const text of ["", "not json", "null", "{}", '{"result":{"agents":[]}}',
    '{"result":{"type":"agent_list","agents":null}}', response([null]), response([{}]), response([[]])]) {
    test(`invalid response rejected: ${text}`, () => {
        assert.throws(() => logic.snapshotFromResponse(text), /Herdr returned/);
    });
}

test("missing status is unknown, not idle", () => {
    assert.equal(logic.snapshotFromResponse(response([agent(undefined)])).state, "unknown");
});

test("unavailable data clears agents and always shows an outlined gray state", () => {
    const result = logic.unavailable("Timed out");
    assert.equal(result.state, "unknown");
    assert.equal(result.filled, false);
    assert.equal(result.visible, true);
    assert.equal(result.available, false);
    assert.equal(result.agents.length, 0);
    assert.equal(logic.summary(result), "Timed out");
});

test("agents are sorted by priority without losing identity", () => {
    const result = snapshot(["idle", "working", "done", "unknown", "blocked"]);
    assert.equal(result.agents.map(entry => entry.state).join(","), "blocked,done,working,idle,unknown");
    assert.equal(result.agents[0].paneId, "w1:p4");
});

test("titles and directories are normalized at the boundary", () => {
    const entry = logic.parseResponse(response([{
        ...agent("working"), terminal_title_stripped: "  Task\nname ",
        cwd: "/old", foreground_cwd: "/current"
    }]))[0];
    assert.equal(entry.title, "Task name");
    assert.equal(entry.directory, "/current");
});

test("title falls back to directory name, then agent kind", () => {
    assert.equal(logic.parseResponse(response([{ ...agent("idle"), cwd: "/home/project/" }]))[0].title, "project");
    assert.equal(logic.parseResponse(response([agent("idle")]))[0].title, "opencode");
});

test("summary counts all states", () => {
    assert.equal(logic.summary(snapshot(["idle", "blocked", "working", "idle"])), "1 blocked · 1 working · 2 idle");
});

test("robot retains status styling and click details without hover information", () => {
    const widget = fs.readFileSync(path.join(__dirname, "../HerdrWidget.qml"), "utf8");
    assert.match(widget, /name: "smart_toy"/);
    assert.match(widget, /filled: root\.snapshot\.filled/);
    assert.match(widget, /color: root\.stateColor/);
    assert.match(widget, /Accessible\.onPressAction: root\.triggerPopout\(\)/);
    assert.match(widget, /popoutContent: Component/);
    assert.doesNotMatch(widget, /HerdrTooltip|tooltipDelay|showTooltip|onHoveredChanged/);
    const hover = widget.match(/function triggerHoverPopout\(widgetHostId\) \{([^}]+)\}/);
    assert.ok(hover, "DMS hover popouts must be disabled for this widget");
    assert.equal(vm.runInNewContext(`(function(widgetHostId) {${hover[1]}})("test-widget")`), undefined);
    assert.equal(logic.tooltip, undefined);
    assert.equal(fs.existsSync(path.join(__dirname, "../HerdrTooltip.qml")), false);
});

test("every three-agent state combination follows the precedence rules", () => {
    const states = ["blocked", "done", "working", "idle", "unknown"];
    for (const a of states) for (const b of states) for (const c of states) {
        const combination = [a, b, c];
        const expected = combination.includes("blocked") ? "blocked"
            : combination.includes("done") ? "done"
            : combination.includes("working") ? "working"
            : combination.every(state => state === "idle") ? "idle" : "unknown";
        assert.equal(snapshot(combination).state, expected, combination.join(" + "));
    }
});
