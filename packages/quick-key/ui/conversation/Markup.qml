pragma Singleton

import Quickshell
import qs
import qs.ui

// What the kit reads in an agent's Markdown (ACP's text format), in one place: its plain lines, its rich text, whether it holds a table.
Singleton {
  readonly property var tableSeparator: /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$/
  readonly property var listItem: /^(\s*)([-*+]|(\d+)[.)])\s+(.*)$/
  readonly property var fenceLine: /^\s*(`{3,}|~{3,})/
  readonly property var headingLine: /^ {0,3}#{1,6}\s/
  readonly property var ruleLine: /^\s{0,3}([-*_])(\s*\1){2,}\s*$/
  readonly property var quoteLine: /^\s{0,3}>/

  // As compact lines show it, from the blocks html() renders, so the two agree on what a block is.
  function plain(markdown) {
    const lines = linesOf(markdown);
    return spans(lines).map(([start, end]) => plainBlock(lines.slice(start, end))).filter(text => text !== "").join("\n");
  }

  function plainBlock(lines) {
    const line = lines[0];
    const fence = line.match(fenceLine);
    if (fence) return lines.slice(1, lines.length > 1 && lines[lines.length - 1].trim().startsWith(fence[1]) ? -1 : lines.length).join("\n");
    if (startsTable(lines, 0)) return [line].concat(lines.slice(2)).map(row => cells(row).map(bare).join("  ")).join("\n");
    if (headingLine.test(line)) return bare(line.replace(/^\s*#+\s+/, "").replace(/\s+#+\s*$/, ""));
    if (ruleLine.test(line)) return "";
    if (quoteLine.test(line)) return plain(lines.map(quoted => quoted.replace(/^\s{0,3}>\s?/, "")).join("\n"));
    if (listItem.test(line)) return lines.filter(each => each.trim()).map(bare).join("\n");
    return bare(lines.map(joined => joined.trim()).join(" "));
  }

  function bare(text) {
    return text.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\*\*|__|~~|`/g, "").replace(/\*([^*\n]+)\*/g, "$1");
  }

  // Rich text of the kit's own making (rule 9): text escaped, an image or a link by its text, so nothing is fetched and no HTML runs.
  function html(markdown) {
    return blocks(linesOf(markdown));
  }

  // Its blocks gathered into pieces of at least `size` characters, as written, as `Markdown` renders one apiece: a stream redraws only its last, and an answer arriving whole is a few documents, not one per block.
  function split(markdown, size) {
    const lines = linesOf(markdown);
    const out = [];
    let first = -1;
    let last = 0;
    let length = 0;
    for (const [start, end] of spans(lines)) {
      if (first < 0) first = start;
      last = end;
      length += lines.slice(start, end).join("\n").length;
      if (length < size) continue;
      out.push(lines.slice(first, end).join("\n"));
      first = -1;
      length = 0;
    }
    if (first >= 0) out.push(lines.slice(first, last).join("\n"));
    return out;
  }

  function linesOf(markdown) {
    return markdown.replace(/\r/g, "").split("\n");
  }

  function blocks(lines) {
    const out = [];
    // A table already ends in its gap (closing).
    const top = () => out.length && !out[out.length - 1].endsWith("</table>") ? Config.theme.spacing : 0;
    for (const [start, end] of spans(lines)) out.push(block(lines.slice(start, end), top()));
    // Nothing follows the last table, so its gap goes.
    return out.join("").replace(/<tr><td colspan="\d+" style="padding-top:\d+px; font-size:1px"><\/td><\/tr><\/table>$/, "</table>");
  }

  // Where each block starts and ends, [start, end), the blank lines between them left out.
  function spans(lines) {
    const out = [];
    for (let i = 0; i < lines.length;) {
      if (!lines[i].trim()) {
        i++;
        continue;
      }
      const end = blockEnd(lines, i);
      out.push([i, end]);
      i = end;
    }
    return out;
  }

  function blockEnd(lines, i) {
    const line = lines[i];
    const fence = line.match(fenceLine);
    let end = i + 1;
    if (fence) {
      // Unclosed, as while it streams in, it runs to the end.
      const close = lines.findIndex((next, j) => j > i && next.trim().startsWith(fence[1]));
      return close < 0 ? lines.length : close + 1;
    }
    if (startsTable(lines, i)) {
      end = i + 2;
      while (end < lines.length && lines[end].includes("|") && lines[end].trim()) end++;
    } else if (headingLine.test(line) || ruleLine.test(line)) {
      return end;
    } else if (quoteLine.test(line)) {
      while (end < lines.length && quoteLine.test(lines[end])) end++;
    } else if (listItem.test(line)) {
      // A blank line goes on with the list when an item or an indented line follows it.
      while (end < lines.length && (listItem.test(lines[end]) || /^\s{2,}\S/.test(lines[end]) || !lines[end].trim() && /^\s*([-*+]|\d+[.)])\s|^\s{2,}\S/.test(lines[end + 1] ?? ""))) end++;
    } else {
      while (end < lines.length && lines[end].trim() && !interrupts(lines, end)) end++;
    }
    return end;
  }

  function block(lines, top) {
    const line = lines[0];
    const fence = line.match(fenceLine);
    if (fence) {
      const closed = lines.length > 1 && lines[lines.length - 1].trim().startsWith(fence[1]);
      return code(lines.slice(1, closed ? -1 : lines.length), top);
    }
    if (startsTable(lines, 0)) return table(cells(line), cells(lines[1]), lines.slice(2).map(cells), top);
    if (headingLine.test(line)) return paragraph("<b>" + inline(line.replace(/^\s*#+\s+/, "").replace(/\s+#+\s*$/, "")) + "</b>", top);
    if (ruleLine.test(line)) return rule(top);
    if (quoteLine.test(line)) return quote(blocks(lines.map(quoted => quoted.replace(/^\s{0,3}>\s?/, ""))), top);
    if (listItem.test(line)) {
      const items = [];
      for (const each of lines) {
        const item = each.match(listItem);
        if (item) items.push({ indent: item[1].length, number: item[3] === undefined ? 0 : parseInt(item[3]), text: item[4] });
        else if (each.trim()) items[items.length - 1].text += " " + each.trim();
      }
      return list(items, top);
    }
    return paragraph(inline(lines.map(joined => joined.trim()).join(" ")), top);
  }

  function startsTable(lines, i) {
    return lines[i].includes("|") && tableSeparator.test((lines[i + 1] ?? "").trim());
  }

  // A line that starts a block of its own, ending the paragraph before it.
  function interrupts(lines, i) {
    return /^\s*(`{3,}|~{3,})|^\s{0,3}(#{1,6}\s|>)/.test(lines[i]) || listItem.test(lines[i]) || startsTable(lines, i);
  }

  function cells(row) {
    return row.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map(cell => cell.trim());
  }

  function escaped(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // Code between backticks on a faint wash; outside it, emphasis, and an image or a link by its text.
  function inline(text) {
    const parts = text.split("`");
    return parts.map((part, i) => {
      if (i % 2 === 0) return emphasis(escaped(part));
      if (i === parts.length - 1) return "`" + emphasis(escaped(part));
      return "<span style=\"background-color:" + css(Tone.wash("normal", 0.5)) + "\">" + escaped(part) + "</span>";
    }).join("");
  }

  function emphasis(text) {
    return text.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\*\*(.+?)\*\*|__(.+?)__/g, (match, stars, unders) => "<b>" + (stars ?? unders) + "</b>")
      .replace(/~~(.+?)~~/g, "<s>$1</s>").replace(/\*([^*\s][^*]*?)\*/g, "<i>$1</i>").replace(/(^|\W)_([^_\s][^_]*?)_(?!\w)/g, "$1<i>$2</i>");
  }

  // A colour as Qt's rich text reads one, its alpha first.
  function css(color) {
    return "#" + [color.a, color.r, color.g, color.b].map(value => Math.round(value * 255).toString(16).padStart(2, "0")).join("");
  }

  function prose(top) {
    return "margin:" + top + "px 0 0 0; line-height:" + Math.round(Config.theme.lineHeight * 100) + "%";
  }

  function paragraph(content, top) {
    return "<p style=\"" + prose(top) + "\">" + content + "</p>";
  }

  // Nested by indent: deeper items belong to the item before them.
  function list(items, top) {
    const tag = items[0].number ? "ol" : "ul";
    let body = "";
    for (let i = 0; i < items.length;) {
      let end = i + 1;
      while (end < items.length && items[end].indent > items[0].indent) end++;
      body += "<li style=\"" + prose(i === 0 ? top : 0) + "\">" + inline(items[i].text) + (end > i + 1 ? list(items.slice(i + 1, end), 0) : "") + "</li>";
      i = end;
    }
    return "<" + tag + (items[0].number > 1 ? " start=\"" + items[0].number + "\"" : "") + ">" + body + "</" + tag + ">";
  }

  // A table's start, `wide` across the answer. Qt ignores a table's margins and the next block's, so the gap above is a block of its own and the gap below a row (closing).
  function opening(top, wide) {
    return (top ? "<p style=\"margin:" + top + "px 0 0 0; font-size:1px\">&nbsp;</p>" : "") + "<table" + (wide ? " width=\"100%\"" : "") + " cellspacing=\"0\" cellpadding=\"0\">";
  }

  function closing(columns) {
    return "<tr><td colspan=\"" + columns + "\" style=\"padding-top:" + Config.theme.spacing + "px; font-size:1px\"></td></tr></table>";
  }

  // The wash on a table of its own, as Qt's rich text draws a cell's padding outside the cell's background.
  function code(lines, top) {
    return opening(top, true) + "<tr><td><table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" bgcolor=\"" + css(Tone.wash("normal", 0.5)) + "\"><tr><td style=\"padding:" + Config.theme.itemPaddingY + "px " + Config.theme.itemPaddingX
      + "px; white-space:pre-wrap\">" + lines.map(escaped).join("<br>") + "</td></tr></table></td></tr>" + closing(1);
  }

  function spacer(width) {
    return "<td width=\"" + width + "\"></td>";
  }

  // Columns apart, the header bold over one divider: as the menu lists, never a grid.
  function table(header, separator, rows, top) {
    const aligns = separator.map(cell => /^:-+:$/.test(cell) ? "center" : /-:$/.test(cell) ? "right" : "left");
    const pad = Config.theme.itemPaddingY;
    const row = (values, bold) => "<tr>" + header.map((unused, i) => "<td align=\"" + (aligns[i] ?? "left") + "\" style=\"padding:" + (bold ? 0 : pad) + "px 0 " + pad + "px 0\">"
      + (bold ? "<b>" + inline(values[i] ?? "") + "</b>" : inline(values[i] ?? "")) + "</td>").join(spacer(2 * Config.theme.spacing)) + "</tr>";
    return opening(top, false) + row(header, true) + divider(2 * header.length - 1) + rows.map(cells => row(cells, false)).join("") + closing(2 * header.length - 1);
  }

  // A row one pixel high, as Qt's rich text draws no border on one side of a cell.
  function divider(columns) {
    return "<tr><td colspan=\"" + columns + "\" bgcolor=\"" + css(Config.colors.border) + "\" style=\"font-size:1px\"></td></tr>";
  }

  function rule(top) {
    return opening(top, true) + divider(1) + closing(1);
  }

  function quote(content, top) {
    return opening(top, false) + "<tr><td width=\"" + 2 * Config.theme.borderWidth + "\" bgcolor=\"" + css(Config.colors.border) + "\"></td>" + spacer(Config.theme.spacing) + "<td style=\"color:" + css(Tone.color("dim")) + "\">"
      + content + "</td></tr>" + closing(3);
  }

  function hasTable(markdown) {
    return markdown.split("\n").some(line => tableSeparator.test(line.trim()));
  }
}
