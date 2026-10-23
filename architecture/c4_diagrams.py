"""Generate mcl-bookclub-observer's two C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: what the service talks to
  c4-components.svg  Level 2: what it is made of

Drawn from the code, never from a template: the callbacks and subscriptions/0 in
mcl_bookclub_observer_service.erl, the boot in mcl_bookclub_observer_app.erl, the
supervisor, the three ingest listeners and their policies, the scoreboard provider
and its query desk, the read model store, the dependencies in rebar.config, the
health socket and volumes in the Containerfile and deploy/docker-compose.yml. When
one of those changes, the diagram changes in the same commit.

Colours are plain classes with a prefers-color-scheme: dark block, no CSS custom
properties (rsvg-convert renders those black), so the SVGs render the same on
GitHub, in IDE previews and through rsvg-convert. After a change, render each
(rsvg-convert -w 1400 assets/c4-context.svg -o /tmp/c.png) and look at it; keep
architecture/README.md's tables in step.
"""
import os
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

SANS = '"Atkinson Hyperlegible", "Segoe UI", system-ui, -apple-system, Helvetica, Arial, sans-serif'
MONO = '"JetBrains Mono", ui-monospace, Menlo, Consolas, monospace'

# Element kinds, each (light fill, light stroke, dark fill, dark stroke).
KINDS = {
    "b-sys": ("#F5E9CC", "#A56F0A", "#3A2E13", "#E3AA3C"),   # in scope
    "b-per": ("#E3EBF2", "#3B5B7A", "#1D2A36", "#8EB4D8"),   # person
    "b-mac": ("#E6E4EE", "#5E5A78", "#26243A", "#A9A4C8"),   # Macula infrastructure
    "b-lib": ("#E7F0E8", "#4A7A55", "#1A241C", "#8FBE9B"),   # library
    "b-ext": ("#ECEFED", "#8A9791", "#1C2421", "#7D8B85"),   # external system
    "b-cmp": ("#FFFFFF", "#8A9791", "#171F1C", "#7D8B85"),   # component or container
}

STYLE = f"""<style>
.t-name {{ font-family: {SANS}; font-size: 15px; font-weight: 700; }}
.t-desc {{ font-family: {SANS}; font-size: 12.5px; }}
.t-rel {{ font-family: {SANS}; font-size: 11.5px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-code {{ font-family: {MONO}; font-size: 13px; font-weight: 600; }}
.t-type {{ font-family: {MONO}; font-size: 11.5px; }}
.t-bound {{ font-family: {MONO}; font-size: 12px; font-weight: 600; }}
.t-leg {{ font-family: {SANS}; font-size: 12px; }}
.edge {{ fill: none; stroke-width: 1.25; }}
.edge-later {{ fill: none; stroke-width: 1.25; stroke-dasharray: 5 4; }}
.bg {{ fill: #FFFFFF; }}
""" + "".join(f".{k} {{ fill: {v[0]}; stroke: {v[1]}; stroke-width: {2 if k == 'b-sys' else 1.25}; }}\n" for k, v in KINDS.items()) + """\
.b-later { fill: none; stroke: #8A9791; stroke-width: 1.25; stroke-dasharray: 5 4; }
.bound { fill: none; stroke: #B3BDB8; stroke-width: 1; }
.head { fill: #3B5B7A; }
.t-name, .t-code { fill: #16201D; }
.t-type, .t-bound, .t-leg { fill: #66736E; }
.t-desc { fill: #34413C; }
.t-rel { fill: #66736E; stroke: #FFFFFF; }
.edge, .edge-later { stroke: #8A9791; }
.arrowhead { fill: #8A9791; }
@media (prefers-color-scheme: dark) {
.bg { fill: #171F1C; }
""" + "".join(f".{k} {{ fill: {v[2]}; stroke: {v[3]}; }}\n" for k, v in KINDS.items()) + """\
.b-later { stroke: #7D8B85; }
.bound { stroke: #4A5752; }
.head { fill: #8EB4D8; }
.t-name, .t-code { fill: #E6ECE9; }
.t-type, .t-bound, .t-leg { fill: #93A09A; }
.t-desc { fill: #C3CDC8; }
.t-rel { fill: #93A09A; stroke: #171F1C; }
.edge, .edge-later { stroke: #7D8B85; }
.arrowhead { fill: #7D8B85; }
}
</style>"""

