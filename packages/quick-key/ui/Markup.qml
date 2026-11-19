pragma Singleton

import Quickshell

// What the kit reads in an agent's Markdown (ACP's text format), in one place: its plain lines, its safe form, its closing options, whether it holds a table.
Singleton {
  readonly property var tableSeparator: /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$/

  // As compact lines show it: its marks gone, an image or a link by its text, a table's rows as columns.
  function plain(markdown) {
    return markdown.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\*\*|__|~~|`/g, "").replace(/\*([^*\n]+)\*/g, "$1").replace(/^#+\s+/gm, "")
      .split("\n").filter(line => !tableSeparator.test(line.trim())).join("\n").replace(/^\|\s*|\s*\|\s*$/gm, "").replace(/\s*\|\s*/g, "  ");
  }

  // As `Markdown` renders it: outside code (between backticks) an image or a link becomes its text, a bare address stays text, `<` a character, so nothing is fetched and no HTML runs.
  function safe(markdown) {
    return markdown.split("`").map((part, i) => i % 2 ? part : part.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\b(https?|ftp):\/\//g, "$1\\://").replace(/\bwww\./g, "www\\.").replace(/</g, "\\<")).join("`");
  }

  // A closing numbered list (1. 2. ...) as the options a digit picks, taken out of the text: { text, options }.
  function options(markdown) {
    const lines = markdown.trim().split("\n");
    let start = lines.length;
    while (start > 0 && /^\s*\d+[.)]\s+\S/.test(lines[start - 1])) start--;
    const listed = lines.slice(start);
    const picked = listed.length >= 2 && start > 0 && listed.every((line, i) => parseInt(line) === i + 1);
    return { text: (picked ? lines.slice(0, start) : lines).join("\n").trim(), options: picked ? listed.map(line => line.replace(/^\s*\d+[.)]\s+/, "").trim()) : [] };
  }

  function hasTable(markdown) {
    return markdown.split("\n").some(line => tableSeparator.test(line.trim()));
  }
}
