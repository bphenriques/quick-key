.pragma library

// Each island's { y, height } in a screen `screen` tall, listed top to bottom and stacked up from `margin`, `gap` apart; a hidden one takes no room.
// The island at `cut` (-1 for none) is no taller than the screen leaves within its margins past every other shown island.
function of(heights, shown, cut, screen, margin, gap) {
  const sized = heights.map((height, i) => shown[i] ? height : 0);
  const taken = sized.reduce((sum, height, i) => shown[i] ? sum + height + gap : sum, -gap);
  if (cut >= 0 && shown[cut]) sized[cut] = Math.min(sized[cut], screen - 2 * margin - (taken - sized[cut]));
  let below = margin;
  const places = [];
  for (let i = sized.length - 1; i >= 0; i--) {
    places[i] = { y: screen - below - sized[i], height: sized[i] };
    if (shown[i]) below += sized[i] + gap;
  }
  return places;
}