DEFS = ('<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/></marker></defs>')

LEGEND = [("b-sys", "In scope"), ("b-per", "Person"), ("b-mac", "Macula infrastructure"),
          ("b-lib", "Library"), ("b-ext", "External system"), ("b-cmp", "Container or component")]
BOUNDARY = ("bound", "Boundary")


class Diagram:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h, self.parts = name, title, w, h, []

    def text(self, cls, x, y, s, anchor=None, rotate=None):
        a = f' text-anchor="{anchor}"' if anchor else ""
        r = f' transform="rotate({rotate} {x} {y})"' if rotate is not None else ""
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}"{a}{r}>{escape(s)}</text>')

    def box(self, cls, x, y, w, h, name, kind, desc, person=False, code=False):
        # A box that is too small for its own words renders as text on top of the
        # next box, which no test would catch and a reader would read as the
        # diagram saying something it does not. Fail here instead.
        need = 70 + 16 * max(len(desc) - 1, 0) + 18
        if h < need:
            raise ValueError(f"{self.name}: {name} needs height {need}, has {h}")
        for line in desc:
            if 16 + 6.2 * len(line) > w - 16:
                raise ValueError(f"{self.name}: {name}: '{line}' is wider than {w - 32}px")
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
        tx = x + 16
        if person:
            self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
            tx = x + 44
        self.text("t-code" if code else "t-name", tx, y + 28, name)
        self.text("t-type", tx, y + 46, kind)
        for i, line in enumerate(desc):
            self.text("t-desc", x + 16, y + 70 + 16 * i, line)

    def bound(self, x, y, w, h, label):
        self.parts.append(f'<rect class="bound" x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/>')
        self.text("t-bound", x + 16, y + 22, label)

    def edge(self, d, later=False):
        self.parts.append(f'<path class="{"edge-later" if later else "edge"}" d="{d}" marker-end="url(#a)"/>')

    def legend(self, y, boundary=True):
        x = 24
        for cls, label in LEGEND + ([BOUNDARY] if boundary else []):
            self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="22" height="14" rx="3"/>')
            self.text("t-leg", x + 30, y + 12, label)
            x += 34 + 6.6 * len(label)

    def write(self):
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" role="img" '
               f'aria-label="{escape(self.title)}">', f"<title>{escape(self.title)}</title>", STYLE, DEFS,
               f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}"/>'] + self.parts + ["</svg>", ""]
        with open(os.path.join(OUT, self.name), "w") as f:
            f.write("\n".join(svg))


