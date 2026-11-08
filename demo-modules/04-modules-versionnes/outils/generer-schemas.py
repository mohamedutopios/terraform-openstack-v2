#!/usr/bin/env python3
"""Génère schemas-demos.html : les schémas des démos de 04-modules-versionnes.

    python3 outils/generer-schemas.py

Page autonome (aucune ressource externe) : utilisable hors ligne en salle.
Convention de couleurs : orange = nouveau / modifié, rouge = problème,
vert = contrôle réussi, gris = inchangé, bleu = élément de référence.
"""
from html import escape
from pathlib import Path

ICI = Path(__file__).resolve().parent.parent
SORTIE = ICI / "schemas-demos.html"

# --------------------------------------------------------------- boîte SVG ---


class Svg:
    """Petite boîte à outils : boîtes, textes, flèches, coordonnées en px."""

    def __init__(self, nom, w, h, titre):
        self.nom, self.w, self.h, self.titre = nom, w, h, titre
        self.el = []

    # -- primitives
    def rect(self, x, y, w, h, cls, rx=8):
        self.el.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" class="{cls}"/>')

    def text(self, x, y, txt, cls="t", anchor="start"):
        self.el.append(f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{escape(txt)}</text>')

    def line(self, x1, y1, x2, y2, cls="f", fleche=True):
        m = f' marker-end="url(#{self.nom}-{cls.split()[0]})"' if fleche else ""
        self.el.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" class="{cls}"{m}/>')

    def path(self, pts, cls="f", fleche=True):
        d = "M" + " L".join(f"{x},{y}" for x, y in pts)
        m = f' marker-end="url(#{self.nom}-{cls.split()[0]})"' if fleche else ""
        self.el.append(f'<path d="{d}" class="{cls}" fill="none"{m}/>')

    def circle(self, x, y, r, cls):
        self.el.append(f'<circle cx="{x}" cy="{y}" r="{r}" class="{cls}"/>')

    # -- composés
    def box(self, x, y, w, h, titre, lignes=(), cls="neutre", mono=True, centre=False):
        self.rect(x, y, w, h, f"b {cls}")
        ty = y + h / 2 + 5 if not lignes else y + 22
        if centre:
            self.text(x + w / 2, ty, titre, f"tt {cls}-t", "middle")
        else:
            self.text(x + 12, ty, titre, f"tt {cls}-t")
        for i, l in enumerate(lignes):
            c = "tl" if mono else "tp"
            if centre:
                self.text(x + w / 2, y + 42 + i * 17, l, c, "middle")
            else:
                self.text(x + 12, y + 42 + i * 17, l, c)

    def chip(self, x, y, w, txt, cls="neutre", h=26):
        self.rect(x, y, w, h, f"b {cls}", rx=6)
        self.text(x + w / 2, y + h / 2 + 4.5, txt, f"tc {cls}-t", "middle")

    def label(self, x, y, txt, cls="tm", anchor="middle", fond=True):
        if fond:
            lw = len(txt) * 6.4 + 10
            x0 = x - lw / 2 if anchor == "middle" else (x if anchor == "start" else x - lw)
            self.rect(x0, y - 12, lw, 17, "etiq", rx=4)
        self.text(x, y, txt, cls, anchor)

    def panel(self, x, y, w, h, titre, cls="panneau"):
        self.rect(x, y, w, h, cls, rx=12)
        self.text(x + 16, y + 26, titre, "tp-titre")

    def rendu(self):
        couleurs = {"f": "#64748b", "fo": "#ff6b35", "fr": "#dc2626", "fv": "#059669", "fb": "#0066cc", "fp": "#7c3aed"}
        defs = "".join(
            f'<marker id="{self.nom}-{k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>'
            for k, c in couleurs.items())
        return (f'<svg viewBox="0 0 {self.w} {self.h}" role="img" aria-label="{escape(self.titre)}" '
                f'xmlns="http://www.w3.org/2000/svg"><defs>{defs}</defs>' + "".join(self.el) + "</svg>")


# ------------------------------------------------------------------ schémas ---

NS = "gitlab.com/mohamed.aijjou1780"


def vue_globale():
    s = Svg("glob", 1240, 830, "Vue globale : les six dépôts et leurs liens")
    # ci-templates
    s.box(420, 20, 400, 120, "terraform-ci-templates", [
        "tags : v1.0.0 · v1.1.0 · v1.2.0",
        "templates/module.yml        (pipeline module)",
        "templates/infra.yml         (pipeline infra)",
        "templates/environnement(s).yml  (multi-env)",
    ], "ref")
    # modules
    mods = [
        (60, "terraform-openstack-network", ["tags : v1.0.0", "réseau + sous-réseau + routeur"]),
        (470, "terraform-openstack-security", ["tags : v1.0.0 · v1.1.0 · v2.0.0", "security group + règles"]),
        (880, "terraform-openstack-compute", ["tags : v1.0.0 · v1.1.0 (démo 2)", "keypair + port + VM + IP flottante"]),
    ]
    for x, n, l in mods:
        s.box(x, 230, 300, 150, n, l + ["examples/  tests/  CHANGELOG.md", "README.md (section terraform-docs)", ".gitlab-ci.yml : include v1.1.0"], "module")
    for x, _, _ in mods:
        s.line(620, 140, x + 150, 228, "fp pointille")
    s.label(620, 190, "include (pipeline module)", "tm-p")
    # infras
    s.box(130, 490, 420, 170, "infra-dm4", [
        "main.tf : 3 × module « git::…?ref=vX.Y.Z »",
        "network v1.0.0 · security v2.0.0 · compute v1.0.0",
        ".terraform.lock.hcl · renovate.json",
        "un état GitLab : dm4",
        ".gitlab-ci.yml : include infra.yml v1.1.0",
    ], "infra")
    s.box(690, 490, 420, 170, "infra-dm4-envs  (démo 3)", [
        "envs/dev · envs/staging · envs/prod",
        "un ?ref= et un backend.hcl par environnement",
        "états : dm4-dev · dm4-staging · dm4-prod",
        "socle/ : un projet + un compte par env",
        ".gitlab-ci.yml : include v1.2.0 (×4, inputs)",
    ], "infra")
    # include vers infras
    s.path([(420, 110), (30, 110), (30, 575), (128, 575)], "fp pointille")
    s.label(225, 104, "include infra.yml v1.1.0", "tm-p", "middle")
    s.path([(820, 110), (1210, 110), (1210, 575), (1112, 575)], "fp pointille")
    s.label(1015, 104, "include environnement(s).yml v1.2.0", "tm-p", "middle")
    # modules -> infras
    for x, _, _ in mods:
        for cx in (340, 900):
            s.line(x + 150, 380, cx, 488, "fb")
    s.label(620, 440, "source = \"git::https://" + NS + "/terraform-openstack-<nom>.git?ref=vX.Y.Z\"", "tm-b")
    # services
    s.text(40, 712, "Ce que les pipelines utilisent :", "tp-titre")
    s.box(40, 725, 360, 90, "GitLab : Releases + registre", ["publiés par le pipeline du TAG d'un module", "notes de version = section du CHANGELOG"], "gris", mono=False)
    s.box(440, 725, 360, 90, "GitLab : états Terraform", ["dm4 · dm4-dev · dm4-staging · dm4-prod", "verrou, historique, Operate > Terraform states"], "gris", mono=False)
    s.box(840, 725, 360, 90, "Lab OpenStack (192.168.56.250)", ["joint par le runner tagué « openstack »", "plan, apply, destroy, dérive"], "gris", mono=False)
    s.line(340, 660, 600, 723, "f")
    s.line(900, 660, 640, 723, "f")
    s.line(980, 660, 1000, 723, "f")
    return s


def avant_apres_modules():
    s = Svg("aa1", 1240, 450, "Avant / après : modules locaux (démo 03) puis modules versionnés (démo 04)")
    s.panel(10, 10, 600, 430, "AVANT — démo 03 : les modules vivent dans le dossier de l'infra")
    s.box(40, 60, 540, 120, "03-module-security/main.tf", [
        'module "network"  { source = "./modules/network"  }',
        'module "security" { source = "./modules/security" }',
        'module "vm"       { source = "./modules/compute"  }',
    ], "gris")
    s.box(40, 200, 540, 70, "03-module-security/modules/", ["network/   security/   compute/      (copiés, sans version)"], "gris")
    s.line(310, 180, 310, 198, "f")
    for i, t in enumerate([
        "Un second projet = copier modules/ : les copies divergent.",
        "Aucune version : une modification part au prochain apply,",
        "   chez tous les utilisateurs, sans qu'ils l'aient choisie.",
        "Rien ne teste ni ne documente le module seul.",
    ]):
        s.text(52 if not t.startswith(" ") else 68, 310 + i * 24, ("✗ " if not t.startswith(" ") else "") + t.strip(), "tko")
    s.panel(630, 10, 600, 430, "APRÈS — démo 04 : un dépôt, un pipeline et des tags par module")
    for i, (n, t) in enumerate([("network", ["v1.0.0"]), ("security", ["v1.0.0 · v1.1.0", "v2.0.0"]), ("compute", ["v1.0.0"])]):
        s.box(660 + i * 185, 60, 170, 80, n, t, "module")
    s.box(660, 200, 540, 90, "infra-dm4/main.tf", [
        'source = "git::https://…/terraform-openstack-security.git?ref=v2.0.0"',
        "la version est CHOISIE par l'infra, montée quand elle le décide",
    ], "nouveau")
    for i in range(3):
        s.line(745 + i * 185, 140, 745 + i * 185 if i != 1 else 930, 198, "fo")
    for i, t in enumerate([
        "Plusieurs consommateurs, chacun à sa version.",
        "Un tag = un code figé, testé, documenté, publié (Release).",
        "SemVer : mineure = rien à changer ; majeure = migration",
        "   décrite dans le CHANGELOG.",
    ]):
        s.text(672 if not t.startswith(" ") else 688, 330 + i * 24, ("✓ " if not t.startswith(" ") else "") + t.strip(), "tok")
    return s


def pipeline_module():
    s = Svg("pmod", 1240, 470, "Pipeline d'un module (templates/module.yml)")
    stages = [("qualite", "MR · branche · tag"), ("test", "MR · branche · tag"), ("securite", "MR · branche · tag"), ("release", "tag vX.Y.Z uniquement")]
    for i, (st, quand) in enumerate(stages):
        x = 20 + i * 305
        cls = "stage-tag" if st == "release" else "stage"
        s.rect(x, 20, 290, 330, cls, rx=10)
        s.text(x + 145, 46, st, "tt", "middle")
        s.text(x + 145, 64, quand, "tm", "middle")
    jobs = {
        0: [("fmt", "terraform fmt -check", "neutre"), ("validate ×2", "Terraform 1.5.7 et 1.16.7", "neutre"),
            ("tflint", "preset « all » : structure, docs", "neutre"), ("docs", "terraform-docs --output-check", "neutre")],
        1: [("terraform-test", "tests/*.tftest.hcl, mock_provider", "neutre"), ("plan-exemple", "examples/basique, sans OpenStack", "nouveau")],
        2: [("checkov", "analyse du code", "neutre"), ("checkov-plan", "analyse du plan JSON (valeurs résolues)", "nouveau"), ("kics", "rapport SAST GitLab", "neutre")],
        3: [("verifier-tag", "SemVer + section du CHANGELOG", "neutre"), ("release", "Release, notes = CHANGELOG", "neutre"), ("publier-registre", "paquet du registre Terraform", "neutre")],
    }
    pos = {}
    for i, lst in jobs.items():
        x = 35 + i * 305
        for j, (n, d, c) in enumerate(lst):
            y = 82 + j * 66
            s.box(x, y, 260, 56, n, [d], c, mono=False)
            pos[n] = (x, y)
    x1, y1 = pos["plan-exemple"]
    x2, y2 = pos["checkov-plan"]
    s.path([(x1 + 260, y1 + 28), (x2 - 8, y2 + 28)], "fo")
    s.text(x1 + 12, y1 + 76, "→ plan-exemple.json", "tm-o")
    s.label(940 + 145, 300, "échec d'un stage précédent ⇒ pas de release", "tm")
    # sorties
    s.text(20, 385, "Produits :", "tp-titre")
    for i, t in enumerate(["rapports JUnit : tests, tflint, checkov", "rapport SAST : KICS", "Release GitLab du tag", "module dans le registre Terraform"]):
        s.chip(20 + i * 305, 400, 290, t, "gris", h=30)
    s.text(20, 455, "En orange : jobs ajoutés par le template v1.1.0 (le passage d'un module à cette version de pipeline est un commit de son dépôt).", "tm-g")
    return s


def pipeline_infra():
    s = Svg("pinf", 1240, 560, "Pipeline de l'infra (templates/infra.yml)")
    s.rect(15, 15, 735, 30, "bande", rx=6)
    s.text(382, 35, "runners partagés gitlab.com : aucun accès au lab", "tm", "middle")
    s.rect(760, 15, 465, 30, "bande-o", rx=6)
    s.text(992, 35, "runner tagué « openstack » : joint l'API du lab", "tm-o", "middle")
    stages = ["conformite", "qualite", "securite", "plan", "deploiement"]
    for i, st in enumerate(stages):
        x = 15 + i * 245
        s.rect(x, 55, 230, 270, "stage", rx=10)
        s.text(x + 115, 80, st, "tt", "middle")
    jobs = [
        [("verifier-refs-modules", "chaque source = ?ref=vX.Y.Z"), ("gitleaks", "aucun secret commité")],
        [("fmt", "style"), ("validate", "modules au tag, lock readonly"), ("tflint", "--call-module-type=all")],
        [("checkov", "infra + modules téléchargés"), ("kics", "rapport SAST")],
        [("plan", "plan.cache + widget de la MR"), ("checkov-plan", "valeurs réelles du plan")],
        [("apply", "MANUEL : applique plan.cache"), ("destroy", "MANUEL")],
    ]
    pos = {}
    for i, lst in enumerate(jobs):
        for j, (n, d) in enumerate(lst):
            x, y = 25 + i * 245, 95 + j * 70
            cls = "nouveau" if n in ("apply",) else "neutre"
            s.box(x, y, 210, 58, n, [d], cls, mono=False)
            pos[n] = (x, y)
    # externes, sous les colonnes qui les utilisent
    s.box(270, 420, 460, 100, "Dépôts des modules (tags)", ["clonés avec le jeton du job : git url.insteadOf + CI_JOB_TOKEN", "(le module autorise l'infra dans l'allowlist du jeton)"], "module", mono=False)
    s.box(760, 420, 220, 100, "État GitLab « dm4 »", ["backend http + verrou", "backend_ci.tf créé en CI", "jeton : CI_JOB_TOKEN"], "ref", mono=False)
    s.box(1000, 420, 225, 100, "API OpenStack du lab", ["OS_CLIENT_CONFIG_FILE", "TF_VAR_public_key_path", "(variables de type fichier)"], "gris", mono=False)
    s.line(375, 325, 375, 418, "fb")
    s.label(375, 375, "validate · tflint", "tm-b")
    s.line(620, 325, 620, 418, "fb")
    s.label(620, 375, "checkov", "tm-b")
    s.line(845, 325, 845, 418, "f")
    s.line(905, 325, 1040, 418, "f")
    s.line(1060, 325, 955, 418, "f")
    s.line(1150, 325, 1150, 418, "f")
    px, py = pos["plan"]
    ax, ay = pos["apply"]
    s.path([(px + 210, py + 29), (ax - 6, ay + 29)], "fo")
    s.text(15, 350, "Un échec dans un stage arrête la suite : pas de plan si un module n'est pas épinglé, pas d'apply si checkov-plan échoue.", "tm-g")
    return s


def histoire_versions():
    s = Svg("hist", 1240, 410, "Histoire des versions : pipeline versionné et faille de sécurité")
    lanes = [(80, "terraform-openstack-security"), (200, "terraform-ci-templates"), (310, "network · compute")]
    for y, n in lanes:
        s.line(240, y, 1210, y, "axe", fleche=False)
        s.text(20, y + 5, n, "tt")

    def point(x, y, cls, haut, bas=(), cote=None):
        s.circle(x, y, 9, cls)
        if haut:
            s.text(x, y - 18, haut, "tt", "middle")
        for k, t in enumerate(bas):
            s.text(x, y + 28 + k * 16, t, "tm", "middle")
        if cote:
            for k, t in enumerate(cote[1]):
                s.text(x + cote[0], y + 5 + k * 16, t, "tm" if k else "tt", "start" if cote[0] > 0 else "end")

    point(320, 200, "pt-ref", "v1.0.0", ["contrôles statiques"])
    point(700, 200, "pt-nouveau", None, cote=(18, ["v1.1.0", "+ plan-exemple, checkov-plan"]))
    point(1100, 200, "pt-ref", "v1.2.0", ["+ multi-environnements"])
    point(320, 80, "pt-ok", "v1.0.0", ["pipeline v1.0.0 : vert"])
    point(460, 80, "pt-ok", "v1.1.0", ["pipeline v1.0.0 : vert"])
    point(700, 80, "pt-ko", "commit « ci: v1.1.0 »", cote=(-16, ["", "checkov-plan : ROUGE", "CKV_OPENSTACK_2"]))
    point(950, 80, "pt-ok", "v2.0.0", ["remote_ip_prefix obligatoire", "majeure : pipeline vert"])
    point(320, 310, "pt-ok", "v1.0.0", ["vert"])
    point(700, 310, "pt-ok", None, ["commit « ci: v1.1.0 » : vert"])
    s.line(700, 190, 700, 92, "fp pointille")
    s.line(700, 210, 700, 298, "fp pointille")
    s.label(700, 150, "adopte le pipeline v1.1.0", "tm-p")
    s.label(700, 258, "adopte le pipeline v1.1.0", "tm-p")
    s.line(712, 80, 938, 80, "fo")
    s.label(825, 70, "correctif", "tm-o")
    s.box(40, 360, 1170, 40, "Le nouveau contrôle de la v1.1.0 du pipeline révèle que le défaut 0.0.0.0/0 ouvre SSH au monde : la correction casse l'interface, d'où v2.0.0.", [], "retenir", mono=False)
    return s


def checkov_statique_plan():
    s = Svg("chk", 1240, 330, "Checkov sur le code ou sur le plan")
    s.panel(10, 10, 560, 310, "Sur le CODE (checkov -d .)")
    s.box(30, 50, 520, 140, "variables.tf / main.tf (security v1.x)", [
        'remote_ip_prefix = optional(string, "0.0.0.0/0")',
        "for_each = { for r in var.rules : … => r }",
        "remote_ip_prefix = each.value.remote_ip_prefix",
        "→ valeur inconnue tant que rules n'est pas évalué",
    ], "gris")
    s.box(30, 220, 520, 70, "Résultat : Passed 2, Failed 0", ["la règle SSH ouverte au monde n'est pas vue"], "gris", mono=False)
    s.line(290, 190, 290, 218, "f")
    s.panel(670, 10, 560, 310, "Sur le PLAN (checkov -f plan.json)")
    s.box(690, 50, 520, 140, "plan-exemple.json (terraform show -json)", [
        'address : module.security…this["tcp-22-22"]',
        "port_range_min : 22, port_range_max : 22",
        'remote_ip_prefix : "0.0.0.0/0"',
        "→ valeurs RÉSOLUES : défauts et for_each appliqués",
    ], "nouveau")
    s.box(690, 220, 520, 70, "Résultat : CKV_OPENSTACK_2 FAILED", ["SSH (22) ouvert depuis 0.0.0.0/0"], "ko", mono=False)
    s.line(950, 190, 950, 218, "fr")
    s.path([(570, 120), (668, 120)], "fo")
    s.label(619, 110, "plan + show", "tm-o")
    return s


def nouvelle_version():
    s = Svg("nv", 1240, 500, "Démo 2 : publier compute v1.1.0 puis l'adopter dans l'infra")
    s.rect(10, 30, 1220, 190, "couloir", rx=10)
    s.text(22, 52, "Dépôt terraform-openstack-compute", "tp-titre")
    s.rect(10, 260, 1220, 200, "couloir", rx=10)
    s.text(22, 282, "Dépôt infra-dm4", "tp-titre")
    etapes_m = [
        ("1", "branche", ["feat/instance-count"], "neutre", None),
        ("2", "modification", ["instance_count", "moved.tf", "sorties en liste", "tests + doc rédigée"], "nouveau", None),
        ("3", "pipeline", ["docs : README périmé"], "neutre", "ko"),
        ("4", "terraform-docs", ["generer-doc.sh", "Inputs / Outputs"], "nouveau", None),
        ("5", "pipeline", ["tout passe"], "neutre", "ok"),
        ("6", "merge + tag", ["v1.1.0 (mineure)"], "nouveau", None),
        ("7", "pipeline du tag", ["verifier-tag", "Release + notes"], "neutre", "ok"),
    ]
    for i, (n, t, l, c, r) in enumerate(etapes_m):
        x = 22 + i * 172
        s.box(x, 70, 158, 130, f"{n}. {t}", l, c, mono=False)
        if r:
            s.chip(x + 12, 168, 134, "ROUGE" if r == "ko" else "VERT", "ko" if r == "ko" else "ok", h=22)
        if i:
            s.line(x - 14, 135, x - 2, 135, "f")
    etapes_i = [
        ("8", "lire la doc", ["README au tag v1.1.0", "« Passer de 1.0.0 »", "CHANGELOG"], "ref", None),
        ("9", "?ref=v1.1.0 seul", ["rien d'autre à changer"], "neutre", "ok"),
        ("10", "s'ajuster", ["vm_count = 2", "sorties en liste"], "nouveau", None),
        ("11", "pipeline infra", ["refs, validate, tflint", "checkov, kics"], "neutre", "ok"),
        ("12", "merge → plan", ["moved : 0 destruction", "2e VM créée"], "nouveau", None),
    ]
    for i, (n, t, l, c, r) in enumerate(etapes_i):
        x = 366 + i * 172
        s.box(x, 300, 158, 140, f"{n}. {t}", l, c, mono=False)
        if r:
            s.chip(x + 12, 408, 134, "VERT", "ok", h=22)
        if i:
            s.line(x - 14, 370, x - 2, 370, "f")
    s.path([(1131, 200), (1131, 240), (445, 240), (445, 298)], "fb")
    s.label(790, 244, "la doc voyage avec le tag : git show v1.1.0:README.md", "tm-b")
    s.text(22, 490, "Mineure : l'étape 9 suffit à rester à jour ; l'étape 10 profite de la nouveauté en suivant le tableau avant / après de la doc.", "tm-g")
    return s


def moved_avant_apres():
    s = Svg("mv", 1240, 420, "Effet des blocs moved : état v1.0.0 puis plan v1.1.0 avec 2 VM")
    s.panel(10, 10, 470, 400, "ÉTAT — compute v1.0.0")
    gauche = ["keypair_v2.this", "port_v2.this", "instance_v2.this   (dm4-vm)", "floatingip_v2.this[0]", "floatingip_associate_v2.this[0]"]
    yg = {}
    for i, t in enumerate(gauche):
        y = 55 + i * 62
        s.box(30, y, 430, 46, t, [], "gris")
        yg[i] = y + 23
    s.panel(560, 10, 670, 400, "PLAN — compute v1.1.0, instance_count = 2")
    droite = [
        ("keypair_v2.this", "inchangé", "gris"),
        ("port_v2.this[0]   ~ nom dm4-vm-1-port", "moved + modifié sur place", "nouveau"),
        ("instance_v2.this[0]   ~ nom dm4-vm-1", "moved + modifié sur place", "nouveau"),
        ("floatingip_v2.this[0] · associate.this[0]", "inchangés", "gris"),
        ("port · instance (dm4-vm-2) · fip · associate [1]", "+ 4 créés", "ok"),
    ]
    for i, (t, e, c) in enumerate(droite):
        y = 55 + i * 62
        s.box(580, y, 450, 46, t, [], c)
        s.chip(1040, y + 10, 175, e, c)
    for i, j in [(0, 0), (1, 1), (2, 2), (3, 3), (4, 3)]:
        cls = "fo" if i in (1, 2) else "f"
        s.line(460, yg[i], 578, 55 + j * 62 + 23, cls)
    s.label(519, 55 + 62 + 12, "moved", "tm-o")
    s.label(519, 55 + 124 + 12, "moved", "tm-o")
    s.box(580, 368, 635, 34, "Plan : 4 to add, 2 to change, 0 to destroy   —   sans moved.tf : dm4-vm détruite puis recréée", [], "retenir", mono=False)
    return s


def envs_avant_apres():
    s = Svg("env", 1240, 560, "Démo 3 : un environnement, puis trois environnements isolés")
    s.panel(10, 10, 360, 540, "AVANT — infra-dm4")
    s.box(30, 55, 320, 90, "un dossier", ["main.tf · terraform.tfvars", "un seul jeu de valeurs"], "gris")
    s.box(30, 175, 320, 60, "un état : dm4", [], "gris")
    s.box(30, 265, 320, 60, "un compte : admin (kolla-aio)", [], "gris")
    s.line(190, 145, 190, 173, "f")
    s.line(190, 235, 190, 263, "f")
    for i, t in enumerate(["Tester une version = la déployer", "là où tourne la « prod ».", "Une erreur de tfvars ou de", "backend touche tout.", "Le compte de CI peut tout faire."]):
        s.text(42, 370 + i * 24, ("✗ " if i in (0, 2, 4) else "   ") + t, "tko")
    s.panel(390, 10, 840, 540, "APRÈS — infra-dm4-envs : même chaîne, trois fois, sans rien de partagé")
    envs = [("dev", "10.60.1.0/24", "192.168.57.0/24", "2 VM", False), ("staging", "10.60.2.0/24", "192.168.57.0/24", "2 VM", False), ("prod", "10.60.3.0/24", "192.168.57.1/32", "4 VM", True)]
    for i, (e, cidr, ssh, quota, prot) in enumerate(envs):
        x = 410 + i * 272
        s.text(x + 125, 60, e.upper(), "tt", "middle")
        s.box(x, 72, 250, 78, f"envs/{e}/", ["main.tf  (?ref= de cet env)", f"tfvars : {cidr}", f"SSH : {ssh}"], "nouveau")
        s.box(x, 180, 250, 58, "backend.hcl", [f".../terraform/state/dm4-{e}"], "neutre")
        s.box(x, 268, 250, 50, f"état GitLab dm4-{e}", [], "ref", centre=True)
        s.box(x, 350, 250, 58, f"clouds.yaml : dm4-{e}", [f"compte ci-dm4-{e}"], "neutre")
        s.box(x, 438, 250, 58, f"projet OpenStack dm4-{e}", [f"quota : {quota}"], "ref")
        s.line(x + 125, 150, x + 125, 178, "f")
        s.line(x + 125, 238, x + 125, 266, "f")
        s.line(x + 125, 408, x + 125, 436, "f")
        s.chip(x, 510, 250, f"variable CI · scope {e}" + (" · PROTÉGÉE" if prot else ""), "ko" if prot else "gris", h=26)
    s.label(815, 334, "provider.tf : cloud = var.cloud_name   (dossier, état, compte : même nom d'environnement)", "tm")
    return s


def pipeline_envs():
    s = Svg("penv", 1240, 520, "Pipeline multi-environnements : une MR qui ne touche que envs/dev")
    s.box(20, 15, 1200, 54, "MR « promotion(dev) » : seul envs/dev/main.tf change", [], "nouveau", mono=False)
    s.text(20, 98, "Jobs communs (templates/environnements.yml), toujours :", "tp-titre")
    communs = ["verifier-refs-modules", "verifier-backends", "matrice-versions", "gitleaks", "fmt", "checkov", "kics"]
    for i, c in enumerate(communs):
        s.chip(20 + i * 172, 110, 160, c, "neutre", h=30)
    s.text(20, 178, "Jobs par environnement (templates/environnement.yml inclus 3 fois, inputs) :", "tp-titre")
    jobs = ["validate", "tflint", "plan", "checkov-plan", "apply"]
    envs = [("dev", "actif", "créés : envs/dev/ a changé"), ("staging", "absent", "non créés : rules:changes"), ("prod", "absent", "non créés · plan seulement sur main")]
    for r, (e, etat, note) in enumerate(envs):
        y = 195 + r * 80
        s.rect(20, y, 1200, 66, "couloir" if etat == "actif" else "couloir-gris", rx=10)
        s.text(40, y + 38, e, "tt")
        for i, j in enumerate(jobs):
            cls = ("nouveau" if j == "apply" else "neutre") if etat == "actif" else "absent"
            s.chip(150 + i * 160, y + 18, 148, f"{j}-{e}", cls, h=30)
        s.text(960, y + 38, note, "tm" if etat == "actif" else "tm-g")
    s.text(20, 460, "Planification nocturne (CI/CD > Schedules) :", "tp-titre")
    for i, e in enumerate(["dev", "staging", "prod"]):
        s.chip(380 + i * 200, 443, 185, f"derive-{e}", "ref", h=30)
    s.text(1000, 463, "plan -detailed-exitcode", "tm")
    s.text(20, 505, "apply-<env> : manuel, branche par défaut, applique plan.cache ; resource_group = un seul plan/apply à la fois par environnement.", "tm-g")
    return s


def promotion():
    s = Svg("promo", 1240, 330, "Promotion de compute v1.1.0 : un commit par environnement")
    cols = [(30, 360, "commit"), (400, 190, "dev"), (600, 190, "staging"), (800, 190, "prod"), (1000, 210, "matrice")]
    for x, w, t in cols:
        s.rect(x, 20, w, 36, "entete", rx=6)
        s.text(x + w / 2, 44, t, "tt", "middle")
    lignes = [
        ("infra initiale", ["v1.0.0", "v1.0.0", "v1.0.0"], "aligné", [None, None, None]),
        ("promotion(dev): compute v1.1.0", ["v1.1.0", "v1.0.0", "v1.0.0"], "promotion en cours", ["nouveau", None, None]),
        ("promotion(staging): compute v1.1.0", ["v1.1.0", "v1.1.0", "v1.0.0"], "promotion en cours", [None, "nouveau", None]),
        ("promotion(prod): compute v1.1.0", ["v1.1.0", "v1.1.0", "v1.1.0"], "aligné", [None, None, "nouveau"]),
    ]
    for r, (c, vs, m, hl) in enumerate(lignes):
        y = 68 + r * 56
        s.box(30, y, 360, 44, c, [], "gris")
        for i, v in enumerate(vs):
            s.chip(cols[i + 1][0], y + 7, cols[i + 1][1], v, hl[i] or "gris", h=30)
        s.chip(1000, y + 7, 210, m, "ok" if m == "aligné" else "nouveau", h=30)
    s.text(30, 310, "Entre deux lignes : apply de l'environnement promu, vérification, puis MR suivante. ./scripts/promouvoir.sh vérifie que le tag existe.", "tm-g")
    return s


def garde_fou_backend():
    s = Svg("gf", 1240, 300, "Garde-fou : un backend copié d'un autre environnement")
    for i, (e, cible, ko) in enumerate([("dev", "dm4-dev", False), ("staging", "dm4-prod", True), ("prod", "dm4-prod", False)]):
        y = 30 + i * 85
        s.box(30, y, 330, 62, f"envs/{e}/backend.hcl", ["copié depuis envs/prod/" if ko else f".../state/dm4-{e}"], "ko" if ko else "neutre")
    for i, e in enumerate(["dm4-dev", "dm4-staging", "dm4-prod"]):
        y = 30 + i * 85
        s.box(520, y, 240, 62, f"état {e}", ["aucun écrivain" if e == "dm4-staging" else ""], "absent" if e == "dm4-staging" else "ref", centre=True)
    s.line(360, 61, 518, 61, "f")
    s.line(360, 146, 518, 228, "fr")
    s.line(360, 231, 518, 236, "f")
    s.box(820, 30, 400, 230, "verifier-backends : ÉCHEC", [
        "OK  dev : état dm4-dev",
        "OK  prod : état dm4-prod",
        "KO  staging : l'état 'dm4-prod' ne",
        "    porte pas le nom de l'environnement",
        "KO  état partagé par plusieurs",
        "    environnements : …/state/dm4-prod",
        "",
        "Sans lui : l'apply de staging écrase",
        "l'état de prod.",
    ], "ko")
    return s


# --------------------------------------------------------------------- page ---

SCHEMAS = {}


def fig(fn, legende):
    s = fn()
    SCHEMAS[s.nom] = s
    return f'<figure><div class="cadre">{s.rendu()}</div><figcaption>{legende}</figcaption></figure>'


def boites(apporte, coute):
    li = lambda l: "".join(f"<li>{x}</li>" for x in l)
    return (f'<div class="grille"><div class="boite interet"><h4>Ce que ça apporte</h4><ul>{li(apporte)}</ul></div>'
            f'<div class="boite cout"><h4>Ce que ça coûte</h4><ul>{li(coute)}</ul></div></div>')


CSS = """
:root{--bleu:#0066cc;--bleu-fonce:#003d7a;--orange:#ff6b35;--vert:#059669;--rouge:#dc2626;--fond:#f7f9fc;--texte:#232f3e;--bord:#d5dbdb}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:var(--texte);background:var(--fond);line-height:1.6}
a{color:var(--bleu)}
code{font-family:'SF Mono',Menlo,Consolas,monospace;font-size:.9em;background:#eef2f7;padding:1px 5px;border-radius:4px}
header.bandeau{background:linear-gradient(135deg,var(--bleu-fonce),var(--bleu));color:#fff;padding:2.2rem 2rem 1.6rem}
header.bandeau h1{font-size:1.9rem;font-weight:600;letter-spacing:-.3px}
header.bandeau p{opacity:.92;max-width:1100px;margin-top:.5rem}
nav.modules{position:sticky;top:0;z-index:20;background:#fff;border-bottom:1px solid var(--bord);display:flex;gap:.4rem;padding:.5rem 2rem;overflow-x:auto;box-shadow:0 2px 6px rgba(0,0,0,.06)}
nav.modules a{text-decoration:none;white-space:nowrap;padding:.35rem .7rem;border-radius:16px;border:1px solid var(--bord);font-size:.85rem;color:var(--bleu-fonce)}
nav.modules a:hover{background:#eef6ff;border-color:var(--bleu)}
main{max-width:1500px;margin:0 auto;padding:1.5rem 2rem 4rem}
section.module{background:#fff;border:1px solid var(--bord);border-radius:12px;padding:1.8rem 2rem;margin:1.6rem 0;box-shadow:0 1px 3px rgba(0,0,0,.08)}
section.module>header{display:flex;align-items:flex-start;gap:1rem;border-bottom:2px solid var(--bord);padding-bottom:1rem;margin-bottom:1.2rem}
.num{flex:none;width:52px;height:52px;border-radius:12px;background:linear-gradient(135deg,var(--bleu),var(--bleu-fonce));color:#fff;font-size:1.5rem;font-weight:700;display:flex;align-items:center;justify-content:center}
section.module h2{font-size:1.55rem;color:var(--bleu-fonce);font-weight:600}
.sous{color:#546e7a;font-size:1rem}
h3{font-size:1.15rem;color:var(--bleu);margin:1.6rem 0 .7rem;font-weight:600}
h4{font-size:1rem;color:var(--bleu-fonce);margin:0 0 .4rem}
p{margin-bottom:.7rem}
.boite{border-radius:8px;padding:1rem 1.2rem;margin:1rem 0;border-left:4px solid var(--bleu)}
.grille{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin:1rem 0}
.grille .boite{margin:0}
.interet{background:#f0fdf4;border-left-color:var(--vert)}
.cout{background:#fef2f2;border-left-color:var(--rouge)}
.boite ul{margin:.3rem 0 .2rem 1.2rem}
.boite li{margin-bottom:.3rem}
figure{margin:1.2rem 0}
.cadre{border:1px solid var(--bord);border-radius:8px;overflow:auto;background:#fff}
.cadre svg{display:block;width:100%;height:auto;min-width:900px;cursor:zoom-in}
figcaption{font-size:.9rem;color:#475569;padding:.5rem .3rem 0}
ul.legende{list-style:none;display:flex;flex-wrap:wrap;gap:.6rem 1.4rem;margin:.6rem 0}
ul.legende li{display:flex;align-items:center;gap:.45rem;font-size:.88rem}
.pastille{width:20px;height:13px;border-radius:3px;border:2px solid;display:inline-block}
table{width:100%;border-collapse:separate;border-spacing:0;margin:.8rem 0 1.2rem;border:1px solid var(--bord);border-radius:8px;overflow:hidden;font-size:.88rem}
th,td{padding:.55rem .7rem;text-align:left;border-bottom:1px solid var(--bord);vertical-align:top}
th{background:#eef2f7;color:var(--bleu-fonce);font-weight:600;font-size:.8rem;text-transform:uppercase;letter-spacing:.4px}
tbody tr:last-child td{border-bottom:none}
#zoom{position:fixed;inset:0;background:rgba(15,23,42,.92);z-index:100;display:none;overflow:auto;padding:2rem}
#zoom.actif{display:block}
#zoom .fermer{position:fixed;top:1rem;right:1.2rem;color:#fff;font-size:.9rem;background:rgba(255,255,255,.15);padding:.4rem .8rem;border-radius:6px;cursor:pointer}
#zoom svg{background:#fff;border-radius:8px;display:block;margin:0 auto;width:1800px;max-width:none;cursor:zoom-out}
footer{max-width:1500px;margin:0 auto;padding:0 2rem 2rem;color:#64748b;font-size:.85rem}
@media (max-width:900px){.grille{grid-template-columns:1fr}main{padding:1rem}section.module{padding:1.2rem 1rem}header.bandeau{padding:1.6rem 1rem 1.2rem}}
/* ---- SVG ---- */
svg text{white-space:pre;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;fill:#232f3e}
svg .tt{font-size:14px;font-weight:600}
svg .tl{font-family:'SF Mono',Menlo,Consolas,monospace;font-size:12px;fill:#334155}
svg .tp{font-size:12.5px;fill:#334155}
svg .tc{font-size:12px;font-weight:600}
svg .tm{font-size:12px;fill:#475569}
svg .tm-g{font-size:12.5px;fill:#64748b;font-style:italic}
svg .tm-o{font-size:12px;fill:#c2410c;font-weight:600}
svg .tm-b{font-size:12px;fill:#0052a3;font-weight:600}
svg .tm-p{font-size:12px;fill:#6d28d9;font-weight:600}
svg .tp-titre{font-size:15px;font-weight:700;fill:#003d7a}
svg .tok{font-size:13px;fill:#047857}
svg .tko{font-size:13px;fill:#b91c1c}
svg .b{stroke-width:1.6}
svg .neutre{fill:#ffffff;stroke:#94a3b8}
svg .gris{fill:#f1f5f9;stroke:#cbd5e1}
svg .gris-t,svg .neutre-t{fill:#232f3e}
svg .module{fill:#eef6ff;stroke:#0066cc}
svg .module-t{fill:#003d7a}
svg .ref{fill:#e0ecff;stroke:#3b82f6}
svg .ref-t{fill:#1e3a8a}
svg .infra{fill:#f5f3ff;stroke:#7c3aed}
svg .infra-t{fill:#4c1d95}
svg .nouveau{fill:#fff4ed;stroke:#ff6b35;stroke-width:2.2}
svg .nouveau-t{fill:#9a3412}
svg .ok{fill:#ecfdf5;stroke:#059669}
svg .ok-t{fill:#065f46}
svg .ko{fill:#fef2f2;stroke:#dc2626;stroke-width:2.2}
svg .ko-t{fill:#991b1b}
svg .retenir{fill:#fff8f0;stroke:#ff6b35}
svg .retenir-t{fill:#9a3412}
svg .absent{fill:#f8fafc;stroke:#cbd5e1;stroke-dasharray:5 4}
svg .absent-t{fill:#94a3b8}
svg .panneau{fill:#fbfcfe;stroke:#d5dbdb;stroke-width:1.2}
svg .stage{fill:#f8fafc;stroke:#cbd5e1}
svg .stage-tag{fill:#f8fafc;stroke:#7c3aed;stroke-dasharray:6 4}
svg .bande{fill:#eef2f7;stroke:none}
svg .bande-o{fill:#fff4ed;stroke:#ff6b35}
svg .couloir{fill:#f8fbff;stroke:#bcd4f0}
svg .couloir-gris{fill:#f8fafc;stroke:#e2e8f0}
svg .entete{fill:#eef2f7;stroke:#cbd5e1}
svg .etiq{fill:#ffffff;stroke:none;opacity:.92}
svg .axe{stroke:#cbd5e1;stroke-width:3}
svg .f{stroke:#64748b;stroke-width:1.6}
svg .fo{stroke:#ff6b35;stroke-width:2.2}
svg .fr{stroke:#dc2626;stroke-width:2.4}
svg .fv{stroke:#059669;stroke-width:2}
svg .fb{stroke:#0066cc;stroke-width:1.6}
svg .fp{stroke:#7c3aed;stroke-width:1.6}
svg .pointille{stroke-dasharray:6 4}
svg .pt-ok{fill:#059669}
svg .pt-ko{fill:#dc2626}
svg .pt-ref{fill:#3b82f6}
svg .pt-nouveau{fill:#ff6b35}
"""

JS = """
const z=document.getElementById('zoom');
document.querySelectorAll('.cadre svg').forEach(s=>s.addEventListener('click',()=>{
  z.querySelector('.contenu').innerHTML='';z.querySelector('.contenu').appendChild(s.cloneNode(true));z.classList.add('actif')}));
z.addEventListener('click',()=>z.classList.remove('actif'));
document.addEventListener('keydown',e=>{if(e.key==='Escape')z.classList.remove('actif')});
"""


def page():
    legende = """<ul class="legende">
<li><span class="pastille" style="background:#fff4ed;border-color:#ff6b35"></span>nouveau / modifié</li>
<li><span class="pastille" style="background:#fef2f2;border-color:#dc2626"></span>problème / contrôle en échec</li>
<li><span class="pastille" style="background:#ecfdf5;border-color:#059669"></span>contrôle réussi / créé</li>
<li><span class="pastille" style="background:#f1f5f9;border-color:#cbd5e1"></span>inchangé</li>
<li><span class="pastille" style="background:#eef6ff;border-color:#0066cc"></span>module</li>
<li><span class="pastille" style="background:#f5f3ff;border-color:#7c3aed"></span>infra (consommateur) · include de pipeline</li>
<li><span class="pastille" style="background:#f8fafc;border-color:#cbd5e1;border-style:dashed"></span>absent / non créé</li>
</ul>"""
    s0 = f"""<section class="module" id="vue"><header><div class="num">0</div><div><h2>Vue globale</h2>
<div class="sous">Six dépôts : un pour les pipelines, trois modules, deux infras qui les consomment</div></div></header>
<p>Chaque flèche est une <b>référence à une version</b> : un <code>include … ref:</code> pour les pipelines, un
<code>?ref=vX.Y.Z</code> pour les modules. Rien n'est partagé « en direct ».</p>
{legende}
{fig(vue_globale, "Les modules et les pipelines sont publiés par tags ; chaque infra choisit les versions qu'elle consomme.")}
<table><thead><tr><th>Mode</th><th>Où vivent les dépôts</th><th>Pipelines</th></tr></thead><tbody>
<tr><td>Local</td><td><code>.depots-git/</code> (dépôts git nus, vrais tags) ; <code>env-depots-locaux.sh</code> redirige <code>https://gitlab.com/…</code> vers eux (<code>url.insteadOf</code>)</td><td><code>controles-locaux.sh</code> rejoue les jobs avec Docker, mêmes images</td></tr>
<tr><td>GitLab</td><td>gitlab.com/mohamed.aijjou1780, publiés par <code>publier-sur-gitlab.sh</code></td><td>vrais pipelines ; plan/apply sur le runner « openstack »</td></tr>
</tbody></table></section>"""

    s1 = f"""<section class="module" id="d1"><header><div class="num">1</div><div><h2>Modules versionnés par tags, avec CI</h2>
<div class="sous">README.md — un dépôt et un pipeline par module ; l'infra épingle les versions et a son propre pipeline</div></div></header>
<h3>Avant / après</h3>
{fig(avant_apres_modules, "De la démo 03 à la démo 04 : le module sort du dossier de l'infra et devient un produit versionné.")}
{boites(["Une version = un code figé : l'infra sait exactement ce qu'elle déploie.", "Chaque consommateur monte de version quand il le décide.", "Le module est testé, documenté et scanné une fois, pour tous."],
        ["Un dépôt et un pipeline de plus par module.", "Monter de version est un geste explicite (changer <code>ref</code>, relancer <code>init</code>).", "Les tags doivent être protégés pour rester fiables."])}
<h3>Pipeline d'un module</h3>
{fig(pipeline_module, "Sur une MR ou une branche : qualité, tests, sécurité. Sur un tag : en plus, contrôle du tag, Release et registre.")}
<h3>Pipeline de l'infra</h3>
{fig(pipeline_infra, "Les jobs statiques tournent sur les runners partagés ; plan et apply sur un runner qui joint le lab.")}
<h3>Histoire des versions</h3>
{fig(histoire_versions, "Le pipeline est lui aussi versionné : son passage en v1.1.0 révèle une faille de security v1.x, corrigée par une majeure.")}
<h3>Pourquoi analyser aussi le plan</h3>
{fig(checkov_statique_plan, "Même module, même règle Checkov : seul le plan JSON montre la règle SSH ouverte au monde.")}
{boites(["Le plan de l'exemple tourne sans OpenStack : le contrôle est possible dès le pipeline du module.", "Le défaut dangereux est vu avant toute Release."],
        ["Un job de plus par pipeline de module.", "Les modules à data source (lecture d'API) ne peuvent pas être planifiés sans cloud."])}
</section>"""

    s2 = f"""<section class="module" id="d2"><header><div class="num">2</div><div><h2>Publier une nouvelle version, puis l'adopter</h2>
<div class="sous">DEMO-NOUVELLE-VERSION.md — compute v1.1.0 (plusieurs VM), documentée, validée, taguée ; l'infra suit la doc</div></div></header>
{fig(nouvelle_version, "Douze étapes, deux dépôts : la doc publiée avec le tag est le contrat entre l'équipe module et l'équipe infra.")}
<h3>Ce que voit le plan de l'infra</h3>
{fig(moved_avant_apres, "Les blocs moved déplacent la VM et le port existants vers [0] : renommage sur place, aucune destruction.")}
{boites(["Le job docs empêche de publier une doc fausse.", "La section « Passer de 1.0.0 à 1.1.0 » dit exactement quoi changer.", "Une mineure se vérifie : <code>?ref=</code> seul, pipeline vert."],
        ["Le module garde ses anciennes sorties (dépréciées) jusqu'à la 2.0.0.", "Les blocs moved sont à écrire et à garder tant que d'anciens états existent."])}
</section>"""

    s3 = f"""<section class="module" id="d3"><header><div class="num">3</div><div><h2>Plusieurs environnements : dev, staging, prod</h2>
<div class="sous">DEMO-ENVIRONNEMENTS.md — un dossier, un backend, un état, des identifiants et des versions par environnement</div></div></header>
<h3>Avant / après</h3>
{fig(envs_avant_apres, "Chaque environnement a sa chaîne complète : dossier → backend → état, et entrée clouds.yaml → compte → projet.")}
{boites(["Un destroy en dev ne peut pas toucher la prod (autre état, autre compte, autre projet).", "La CI de dev ne reçoit jamais les identifiants de prod.", "Les écarts entre environnements se lisent dans un diff de dossiers."],
        ["La composition est répétée dans chaque <code>envs/&lt;env&gt;/main.tf</code>.", "Un socle à appliquer une fois (projets, comptes, quotas).", "Trois variables d'identifiants à gérer dans GitLab."])}
<h3>Pipeline : seul l'environnement modifié est planifié</h3>
{fig(pipeline_envs, "Le même template, inclus une fois par environnement avec inputs ; rules:changes ne crée que les jobs de l'environnement touché.")}
<h3>Promotion d'une version</h3>
{fig(promotion, "La matrice des versions (job matrice-versions) suit la promotion ; l'historique git en est le journal.")}
<h3>Le garde-fou des backends</h3>
{fig(garde_fou_backend, "Le risque propre au dossier par environnement : copier un dossier sans adapter son backend.")}
{boites(["L'erreur de copier-coller est bloquée avant tout plan.", "Un état partagé par deux environnements est détecté."],
        ["Une convention à respecter : le nom de l'état finit par le nom du dossier."])}
</section>"""

    nav = "".join(f'<a href="#{i}">{t}</a>' for i, t in [("vue", "0 · Vue globale"), ("d1", "1 · Modules versionnés et CI"), ("d2", "2 · Nouvelle version"), ("d3", "3 · Environnements")])
    return f"""<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Démo modules 4 — schémas</title>
<style>{CSS}</style></head><body>
<header class="bandeau"><h1>Démo modules 4 — schémas</h1>
<p>Modules Terraform dans des dépôts versionnés par tags, pipelines GitLab CI pour les modules et pour l'infra,
publication d'une nouvelle version, déploiement en dev, staging et prod. Cliquer sur un schéma pour l'agrandir.</p></header>
<nav class="modules">{nav}</nav>
<main>{s0}{s1}{s2}{s3}</main>
<footer>Généré par <code>outils/generer-schemas.py</code> — ne pas modifier cette page à la main.</footer>
<div id="zoom"><span class="fermer">Fermer (Échap)</span><div class="contenu"></div></div>
<script>{JS}</script>
</body></html>"""


if __name__ == "__main__":
    SORTIE.write_text(page(), encoding="utf-8")
    print(f"{SORTIE} : {len(SCHEMAS)} schémas")
