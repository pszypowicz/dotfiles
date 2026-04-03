// Auto-theme for Claude Code
// Reads OS appearance from os-state's theme file
// and exposes reactive state for the loader hook to subscribe to.
import { readFileSync, watch } from "node:fs";
import { register } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const home = process.env.HOME || "/Users/" + process.env.USER;
const themeFile = join(home, ".config", "os-state", "state", "appearance", "theme");

let currentIsDark = true;

function readThemeFile() {
  try {
    return readFileSync(themeFile, "utf-8").trim() === "dark";
  } catch {
    return true; // default to dark if file missing
  }
}

currentIsDark = readThemeFile();

// Watch for changes from the Swift daemon
const listeners = new Set();
try {
  watch(themeFile, () => {
    const wasDark = currentIsDark;
    currentIsDark = readThemeFile();
    if (currentIsDark !== wasDark) {
      for (const cb of listeners) cb(currentIsDark);
    }
  });
} catch {
  // file doesn't exist yet — initial value still works
}

globalThis.__ccThemeState = {
  get isDark() { return currentIsDark; },
  onChange(cb) {
    listeners.add(cb);
    return () => listeners.delete(cb);
  },
};

register(new URL("./loader.mjs", import.meta.url));
