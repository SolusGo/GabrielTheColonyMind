# Gabriel map artwork refinement

Generated with the built-in imagegen tool on 7 September 2026.
The existing panorama was used as the edit reference. The selection map is a new image.
`Tools/build_art.py` compiles these PNG sources into legacy DDS textures.

## Dawn of Man panorama

Source: `Gabriel_Colony_Network_Map.png`; output: 1600x900 `Gabriel_Colony_Network_Map.dds`.

Use case: style-transfer. Edit target: supplied Gabriel colony network panorama. Refine this art for a Civilization V Dawn of Man loading illustration. Preserve the mountainous river valley, amber connected colonies, and central nexus. Keep a wide 16:9 composition. Improve painterly craftsmanship, clearer terrain and warmer dawn illumination, well-defined stone bridges, believable intricate domed architecture and terraced settlements. Replace over-sharp generic golden skyscraper needles with elegant low domes and a distinctive central amber-glass colony nexus. More readable river and forest detail, restrained fine golden routes, rich charcoal blue and muted natural green contrasted with honey gold, no excessive bloom. Sophisticated hand-painted strategy game concept art. No text, no UI, no watermark, no frame. Avoid an almost-black empty upper-left quarter: reveal atmospheric terrain there.

## Civilization-selection map

Source: `Gabriel_Selection_Map.png`; output: 360x410 uncompressed `Gabriel_Selection_Map.dds`.
The size matches `LargeMapImage` in the game's `GameSetupScreen.xml`.
`Civilizations.MapImage` selects this portrait; `DawnOfManImage` retains the panorama.

Use case: stylized-concept. Generate a new Civilization V civilization-selection MAP artwork for Gabriel, The Colony Mind. Portrait aspect ratio 36:41 (roughly 1080x1230), full bleed. A beautiful antique illustrated top-down cartographic map of a fictional compact colony realm, visibly a MAP rather than a cinematic landscape: coherent coastline with deep slate-blue sea at right, winding silver-blue river through the middle, engraved mountain ranges at top and left, small green forests, seven elegantly illustrated circular gold-and-black cities joined by fine amber routes in an organic ant-colony network. A grand domed amber-glass capital at center and six smaller colony nodes, plenty of discernible negative space between towns. Polished Civilization V loading-map style, parchment vellum with muted olive and warm stone land, fine sepia hatching and restrained gold ornament. Small tasteful gold ANT crest near lower left, with six legs and two antennae; subtle compass rose upper right. Readable when reduced to 360x410 pixels. No written labels, no words, no lettering, no UI, no outer decorative border, no watermark. Art must occupy the entire portrait, no black margin. Sophisticated geographic map with a crafted ink-and-watercolor look.
