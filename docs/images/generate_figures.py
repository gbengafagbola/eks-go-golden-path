#!/usr/bin/env python3
"""Generate article analogy figures as PNGs for AWS Builder Center upload."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
W, H = 1600, 900

# Palette — editorial, not purple/glow AI defaults
BG = (250, 249, 246)
INK = (28, 35, 43)
MUTED = (90, 100, 110)
TEAL = (15, 118, 110)
CORAL = (196, 84, 54)
GOLD = (196, 149, 58)
SLATE = (55, 70, 86)
SOFT = (232, 236, 238)
OK = (46, 125, 90)
BAD = (170, 55, 55)
WHITE = (255, 255, 255)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def new_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), BG)
    return img, ImageDraw.Draw(img)


def centered(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], f, fill=INK) -> None:
    x, y = xy
    bbox = draw.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((x - tw / 2, y - th / 2), text, font=f, fill=fill)


def title_bar(draw: ImageDraw.ImageDraw, text: str) -> None:
    draw.rectangle((0, 0, W, 78), fill=SLATE)
    centered(draw, text, (W // 2, 39), font(34, bold=True), fill=WHITE)


def panel(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill=WHITE, outline=SOFT, width=3) -> None:
    draw.rounded_rectangle(box, radius=18, fill=fill, outline=outline, width=width)


def caption(draw: ImageDraw.ImageDraw, text: str, y: int = H - 42) -> None:
    centered(draw, text, (W // 2, y), font(22), fill=MUTED)


def save(img: Image.Image, name: str) -> Path:
    path = OUT / name
    img.save(path, "PNG", optimize=True)
    print(f"wrote {path.name}")
    return path


def fig_01_golden_path() -> None:
    img, d = new_canvas()
    title_bar(d, "Golden path = paved main road (not a prison)")

    # Left chaos panel
    panel(d, (60, 120, 760, 780), fill=(255, 245, 242), outline=CORAL)
    centered(d, "Chaos: every team invents roads", (410, 160), font(26, True), CORAL)

    # messy roads
    for pts in [
        [(120, 240), (320, 520), (180, 700)],
        [(650, 250), (420, 480), (680, 690)],
        [(140, 420), (700, 360)],
        [(200, 620), (620, 280)],
        [(300, 250), (560, 700)],
    ]:
        d.line(pts, fill=(210, 130, 110), width=8)
    # crash marks
    for c in [(360, 430), (480, 500), (300, 560)]:
        d.ellipse((c[0] - 18, c[1] - 18, c[0] + 18, c[1] + 18), outline=BAD, width=4)
        d.line((c[0] - 12, c[1] - 12, c[0] + 12, c[1] + 12), fill=BAD, width=3)
        d.line((c[0] - 12, c[1] + 12, c[0] + 12, c[1] - 12), fill=BAD, width=3)
    centered(d, "Accidents at every intersection", (410, 740), font(22), MUTED)

    # Right golden path
    panel(d, (840, 120, 1540, 780), fill=(240, 250, 247), outline=TEAL)
    centered(d, "Golden path: one engineered route", (1190, 160), font(26, True), TEAL)

    # main road
    d.rounded_rectangle((1040, 220, 1340, 720), radius=12, fill=GOLD)
    d.rounded_rectangle((1070, 220, 1310, 720), radius=8, fill=(232, 196, 110))
    # dashed center line
    for y in range(250, 700, 40):
        d.rectangle((1185, y, 1195, y + 18), fill=WHITE)
    # sidewalks
    d.rectangle((1000, 220, 1040, 720), fill=SOFT)
    d.rectangle((1340, 220, 1380, 720), fill=SOFT)
    # houses off the road
    for hx, hy, label in [(920, 320, "App A"), (1420, 400, "App B"), (920, 560, "App C")]:
        d.rounded_rectangle((hx - 50, hy - 40, hx + 50, hy + 40), radius=8, fill=WHITE, outline=TEAL, width=3)
        centered(d, label, (hx, hy), font(18, True), TEAL)
        # connector
        if hx < 1190:
            d.line((hx + 50, hy, 1040, hy), fill=TEAL, width=4)
        else:
            d.line((hx - 50, hy, 1340, hy), fill=TEAL, width=4)
    # street lights / hydrant markers
    for y in (280, 450, 620):
        d.ellipse((1360, y, 1378, y + 18), fill=TEAL)
    centered(d, "Sidewalks • lights • hydrant already there", (1190, 740), font(20), MUTED)

    caption(d, "Safer defaults become the natural way to ship")
    save(img, "01-golden-path-main-road.png")


def fig_02_four_layers() -> None:
    img, d = new_canvas()
    title_bar(d, "Four layers of the golden path")

    layers = [
        ("4  Operations", "Probes • metrics • CloudWatch • failure experiments", OK, (230, 245, 236)),
        ("3  Runtime security", "Pod Identity • NetworkPolicy • restricted PSS", CORAL, (255, 240, 235)),
        ("2  Delivery", "GitHub Actions CI • OIDC deploy • Helm upgrade", TEAL, (230, 245, 242)),
        ("1  Infrastructure", "Terraform VPC • EKS • IAM • ECR • S3 • endpoints", SLATE, (236, 239, 242)),
    ]
    y0 = 130
    for i, (title, sub, accent, fill) in enumerate(layers):
        y = y0 + i * 170
        panel(d, (120, y, 1480, y + 145), fill=fill, outline=accent, width=4)
        d.rectangle((120, y, 160, y + 145), fill=accent)
        d.text((200, y + 35), title, font=font(36, True), fill=accent)
        d.text((200, y + 90), sub, font=font(26), fill=INK)

    caption(d, "Boring app on purpose — interesting platform on purpose")
    save(img, "02-four-layers-platform.png")


def fig_03_two_keys() -> None:
    img, d = new_canvas()
    title_bar(d, "Two actors. Two keys. Never one master key.")

    # crossed-out master key center top
    panel(d, (560, 110, 1040, 220), fill=(255, 236, 232), outline=BAD)
    centered(d, "Do NOT share one admin-ish role", (800, 145), font(24, True), BAD)
    centered(d, "Building manager + intern ≠ same key", (800, 185), font(20), MUTED)

    # left door
    panel(d, (80, 260, 740, 820), fill=WHITE, outline=TEAL)
    d.rounded_rectangle((220, 320, 600, 720), radius=16, fill=(236, 246, 244), outline=TEAL, width=5)
    # door window
    d.rounded_rectangle((300, 380, 520, 520), radius=8, fill=WHITE, outline=TEAL, width=3)
    d.ellipse((540, 560, 575, 595), outline=TEAL, width=4)  # knob
    centered(d, "Deployment identity", (410, 300), font(28, True), TEAL)
    centered(d, "GitHub Actions", (410, 560), font(22, True), INK)
    centered(d, "OIDC → ECR / deploy roles", (410, 600), font(20), MUTED)
    centered(d, "Publish image + Helm upgrade", (410, 640), font(20), MUTED)
    # key badge
    d.rounded_rectangle((250, 740, 570, 790), radius=10, fill=TEAL)
    centered(d, "Temporary pipeline key", (410, 765), font(22, True), WHITE)

    # right door
    panel(d, (860, 260, 1520, 820), fill=WHITE, outline=CORAL)
    d.rounded_rectangle((1000, 320, 1380, 720), radius=16, fill=(255, 243, 238), outline=CORAL, width=5)
    d.rounded_rectangle((1080, 380, 1300, 520), radius=8, fill=WHITE, outline=CORAL, width=3)
    d.ellipse((1320, 560, 1355, 595), outline=CORAL, width=4)
    centered(d, "Workload identity", (1190, 300), font(28, True), CORAL)
    centered(d, "Running app pod", (1190, 560), font(22, True), INK)
    centered(d, "EKS Pod Identity → IAM", (1190, 600), font(20), MUTED)
    centered(d, "S3 read only (demo)", (1190, 640), font(20), MUTED)
    d.rounded_rectangle((1030, 740, 1350, 790), radius=10, fill=CORAL)
    centered(d, "Scoped workload key", (1190, 765), font(22, True), WHITE)

    save(img, "03-two-keys-identity.png")


def fig_04_oidc_badge() -> None:
    img, d = new_canvas()
    title_bar(d, "OIDC visitor badge vs laminated 2019 keys")

    # Left good
    panel(d, (80, 130, 760, 800), fill=(236, 247, 244), outline=TEAL)
    centered(d, "Better habit", (420, 180), font(28, True), TEAL)
    # badge
    d.rounded_rectangle((220, 240, 620, 620), radius=20, fill=WHITE, outline=TEAL, width=5)
    d.rectangle((220, 240, 620, 320), fill=TEAL)
    centered(d, "VISITOR", (420, 280), font(32, True), WHITE)
    d.ellipse((340, 360, 500, 520), outline=TEAL, width=5)
    centered(d, "GH", (420, 440), font(40, True), TEAL)
    centered(d, "Expires when the job ends", (420, 570), font(20), MUTED)
    # clock
    d.ellipse((520, 340, 590, 410), fill=GOLD, outline=INK, width=2)
    centered(d, "⏱", (555, 375), font(28), INK)
    centered(d, "Short-lived OIDC token", (420, 680), font(26, True), TEAL)
    centered(d, "aud + sub must match repo/branch", (420, 730), font(20), MUTED)

    # Right bad
    panel(d, (840, 130, 1520, 800), fill=(255, 240, 236), outline=BAD)
    centered(d, "Old habit", (1180, 180), font(28, True), BAD)
    d.rounded_rectangle((980, 240, 1380, 620), radius=20, fill=WHITE, outline=BAD, width=5)
    d.rectangle((980, 240, 1380, 320), fill=BAD)
    centered(d, "PERMANENT", (1180, 280), font(28, True), WHITE)
    d.ellipse((1100, 360, 1260, 520), outline=MUTED, width=5)
    centered(d, "AKIA…", (1180, 440), font(28, True), MUTED)
    centered(d, "Laminated in 2019. Still worn.", (1180, 570), font(20), MUTED)
    # scratch marks
    d.line((1020, 350, 1340, 580), fill=(220, 180, 170), width=3)
    d.line((1040, 580, 1340, 360), fill=(220, 180, 170), width=3)
    centered(d, "Long-lived access keys", (1180, 680), font(26, True), BAD)
    centered(d, "Hope nobody screenshots the logs", (1180, 730), font(20), MUTED)

    save(img, "04-oidc-visitor-badge.png")


def fig_05_bouncer() -> None:
    img, d = new_canvas()
    title_bar(d, "Guest list vs bouncer (NetworkPolicy)")

    # Guest list
    panel(d, (70, 120, 520, 820), fill=WHITE, outline=SLATE)
    centered(d, "Guest list", (295, 170), font(30, True), SLATE)
    centered(d, "NetworkPolicy YAML", (295, 215), font(20), MUTED)
    rows = [
        ("access=allowed → app:8080", OK),
        ("DNS → kube-system CoreDNS", OK),
        ("TCP 443 → AWS APIs", OK),
        ("unlabeled pod → app", BAD),
        ("east-west free-for-all", BAD),
    ]
    y = 280
    for text, color in rows:
        d.rounded_rectangle((110, y, 480, y + 70), radius=10, fill=SOFT if color == OK else (255, 236, 232))
        mark = "✓" if color == OK else "✗"
        d.text((130, y + 18), f"{mark}  {text}", font=font(20, True), fill=color)
        y += 90
    centered(d, "Writing the list ≠ enforcement", (295, 770), font(18), MUTED)

    # Arrow
    d.polygon([(560, 430), (640, 390), (640, 410), (720, 410), (720, 450), (640, 450), (640, 470)], fill=GOLD)

    # Bouncer
    panel(d, (760, 120, 1530, 820), fill=(236, 239, 242), outline=CORAL)
    centered(d, "Bouncer", (1145, 170), font(30, True), CORAL)
    centered(d, "VPC CNI network policy enforcement", (1145, 215), font(20), MUTED)

    # door / club
    d.rounded_rectangle((980, 280, 1310, 620), radius=14, fill=SLATE)
    centered(d, "App pod", (1145, 360), font(26, True), WHITE)
    centered(d, ":8080", (1145, 410), font(22), SOFT)
    # bouncer figure
    d.ellipse((860, 340, 940, 420), fill=CORAL)
    d.rounded_rectangle((850, 420, 950, 560), radius=12, fill=CORAL)
    centered(d, "CNI", (900, 480), font(18, True), WHITE)

    # allowed / denied people
    d.rounded_rectangle((1020, 660, 1260, 730), radius=10, fill=OK)
    centered(d, "Allowed client → /healthz", (1140, 695), font(20, True), WHITE)
    d.rounded_rectangle((1320, 360, 1480, 520), radius=10, fill=BAD)
    centered(d, "Denied", (1400, 420), font(22, True), WHITE)
    centered(d, "client", (1400, 460), font(20), WHITE)
    d.line((1310, 440, 1260, 440), fill=BAD, width=5)
    d.polygon([(1260, 430), (1240, 440), (1260, 450)], fill=BAD)

    centered(d, "Experiments = watching the bouncer turn someone away", (1145, 780), font(18), MUTED)
    save(img, "05-network-bouncer.png")


def fig_06_probes() -> None:
    img, d = new_canvas()
    title_bar(d, "Liveness ≠ readiness (stop dressing them identically)")

    # Liveness
    panel(d, (70, 130, 760, 800), fill=(255, 243, 238), outline=CORAL)
    centered(d, "Liveness", (415, 190), font(34, True), CORAL)
    centered(d, "Are you so broken we should restart you?", (415, 245), font(20), MUTED)
    # hospital / restart metaphor
    d.rounded_rectangle((220, 300, 610, 560), radius=16, fill=WHITE, outline=CORAL, width=4)
    centered(d, "Pod", (415, 370), font(28, True), INK)
    centered(d, "stuck / deadlocked", (415, 420), font(22), MUTED)
    d.rounded_rectangle((260, 470, 570, 530), radius=10, fill=CORAL)
    centered(d, "Restart container", (415, 500), font(22, True), WHITE)
    centered(d, "Wrong use: “still warming up”", (415, 620), font(22, True), BAD)
    centered(d, "→ popular genre of restart-loop outage", (415, 670), font(20), MUTED)

    # Readiness
    panel(d, (840, 130, 1530, 800), fill=(236, 247, 244), outline=TEAL)
    centered(d, "Readiness", (1185, 190), font(34, True), TEAL)
    centered(d, "Should you receive traffic right now?", (1185, 245), font(20), MUTED)
    # traffic light
    d.rounded_rectangle((1100, 300, 1270, 560), radius=20, fill=SLATE)
    for cy, color in [(370, BAD), (440, GOLD), (510, OK)]:
        d.ellipse((1145, cy - 28, 1225, cy + 28), fill=color)
    centered(d, "Service traffic", (1185, 620), font(22, True), TEAL)
    centered(d, "Not ready → removed from endpoints", (1185, 670), font(20), MUTED)
    centered(d, "Warming up belongs here", (1185, 720), font(22, True), TEAL)

    save(img, "06-liveness-vs-readiness.png")


def fig_07_three_signals() -> None:
    img, d = new_canvas()
    title_bar(d, "Three signals — installing an agent ≠ useful telemetry")

    cards = [
        ("Metrics", "Are we within limits?", "/metrics + Container Insights", TEAL, (230, 245, 242)),
        ("Logs", "What happened in this event?", "Structured JSON + request IDs", CORAL, (255, 243, 238)),
        ("Traces", "Where did the request go?", "Claim only if you see a real trace", GOLD, (255, 249, 230)),
    ]
    x0 = 70
    for i, (title, q, detail, accent, fill) in enumerate(cards):
        x = x0 + i * 510
        panel(d, (x, 140, x + 470, 620), fill=fill, outline=accent, width=4)
        d.ellipse((x + 185, 190, x + 285, 290), fill=accent)
        centered(d, str(i + 1), (x + 235, 240), font(36, True), WHITE)
        centered(d, title, (x + 235, 340), font(34, True), accent)
        centered(d, q, (x + 235, 410), font(22), INK)
        # wrap detail manually
        centered(d, detail, (x + 235, 500), font(20), MUTED)

    panel(d, (70, 660, 1530, 820), fill=WHITE, outline=BAD)
    centered(d, "Unplugged CCTV still says “we have cameras.”", (800, 715), font(26, True), BAD)
    centered(d, "Verify arrival in CloudWatch. Until then: configuration exists; data arrival is PENDING.", (800, 770), font(20), MUTED)
    save(img, "07-three-signals-observability.png")


def fig_08_private_road() -> None:
    img, d = new_canvas()
    title_bar(d, "Private subnets need a road to EKS Auth")

    # Private subnet zone
    panel(d, (70, 130, 900, 780), fill=(236, 239, 242), outline=SLATE)
    centered(d, "Private worker subnets", (485, 180), font(28, True), SLATE)
    # nodes
    for i, label in enumerate(["Node A", "Node B", "Node C"]):
        x = 140 + i * 240
        d.rounded_rectangle((x, 260, x + 180, 400), radius=12, fill=WHITE, outline=TEAL, width=3)
        centered(d, label, (x + 90, 310), font(22, True), TEAL)
        centered(d, "pods", (x + 90, 355), font(18), MUTED)

    # NAT as crowded hallway (avoid only path)
    d.rounded_rectangle((200, 480, 770, 560), radius=10, fill=(255, 236, 232), outline=BAD, width=3)
    centered(d, "Don’t shove EVERY conversation through NAT", (485, 520), font(20, True), BAD)

    # VPC endpoint road
    d.rounded_rectangle((200, 600, 770, 720), radius=12, fill=(230, 245, 242), outline=TEAL, width=4)
    centered(d, "Interface VPC endpoint: eks-auth", (485, 640), font(24, True), TEAL)
    centered(d, "+ STS • ECR • S3 gateway • CloudWatch Logs", (485, 690), font(18), MUTED)

    # Right EKS Auth
    panel(d, (960, 200, 1530, 700), fill=WHITE, outline=TEAL)
    d.rounded_rectangle((1080, 320, 1410, 560), radius=16, fill=TEAL)
    centered(d, "EKS Auth API", (1245, 400), font(30, True), WHITE)
    centered(d, "Pod Identity", (1245, 460), font(24), SOFT)
    centered(d, "Private reachability required", (1245, 640), font(20), MUTED)

    # arrow
    d.polygon([(900, 650), (960, 620), (960, 680)], fill=TEAL)

    caption(d, "Pod Identity from private nodes is a road design problem, not a YAML wish")
    save(img, "08-private-subnet-eks-auth.png")


def fig_09_green_monday() -> None:
    img, d = new_canvas()
    title_bar(d, "Green pods ≠ ready for Monday morning")

    # Left dashboard
    panel(d, (70, 130, 760, 780), fill=WHITE, outline=OK)
    centered(d, "Friday deploy dashboard", (415, 180), font(26, True), OK)
    d.rounded_rectangle((160, 230, 670, 420), radius=14, fill=(230, 245, 236), outline=OK, width=3)
    centered(d, "●  Deployment Available", (415, 290), font(28, True), OK)
    centered(d, "●  Pods Ready  3/3", (415, 350), font(26, True), OK)
    d.rounded_rectangle((220, 470, 610, 560), radius=12, fill=OK)
    centered(d, "shipped  ✓", (415, 515), font(30, True), WHITE)
    centered(d, "Looks successful…", (415, 640), font(24), MUTED)
    centered(d, "Service responds. Slack celebrates.", (415, 690), font(20), MUTED)

    # Right monday
    panel(d, (840, 130, 1530, 780), fill=(255, 243, 238), outline=CORAL)
    centered(d, "Monday morning questions", (1185, 180), font(26, True), CORAL)
    qs = [
        "How was infra provisioned?",
        "Which identity talks to AWS?",
        "Can A talk to B when it shouldn’t?",
        "What happens when a pod dies at 2 a.m.?",
        "Do we have telemetry to explain ourselves?",
    ]
    y = 250
    for q in qs:
        d.rounded_rectangle((900, y, 1470, y + 70), radius=10, fill=WHITE, outline=CORAL, width=2)
        d.text((930, y + 20), q, font=font(20), fill=INK)
        y += 90
    centered(d, "That gap is where platform engineering earns its keep", (1185, 740), font(18, True), CORAL)

    save(img, "09-green-pods-monday.png")


def fig_10_delivery_pipeline() -> None:
    img, d = new_canvas()
    title_bar(d, "CI exam → deploy keys → OIDC valet ticket")

    steps = [
        ("1  CI", "License exam", "fmt • vet • test\nscan • helm lint", TEAL),
        ("2  OIDC", "Valet ticket", "short-lived token\nrepo + branch match", GOLD),
        ("3  Push", "Park the car", "immutable\nsha-<gitsha> tag", CORAL),
        ("4  Deploy", "Drive", "helm upgrade\nwait /readyz", OK),
    ]
    for i, (title, analogy, detail, accent) in enumerate(steps):
        x = 70 + i * 385
        panel(d, (x, 160, x + 350, 620), fill=WHITE, outline=accent, width=4)
        d.rectangle((x, 160, x + 350, 250), fill=accent)
        centered(d, title, (x + 175, 205), font(28, True), WHITE)
        centered(d, analogy, (x + 175, 320), font(26, True), accent)
        # multiline detail
        lines = detail.split("\n")
        yy = 420
        for line in lines:
            centered(d, line, (x + 175, yy), font(22), INK)
            yy += 40
        if i < 3:
            d.polygon([(x + 360, 380), (x + 380, 360), (x + 380, 400)], fill=SLATE)

    panel(d, (70, 670, 1530, 820), fill=(255, 243, 238), outline=BAD)
    centered(d, "latest tags are mystery novels in production.", (800, 720), font(26, True), BAD)
    centered(d, "OIDC is not a rusty master key left under the mat since 2018.", (800, 775), font(22), MUTED)
    save(img, "10-delivery-oidc-pipeline.png")


def main() -> None:
    fig_01_golden_path()
    fig_02_four_layers()
    fig_03_two_keys()
    fig_04_oidc_badge()
    fig_05_bouncer()
    fig_06_probes()
    fig_07_three_signals()
    fig_08_private_road()
    fig_09_green_monday()
    fig_10_delivery_pipeline()
    print("done")


if __name__ == "__main__":
    main()
