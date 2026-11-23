import QtQuick
import Quickshell
import qs
import qs.ui

// What Markup makes of an agent's Markdown, pure: each of `cases` is what it shows, what Markup gives, and what that must be.
ShellRoot {
  id: root

  // Rich text without the theme's styles and colours, so a case reads as its structure.
  function bare(markdown) {
    return Markup.html(markdown).replace(/ style="[^"]*"| bgcolor="[^"]*"/g, "");
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
    ["inline code keeps its marks and links as written, and an unclosed backtick is text", () => bare("`a*b*` `[b](v)` and `open"), "<p><span>a*b*</span> <span>[b](v)</span> and `open</p>"],
    ["a fenced block is code as written: its links, emphasis and HTML stay text", () => bare("```sh\n[site](https://x) **no** <b>\n```"), "<table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr><td><table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr><td>[site](https://x) **no** &lt;b&gt;</td></tr></table></td></tr></table>"],
    ["a fence still streaming in runs to the end, its blank lines kept", () => bare("```\nopen\n\nstill").includes("<td>open<br><br>still</td>"), true],
    ["a list nests by indent", () => bare("- a\n- b\n  - c"), "<ul><li>a</li><li>b<ul><li>c</li></ul></li></ul>"],
    ["a numbered list starts at its first number", () => [bare("3. x\n4. y"), bare("1) x")], ["<ol start=\"3\"><li>x</li><li>y</li></ol>", "<ol><li>x</li></ol>"]],
    ["a loose list is one list, and an indented line goes on with its item", () => [bare("- a\n\n- b"), bare("1. one\n   more")], ["<ul><li>a</li><li>b</li></ul>", "<ol><li>one more</li></ol>"]],
    ["a paragraph's lines join, and a heading or a list ends it", () => bare("one\ntwo\n# Head\n- item"), "<p>one two</p><p><b>Head</b></p><ul><li>item</li></ul>"],
    ["a table's header is bold, each column aligned as its separator says, a short row filled", () => bare("| L | C | R |\n|:--|:-:|--:|\n| 1 |").match(/<td align="\w+">(<b>)?\w*/g),
      ["<td align=\"left\"><b>L", "<td align=\"center\"><b>C", "<td align=\"right\"><b>R", "<td align=\"left\">1", "<td align=\"center\">", "<td align=\"right\">"]],
    ["a rule is a divider without text", () => bare("---"), "<table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr><td colspan=\"1\"></td></tr></table>"],
    ["a quote's blocks render inside it", () => bare("> *w*").includes("<td><p><i>w</i></p></td>"), true],
    ["a link or an image shows by its text", () => bare("[site](https://e.com) ![pic](https://e.com/a.png)"), "<p>site pic</p>"],
    ["HTML shows as text, so a script never runs", () => bare("<script>alert(1)</script> & <img src=x>"), "<p>&lt;script&gt;alert(1)&lt;/script&gt; &amp; &lt;img src=x&gt;</p>"],
    ["nothing it renders fetches: no link, image or stylesheet in any block", () => /<a |<img|href|src=|url\(|<link|<style/.test(Markup.html(everything)), false],
    ["closing numbered options are the choices, taken out of the text", () => Markup.options("Pick one:\n1. Red\n2) Blue\n"), { text: "Pick one:", options: ["Red", "Blue"] }],
    ["one option is no choice", () => Markup.options("Pick:\n1. Red").options, []],
    ["options not counted from 1 are no choice", () => Markup.options("Then:\n2. a\n3. b").options, []],
    ["a numbered list before more text is no choice", () => Markup.options("Steps:\n1. a\n2. b\nThen done.").options, []],
    ["an answer that is only a list is no choice", () => Markup.options("1. a\n2. b"), { text: "1. a\n2. b", options: [] }],
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
