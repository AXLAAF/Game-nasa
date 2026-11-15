# Visual direction v2 — cinematic gameplay

Applied skill: frontend-design (Anthropic, installed 1.1.1).
Audience: NASA Space Apps judges and game players. Job: show a playable space-mission loop in 29.7 seconds.

Palette: void #080c16; film black #030609; ink #f4ebd9; flight amber #f09c14; telemetry cyan #38bdf8; warning terracotta #c83e2b. These are established game colors.
Type: Pixelta for the game wordmark and cinematic display; Exo 2 SemiBold/Regular for explanation and subtitles; Space Mono only for numeric sequence/telemetry. All supplied by the repository.

Rejected layout: [persistent navigation | reduced static screenshot]. It suppressed action and resembled an instructional presentation.
Chosen layout: [edge-to-edge moving gameplay], [short step title low left], [one subtitle centered in the bottom safe area]. Opening/closing use the actual game planet and space assets with Pixelta type.

One memorable moment: the wordmark snaps into focus at frame 240 from a scale and position surge, with native EffectCraft shutter blur. Motion elsewhere follows action: rocket rise, orbit pan, warning push, reentry shake. No arbitrary decorative headings or panel UI.

Check: exact script; 1920x1080; safe margins 96px; no text collisions; native motion blur on animated image/title layers, off on subtitles; real moving Godot captures; existing logo geometry; no substitute fonts; 891 frames. This is a fixed-format video, not an interactive UI.
