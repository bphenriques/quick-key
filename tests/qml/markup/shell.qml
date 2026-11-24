import QtQuick
import Quickshell
import qs
import qs.ui
import qs.ui.conversation

// What Markup makes of an agent's Markdown, pure: each of `cases` is what it shows, what Markup gives, and what that must be.
ShellRoot {
  id: root

  // Rich text without the theme's styles and colours, so a case reads as its structure.
  function bare(markdown) {
    return Markup.html(markdown).replace(/ style="[^"]*"| bgcolor="[^"]*"/g, "");
  }

  // A quote as bare() gives it, around its blocks.
  function quote(inner) {
    return "<table cellspacing=\"0\" cellpadding=\"0\"><tr><td width=\"2\"></td><td width=\"8\"></td><td>" + inner + "</td></tr></table>";
  }

  function same(what, got, want) {
    const right = JSON.stringify(got) === JSON.stringify(want);
    if (!right) console.info("# " + what + " gave " + JSON.stringify(got));
    return right;
  }

  readonly property string everything: "# H\n\n**b** `c` [l](https://e.com/l)\n\n```\n[l](https://e.com/c)\n```\n\n- [l](https://e.com/i)\n\n| ![i](https://e.com/t.png) |\n|---|\n\n> ![i](https://e.com/q.png)"

  readonly property var cases: [
    ["a heading is a bold paragraph, its closing hashes dropped", () => bare("## Setup ##"), "<p><b>Setup</b></p>"],
    ["a hash without a space is text", () => bare("#not one"), "<p>#not one</p>"],
    ["emphasis is bold, italic by either mark, or struck; underscores inside a word stay", () => bare("**b** *i* _u_ ~~s~~ snake_case_name"), "<p><b>b</b> <i>i</i> <i>u</i> <s>s</s> snake_case_name</p>"],
    ["double underscores inside a word stay, a tool's name among them", () => [bare("__b__ mcp__tasks__delete_done"), Markup.plain("__b__ mcp__tasks__delete_done")], ["<p><b>b</b> mcp__tasks__delete_done</p>", "b mcp__tasks__delete_done"]],
    ["inline code keeps its marks and links as written, and an unclosed backtick is text", () => bare("`a*b*` `[b](v)` and `open"), "<p><span>a*b*</span> <span>[b](v)</span> and `open</p>"],
    ["emphasis spans inline code inside it", () => bare("**a `b` c** and *`d`*"), "<p><b>a <span>b</span> c</b> and <i><span>d</span></i></p>"],
    ["a fenced block is code as written: its links, emphasis and HTML stay text", () => bare("```sh\n[site](https://x) **no** <b>\n```"), "<table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr><td><table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr><td>[site](https://x) **no** &lt;b&gt;</td></tr></table></td></tr></table>"],
    ["a fence still streaming in runs to the end, its blank lines kept", () => bare("```\nopen\n\nstill").includes("<td>open<br><br>still</td>"), true],
    ["a list nests by indent", () => bare("- a\n- b\n  - c"), "<ul><li>a</li><li>b<ul><li>c</li></ul></li></ul>"],
    ["a numbered list starts at its first number", () => [bare("3. x\n4. y"), bare("1) x")], ["<ol start=\"3\"><li>x</li><li>y</li></ol>", "<ol><li>x</li></ol>"]],
    ["a loose list is one list, and an indented line goes on with its item", () => [bare("- a\n\n- b"), bare("1. one\n   more")], ["<ul><li>a</li><li>b</li></ul>", "<ol><li>one more</li></ol>"]],
    ["a line right under an item goes on with it, unindented too; after a blank line it is a paragraph", () => [bare("- item\ncontinued"), bare("- item\n\nafter")], ["<ul><li>item continued</li></ul>", "<ul><li>item</li></ul><p>after</p>"]],
    ["a paragraph's lines join, and a heading or a list ends it", () => bare("one\ntwo\n# Head\n- item"), "<p>one two</p><p><b>Head</b></p><ul><li>item</li></ul>"],
    ["a table's header is bold, each column aligned as its separator says, a short row filled", () => bare("| L | C | R |\n|:--|:-:|--:|\n| 1 |").match(/<td align="\w+">(<b>)?\w*/g),
      ["<td align=\"left\"><b>L", "<td align=\"center\"><b>C", "<td align=\"right\"><b>R", "<td align=\"left\">1", "<td align=\"center\">", "<td align=\"right\">"]],
    ["an escaped pipe is text in its cell, not a column", () => [bare("| a \\| b | c |\n|---|---|").match(/<b>[^<]*<\/b>/g), Markup.plain("| a \\| b | c |\n|---|---|")], [["<b>a | b</b>", "<b>c</b>"], "a | b  c"]],
    ["a rule is a divider without text", () => bare("---"), "<table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr><td colspan=\"1\"></td></tr></table>"],
    ["a quote's blocks render inside it", () => bare("> *w*").includes("<td><p><i>w</i></p></td>"), true],
    ["a quote nests as written up to three deep", () => [1, 2, 3].map(depth => bare("> ".repeat(depth) + "x")), [quote("<p>x</p>"), quote(quote("<p>x</p>")), quote(quote(quote("<p>x</p>")))]],
    ["a deeper quote renders three deep, as each level multiplies its layout time", () => bare("> ".repeat(30) + "x"), quote(quote(quote("<p>x</p>")))],
    ["a link or an image shows by its text", () => bare("[site](https://e.com) ![pic](https://e.com/a.png)"), "<p>site pic</p>"],
    ["a link whose address holds parentheses shows by its text alone", () => [bare("[Foo](https://e.com/wiki/Foo_(bar)) after"), Markup.plain("[Foo](https://e.com/wiki/Foo_(bar)) after")], ["<p>Foo after</p>", "Foo after"]],
    ["HTML shows as text, so a script never runs", () => bare("<script>alert(1)</script> & <img src=x>"), "<p>&lt;script&gt;alert(1)&lt;/script&gt; &amp; &lt;img src=x&gt;</p>"],
    ["nothing it renders fetches: no link, image or stylesheet in any block", () => /<a |<img|href|src=|url\(|<link|<style/.test(Markup.html(everything)), false],
    ["a table is told by its separator row; a rule or a lone pipe is none", () => ["| a | b |\n|---|:-:|", "text\n---|---", "a | b", "---"].map(text => Markup.hasTable(text)), [true, true, false, false]]
  ]

  Suite {
    cases: root.cases.map(([what, got, want]) => ({
      name: what,
      timeout: 0,
      until: () => root.same(what, got(), want)
    }))
  }
}
