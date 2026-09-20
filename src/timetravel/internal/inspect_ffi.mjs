const indentation = 2;
const maximumDepth = 20;

// Gleam values compile to JavaScript objects and constructor classes. This is
// deliberately a development convenience: minifiers may rename those classes.
export function inspectValue(value) {
  return format(value, 0, new WeakSet());
}

export function constructorName(value) {
  return value?.constructor?.name || typeof value;
}

function format(value, depth, seen) {
  if (value === undefined) return "Nil";
  if (value === null) return "//js(null)";
  if (value === true) return "True";
  if (value === false) return "False";
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number" || typeof value === "bigint") {
    return String(value);
  }
  if (typeof value === "function") return "fn(...) { ... }";
  if (depth >= maximumDepth) return "…";
  if (typeof value !== "object") return String(value);
  if (seen.has(value)) return "<circular>";

  seen.add(value);
  let formatted;

  if (Array.isArray(value)) {
    formatted = formatSequence("#(", ")", value, depth, seen);
  } else if (isGleamList(value)) {
    formatted = formatSequence("[", "]", listItems(value), depth, seen);
  } else {
    formatted = formatObject(value, depth, seen);
  }

  seen.delete(value);
  return formatted;
}

function isGleamList(value) {
  const name = value?.constructor?.name;
  return name === "Empty" || name === "NonEmpty";
}

function listItems(list) {
  const items = [];
  let current = list;
  while (current?.constructor?.name === "NonEmpty") {
    items.push(current.head);
    current = current.tail;
  }
  return items;
}

function formatSequence(open, close, values, depth, seen) {
  if (values.length === 0) return open + close;
  const pad = " ".repeat((depth + 1) * indentation);
  const closingPad = " ".repeat(depth * indentation);
  const body = values
    .map((item) => pad + format(item, depth + 1, seen))
    .join(",\n");
  return `${open}\n${body}\n${closingPad}${close}`;
}

function formatObject(value, depth, seen) {
  const name = value.constructor?.name || "Object";
  const entries = Object.entries(value);
  if (entries.length === 0) return name;

  const pad = " ".repeat((depth + 1) * indentation);
  const closingPad = " ".repeat(depth * indentation);
  const body = entries
    .map(([key, item]) => {
      const formatted = format(item, depth + 1, seen);
      return /^\d+$/.test(key)
        ? `${pad}${formatted}`
        : `${pad}${key}: ${formatted}`;
    })
    .join(",\n");
  return `${name}(\n${body}\n${closingPad})`;
}
