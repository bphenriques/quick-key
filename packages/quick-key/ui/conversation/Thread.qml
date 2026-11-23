pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
import qs.ui

// A conversation's turns, built only where they show, so a long one opens as fast as a short one; laid out from the newest up, so it rests at its end however tall the turns built meanwhile. Empty, it says `emptyText`.
ListView {
  id: root

  property string emptyText
  property string emptyTone: "dim"

  function page(down) {
    // A conversation shorter than the view has nothing above to page to; laid out upward, the bound below would leave a gap.
    if (contentHeight <= height) return;
    contentY = Math.max(originY, Math.min(originY + contentHeight - height, contentY + (down ? 1 : -1) * height * 0.8));
  }

  verticalLayoutDirection: ListView.BottomToTop
  clip: true
  // What scrolled away above fades out, so a cut bubble shows no edge; only while something is cut.
  layer.enabled: !atYBeginning
  layer.effect: MultiEffect {
    maskEnabled: true
    maskSource: fadeMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }
  spacing: Config.theme.padding
  boundsBehavior: Flickable.StopAtBounds
  // No turn is current: a ListView keeps its current item built wherever it is, and makes the first current again as its count changes.
  onCountChanged: currentIndex = -1

  // On the view itself, not its content, which a list laid out upward places out of sight while empty.
  Label {
    parent: root
    anchors.top: parent.top
    visible: root.count === 0
    width: root.width
    wrapMode: Text.Wrap
    tone: root.emptyTone
    text: root.emptyText
  }

  // Clear at the top, opaque a line down.
  Rectangle {
    id: fadeMask
    parent: root
    visible: false
    layer.enabled: true
    width: root.width
    height: root.height
    gradient: Gradient {
      GradientStop {
        position: 0
        color: "transparent"
      }
      GradientStop {
        position: Math.min(1, Metrics.line / Math.max(1, root.height))
        color: "black"
      }
    }
  }
}
