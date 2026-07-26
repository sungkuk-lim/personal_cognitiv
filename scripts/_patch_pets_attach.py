from pathlib import Path
p = Path("lib/features/graph/graph_layout.dart")
t = p.read_text(encoding="utf-8")
needle = "  attachMany('person', GraphNodeKind.person, satellites.people);\n  attachMany('place', GraphNodeKind.place, satellites.places);"
repl = "  attachMany('person', GraphNodeKind.person, satellites.people);\n  attachMany('pet', GraphNodeKind.pet, satellites.pets);\n  attachMany('place', GraphNodeKind.place, satellites.places);"
if "attachMany('pet'" not in t:
    if needle not in t:
        raise SystemExit("attachMany person/place not found")
    t = t.replace(needle, repl)
p.write_text(t, encoding="utf-8", newline="\n")
print("pets attached", "attachMany('pet'" in t)
