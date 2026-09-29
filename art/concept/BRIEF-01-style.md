# Brief 01 — Style sheet (key art, backgrounds, palette, names)

You are the art and writing lead for a mobile game jam entry. Claude Code builds the
mechanics in Godot; you make the creative work. The human director (Luqman) approves.

## The game
Working title: "Flop Siege". Jam: Slapjam 2026, theme **Castles** ("build one, storm one,
defend one — a castle must be at the heart of your game"). Judged on Fun, Visual Appeal,
Theme.

A funny 2D physics game for phones, held in **portrait**. A wobbly castle sits on top of a
grassy cliff on the upper RIGHT of the screen. At the bottom LEFT, on the valley floor, is
your siege camp with a catapult, lobbing up and to the right. You drag back and flick **floppy ragdoll knights** up at the castle.
Wooden and stone blocks topple, knights flop and bounce, and you win by knocking the pompous
little **king** off his tower. Slapstick, never violent: knights bounce off and wave, nobody
gets hurt, the king lands on his bottom and pouts.

## The look (locked)
- **Flat 2D cartoon, storybook**: bold simple shapes, flat colours with one soft shadow
  tone, thick dark outlines (#2a2420), bright warm daylight. Think a children's picture book
  crossed with Angry Birds — clean and readable on a small phone.
- Castle blocks: warm wood planks, grey-blue stone, red-and-cream flags.
- Knights: round heads in bucket helmets, silver armour, colourful tabards.
- King: short, round, big gold crown, red robe with white fur trim.

## Deliverables (save into this folder, art/concept/)
1. `key-art.png` — ONE key image, 1080x1920 portrait: the castle on its cliff at the upper
   right, a knight flying through the air mid-flop toward it, the king on the top tower
   looking alarmed, the catapult camp at the bottom left. No text.
2. `bg-sky.png` — 1080x1920 portrait BACKGROUND ONLY, no castle, no characters, no
   catapult: sky with soft clouds and distant hills filling the whole frame. It sits behind
   everything.
3. `bg-valley.png` — 1080x1920 portrait BACKGROUND ONLY, same style and lighting as
   bg-sky: the same sky and distant hills, plus a green grassy **cliff plateau** on the RIGHT: its flat
   top edge runs straight and horizontal at exactly 56% of the image height (y = 1075 px),
   from x = 36% (389 px) all the way to the right edge. At x = 36% a near-vertical cliff face
   drops down to a flat green valley floor that fills the bottom 12% of the image (from
   y = 1690 px down) across the full width. The left 36% above the valley is open sky and
   far hills. A few tents on the valley floor at the far left edge only (x < 10%), small. The cliff top and valley floor must be flat and horizontal because the game puts
   physics blocks on them. Nothing standing on the cliff top.
4. `palette.md` — 10 named colours with hex codes (sky, grass, cliff, wood, wood shadow,
   stone, stone shadow, armour, king red, gold, outline) drawn from the key art.
5. `style-notes.md` — 10 short bullet rules so every later asset matches.
6. `names.md` — 10 candidate game names (English, short, funny, castle + flopping
   knights), one line each. Mark your top 3.

All text in English. Do not write any game code.