def context():
    d = Diagram("c4-context.svg", "mcl-bookclub-observer system context", 1000, 780)
    d.box("b-per", 40, 30, 270, 120, "Mesh consumer", "[Person, app or service]",
          ["Calls mcl-bookclub-observer/", "get_scoreboard and reads the",
           "counts, clubs and verdicts"], person=True)
    d.box("b-per", 690, 30, 270, 120, "Service operator", "[Person]",
          ["Deploys the release and supplies", "MCL_REALM, MCL_REALM_KEY and the",
           "pinned station ids"], person=True)
    d.box("b-sys", 365, 186, 270, 152, "mcl-bookclub-observer", "[mcl_om mesh service, own box]",
          ["Storeless: no event store, no", "command. Subscribes to three fact",
           "topics, folds them into one sqlite", "read model, and serves its own",
           "procedure on the mesh"])
    d.box("b-ext", 40, 400, 270, 136, "mcl-bookclub", "[External system, on the mesh]",
          ["The producer. Publishes the three", "facts and answers",
           "mcl-bookclub/get_bookclub_by_id,", "the call this service verifies with"])
    d.box("b-mac", 365, 400, 270, 136, "macula-realm", "[Macula infrastructure]",
          ["Endorses the node's identity key", "and grants the scope",
           "mcl-bookclub-observer for its action", "and its read resources"])
    d.box("b-mac", 690, 400, 270, 136, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["Pinned stations are the mesh entry", "(QUIC); the DHT holds its own",
           "procedure and delivers its", "fact topics"])
    d.box("b-ext", 40, 560, 270, 120, "Host disk", "[External system]",
          ["The sqlite read model at /data,", "and the node key under",
           "/etc/mcl/secrets"])
    d.edge("M175 150V176H400V186"); d.text("t-rel", 183, 170, "calls get_scoreboard")
    d.edge("M825 134V176H620V186"); d.text("t-rel", 690, 170, "deploys; sets the realm, stations")
    d.edge("M440 338V380H175V400")
    d.text("t-rel", 190, 356, "calls get_bookclub_by_id,")
    d.text("t-rel", 190, 372, "pinned to the publisher")
    d.edge("M540 340V400"); d.text("t-rel", 532, 370, "boot claim, scope", anchor="end")
    d.edge("M620 338V380H825V400"); d.text("t-rel", 635, 372, "subscribes to the facts; advertises its own")
    d.edge("M365 300H340V620H310")
    d.text("t-rel", 330, 480, "keeps the read model", anchor="middle", rotate=-90)
    d.text("t-desc", 40, 712, "Storeless by dependency list: no evoq and no reckon-db, so no command can be dispatched and no event log is")
    d.text("t-desc", 40, 730, "opened. The only durable state is the sqlite read model, rebuilt from whatever the mesh delivers after a loss.")
    d.legend(756, boundary=False)
    d.write()


