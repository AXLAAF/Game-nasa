import json, pathlib, subprocess

ROOT = pathlib.Path("/tmp/mz_trailer")
FC = "/home/alexykk/.local/bin/filmcraft-cli"
PROJ = ROOT / "margin_zero_trailer.fcproj"
OUT_MP4 = pathlib.Path("/home/alexykk/Downloads/MarginZero_Final_SpaceApps2026.mp4")

def run_fc(args):
    cmd = ["env", "-u", "DISPLAY", FC] + list(map(str, args))
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return res.stdout

def main():
    if PROJ.exists():
        PROJ.unlink()

    init_jsonl = ROOT / "scripts/fc_init.jsonl"
    media_paths = [
        str(ROOT / "renders/visual_master_v2.mp4"),
        str(ROOT / "vo/voice_stem.wav"),
        str(ROOT / "music/music_stem.wav"),
        str(ROOT / "sfx/sfx_stem.wav"),
        str(ROOT / "audio_trailer_master.wav"),
    ]
    steps = [
        {"id": "file.newProject", "params": {"name": "margin_zero_trailer"}},
        {"id": "file.newSequence", "params": {
            "name": "Margin Zero — Official Trailer 29.7s",
            "width": 1920, "height": 1080, "fps": 30,
            "sampleRate": 48000, "video": 1, "audio": 4, "mix": "Stereo"
        }},
        {"id": "file.import", "params": {"paths": media_paths}},
    ]
    init_jsonl.write_text("\n".join(json.dumps(s) for s in steps) + "\n")
    run_fc(["--save-as", PROJ, "run", init_jsonl])

    info = json.loads(run_fc(["--project", PROJ, "inspect"]))
    items_by_name = {}
    for child in info["project"]["root"]["children"]:
        items_by_name[child["name"]] = child["item"]
    print("Imported items:", items_by_name)

    place_steps = [
        {"id": "timeline.place", "params": {
            "item": items_by_name["visual_master_v2.mp4"],
            "track": "V1", "seconds": 0, "insert": false_val(),
            "duration": {"frame": 891}, "video": True, "audio": False
        }},
        {"id": "timeline.place", "params": {
            "item": items_by_name["voice_stem.wav"],
            "track": "A1", "seconds": 0, "insert": False,
            "duration": {"frame": 891}, "video": False, "audio": True
        }},
        {"id": "timeline.place", "params": {
            "item": items_by_name["music_stem.wav"],
            "track": "A2", "seconds": 0, "insert": False,
            "duration": {"frame": 891}, "video": False, "audio": True
        }},
        {"id": "timeline.place", "params": {
            "item": items_by_name["sfx_stem.wav"],
            "track": "A3", "seconds": 0, "insert": False,
            "duration": {"frame": 891}, "video": False, "audio": True
        }},
        {"id": "timeline.place", "params": {
            "item": items_by_name["audio_trailer_master.wav"],
            "track": "A4", "seconds": 0, "insert": False,
            "duration": {"frame": 891}, "video": False, "audio": True
        }},
        {"id": "timeline.setTrack", "params": {"track": "V1", "name": "Visual master v2 — EffectCraft (240 deg shutter)", "muted": False}},
        {"id": "timeline.setTrack", "params": {"track": "A1", "name": "English voice-over — ElevenLabs", "muted": False, "volumeDb": 0.0}},
        {"id": "timeline.setTrack", "params": {"track": "A2", "name": "Original music 120 BPM D minor — ElevenLabs", "muted": False, "volumeDb": 0.0}},
        {"id": "timeline.setTrack", "params": {"track": "A3", "name": "Cinematic SFX — ElevenLabs", "muted": False, "volumeDb": 0.0}},
        {"id": "timeline.setTrack", "params": {"track": "A4", "name": "Reference master — muted", "muted": True}},
        {"id": "markers.add", "params": {"target": "program", "time": 38102400000, "name": "vo_01.wav", "comment": "We are Team Skaar, from Mérida, Mexico.", "durationFrames": 77}},
        {"id": "markers.add", "params": {"target": "program", "time": 787449600000, "name": "vo_02.wav", "comment": "Our challenge: Space Mission Design Game. Students rarely see how a real mission is designed.", "durationFrames": 139}},
        {"id": "markers.add", "params": {"target": "program", "time": 2062609920000, "name": "vo_03.wav", "comment": "So we built Margin Zero: mission design with zero margin for error.", "durationFrames": 110}},
        {"id": "markers.add", "params": {"target": "program", "time": 3073593600000, "name": "vo_04.wav", "comment": "Pick a contract. Build a rocket on a tight budget.", "durationFrames": 82}},
        {"id": "markers.add", "params": {"target": "program", "time": 3830561280000, "name": "vo_05.wav", "comment": "Launch, and fly it yourself.", "durationFrames": 54}},
        {"id": "markers.add", "params": {"target": "program", "time": 4343673600000, "name": "vo_06.wav", "comment": "Space fights back, modeled on NASA and JPL open data.", "durationFrames": 112}},
        {"id": "markers.add", "params": {"target": "program", "time": 5862689280000, "name": "vo_07.wav", "comment": "Every flight ends with a debrief of what went wrong.", "durationFrames": 54}},
        {"id": "markers.add", "params": {"target": "program", "time": 6375801600000, "name": "vo_08.wav", "comment": "Training the next generation of mission designers.", "durationFrames": 88}},
        {"id": "markers.add", "params": {"target": "program", "time": 0, "name": "OPENING"}},
        {"id": "markers.add", "params": {"target": "program", "time": 762048000000, "name": "CHALLENGE"}},
        {"id": "markers.add", "params": {"target": "program", "time": 2032128000000, "name": "TITLE / HERO DROP"}},
        {"id": "markers.add", "params": {"target": "program", "time": 3048192000000, "name": "01 CONTRACT"}},
        {"id": "markers.add", "params": {"target": "program", "time": 3429216000000, "name": "02 BUILD"}},
        {"id": "markers.add", "params": {"target": "program", "time": 3810240000000, "name": "03 LAUNCH"}},
        {"id": "markers.add", "params": {"target": "program", "time": 4318272000000, "name": "04 FLY"}},
        {"id": "markers.add", "params": {"target": "program", "time": 5334336000000, "name": "05 LAND / NO VOICE"}},
        {"id": "markers.add", "params": {"target": "program", "time": 5842368000000, "name": "06 DEBRIEF"}},
        {"id": "markers.add", "params": {"target": "program", "time": 6350400000000, "name": "CLOSING"}},
        {"id": "sequence.setWorkArea", "params": {"start": 0, "end": 7544275200000}},
    ]
    place_jsonl = ROOT / "scripts/fc_place.jsonl"
    place_jsonl.write_text("\n".join(json.dumps(s) for s in place_steps) + "\n")
    run_fc(["--project", PROJ, "--save", "run", place_jsonl])
    print("Saved FilmCraft project:", PROJ)

    run_fc(["--project", PROJ, "export", OUT_MP4, "--format", "h264", "--range", "workArea", "--quality", "92"])
    print("Exported MP4:", OUT_MP4)

def false_val():
    return False

if __name__ == "__main__":
    main()
