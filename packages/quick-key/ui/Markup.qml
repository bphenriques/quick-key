pragma Singleton

import Quickshell
import qs

// What the kit reads in an agent's Markdown (ACP's text format), in one place: its plain lines, its rich text, its closing options, whether it holds a table.
Singleton {
  readonly property var tableSeparator: /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$/
  readonly property var listItem: /^(\s*)([-*+]|(\d+)[.)])\s+(.*)$/

  // As compact lines show it: its marks gone, an image or a link by its text, a table's rows as columns.
  function plain(markdown) {
    return markdown.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\*\*|__|~~|`/g, "").replace(/\*([^*\n]+)\*/g, "$1").replace(/^#+\s+/gm, "")
      .split("\n").filter(line => !tableSeparator.test(line.trim())).join("\n").replace(/^\|\s*|\s*\|\s*$/gm, "").replace(/\s*\|\s*/g, "  ");
  }

  // As `Markdown` renders it: rich text of the kit's own making (AGENTS.md rule 9), the answer's text escaped and an image or a link by its text, so nothing is fetched and no HTML runs.
  function html(markdown) {
    return blocks(markdown.replace(/\r/g, "").split("\n"));
  }

  function blocks(lines) {
    const out = [];
    // A table already ends in its gap (closing).
    const top = () => out.length && !out[out.length - 1].endsWith("</table>") ? Config.theme.spacing : 0;
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      const fence = line.match(/^\s*(`{3,}|~{3,})/);
      if (!line.trim()) {
        i++;
      } else if (fence) {
        // Unclosed, as while it streams in, it runs to the end.
        const close = lines.findIndex((next, j) => j > i && next.trim().startsWith(fence[1]));
        const end = close < 0 ? lines.length : close;
        out.push(code(lines.slice(i + 1, end), top()));
        i = end + 1;
      } else if (startsTable(lines, i)) {
        let end = i + 2;
        while (end < lines.length && lines[end].includes("|") && lines[end].trim()) end++;
        out.push(table(cells(line), cells(lines[i + 1]), lines.slice(i + 2, end).map(cells), top()));
        i = end;
      } else if (/^\s{0,3}#{1,6}\s/.test(line)) {
        out.push(paragraph("<b>" + inline(line.replace(/^\s*#+\s+/, "").replace(/\s+#+\s*$/, "")) + "</b>", top()));
        i++;
      } else if (/^\s{0,3}([-*_])(\s*\1){2,}\s*$/.test(line)) {
        out.push(rule(top()));
        i++;
      } else if (/^\s{0,3}>/.test(line)) {
        let end = i;
        while (end < lines.length && /^\s{0,3}>/.test(lines[end])) end++;
        out.push(quote(blocks(lines.slice(i, end).map(quoted => quoted.replace(/^\s{0,3}>\s?/, ""))), top()));
        i = end;
      } else if (listItem.test(line)) {
        const items = [];
        while (i < lines.length) {
          const item = lines[i].match(listItem);
          if (item) items.push({ indent: item[1].length, number: item[3] === undefined ? 0 : parseInt(item[3]), text: item[4] });
          else if (/^\s{2,}\S/.test(lines[i])) items[items.length - 1].text += " " + lines[i].trim();
          else if (lines[i].trim() || !/^\s*([-*+]|\d+[.)])\s|^\s{2,}\S/.test(lines[i + 1] ?? "")) break;
          i++;
        }
        out.push(list(items, top()));
      } else {
        let end = i + 1;
        while (end < lines.length && lines[end].trim() && !interrupts(lines, end)) end++;
        out.push(paragraph(inline(lines.slice(i, end).map(joined => joined.trim()).join(" ")), top()));
        i = end;
      }
    }
    // Nothing follows the last table, so its gap goes.
    return out.join("").replace(/<tr><td colspan="\d+" style="padding-top:\d+px; font-size:1px"><\/td><\/tr><\/table>$/, "</table>");
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