def components():
    d = Diagram("c4-components.svg", "mcl-bookclub-observer components", 1340, 1220)
    d.bound(16, 40, 1292, 640, "mcl-bookclub-observer [Container] - one OTP release, one app")
    # Row 1: the boot and the contract.
    d.box("b-cmp", 32, 76, 340, 136, "mcl_bookclub_observer_app", "[OTP application]",
          ["One call: mcl_om:boot/1 with the service",
           "module. No store is opened here, because",
           "there is no store to open"], code=True)
    d.box("b-sys", 492, 76, 340, 136, "mcl_bookclub_observer_service", "[mcl_om_service behaviour]",
          ["The six callbacks, plus subscriptions/0:",
           "the three topic triples mcl_om wires",
           "into its supervised pubsub tree"], code=True)
    d.text("t-desc", 972, 130, "mcl_om:boot/1 wires the mesh,")
    d.text("t-desc", 972, 148, "the realm identity and the adverts")
    d.text("t-desc", 972, 166, "capabilities/0 returns, health and")
    d.text("t-desc", 972, 184, "the declared subscriptions.")
    # Row 2: the mesh face, the ingest path, the policies.
    d.box("b-sys", 32, 272, 340, 136, "mcl_bookclub_observer_get_scoreboard", "[macula_response provider]",
          ["Answers from the local read model, then",
           "verifies each club by calling the",
           "bookclub, pinned to the fact's publisher"], code=True)
    d.box("b-cmp", 492, 272, 340, 136, "ingest_member_registered", "[macula_subscriber, three modules]",
          ["with ingest_book_procured and",
           "ingest_book_retired: hand the payload",
           "to the policy, then write its decision"], code=True)
    d.box("b-cmp", 952, 272, 340, 136, "on_book_procured_fact_maybe_record", "[policy, three modules]",
          ["with on_member_registered_ and",
           "on_book_retired_ fact_maybe_record:",
           "unwrap with mcl_om_wire:field/2,",
           "then decide admit or supersede"], code=True)
    # Row 3: the answer, the store, its supervisor.
    d.box("b-cmp", 32, 468, 340, 180, "get_scoreboard", "[pure query desk]",
          ["counts/0 and clubs/0 over the store:",
           "members, books on shelf, books retired,",
           "and one row per club with its name,",
           "counts, last registration and the",
           "publisher's node id"], code=True)
    d.box("b-cmp", 492, 468, 340, 180, "observer_read_model_store", "[gen_server, esqlite]",
          ["One connection, owned by this process.",
           "Schema: members and books. Writes are",
           "INSERT OR REPLACE keyed on the fact's",
           "natural key, because a fact carries no",
           "event_id or version to dedupe on"], code=True)
    d.box("b-cmp", 952, 468, 340, 180, "mcl_bookclub_observer_sup", "[supervisor, one_for_one]",
          ["One child, observer_read_model_store,",
           "started before anything reads it.",
           "The mesh subscribers are not here:",
           "mcl_om supervises those from",
           "subscriptions/0"], code=True)
    # The libraries.
    d.text("t-desc", 32, 720, "The libraries the release links:")
    d.box("b-lib", 32, 736, 400, 136, "mcl_om", "[library, ~> 1.4]",
          ["boot/1: node key, realm join, QUIC pool,",
           "health, subscriptions/0 and the adverts",
           "capabilities/0 returns; call_capability/5"], code=True)
    d.box("b-lib", 452, 736, 400, 136, "macula", "[library, ~> 16.0]",
          ["QUIC transport and the subscriber that",
           "receives a fact; the advertiser-pinned",
           "call is mcl_om:call_capability/5"], code=True)
    d.box("b-lib", 872, 736, 400, 136, "esqlite", "[library, ~> 0.9]",
          ["one sqlite file, one connection owned by",
           "the store process; a NIF connection belongs",
           "to the process that opened it"], code=True)
    # The host's environment.
    d.box("b-ext", 32, 912, 600, 104, "MCL_DATA_DIR", "[environment, /data in the image]",
          ["the read model at <dir>/bookclub_observer.sqlite3;",
           "without the volume a recreate forgets everything observed"], code=True)
    d.box("b-ext", 652, 912, 640, 104, "MCL_COOKIE", "[environment, supplied by the operator]",
          ["supplied by the environment; the compose file refuses to start without it;",
           "the node name is fixed"], code=True)
    d.box("b-ext", 32, 1044, 1260, 104, "MCL_REALM, MCL_REALM_KEY, MACULA_STATION_SEEDS, MACULA_STATION_NODE_IDS",
          "[environment: realm pair in sys.config.src, seeds and node ids via mcl_om]",
          ["the compose file refuses to start without all four, so a half-configured node",
           "never announces itself where nobody can attribute it"], code=True)
    # The wiring between the boxes.
    d.edge("M492 190H432V272"); d.text("t-rel", 440, 240, "capabilities/0 names it")
    d.edge("M632 212V272"); d.text("t-rel", 640, 246, "subscriptions/0 wires the three")
    d.edge("M832 340H952"); d.text("t-rel", 892, 332, "hands it the fact", anchor="middle")
    d.edge("M212 408V468"); d.text("t-rel", 220, 442, "answers from the rows")
    d.edge("M632 408V468"); d.text("t-rel", 624, 442, "records what it admitted", anchor="end")
    d.edge("M1000 408V436H700V468"); d.text("t-rel", 720, 430, "consults book_status")
    d.edge("M372 560H492"); d.text("t-rel", 432, 552, "reads the rows", anchor="middle")
    d.edge("M952 560H832"); d.text("t-rel", 892, 552, "one child", anchor="middle")
    d.legend(1180)
    d.write()


if __name__ == "__main__":
    for make in (context, components):
        make()
