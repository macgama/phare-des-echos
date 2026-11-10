# Le Phare des Échos

Un jeu cosy en pixel art : le jour, tu répares et améliores ton phare ; la nuit, tu guides les bateaux à travers la tempête. Les visiteurs apportent des fragments d'une histoire mystérieuse.

Ce dépôt contient pour l'instant un **prototype de la nuit**, en formes simples (« greybox ») : on teste si le jeu est amusant avant de dessiner les vrais graphismes.

## Comment on joue

- Le **rayon du phare suit ta souris** (ou les flèches gauche / droite du clavier).
- Un bateau **éclairé** voit les rochers, les évite et file vers le **port** (en bas à droite).
- Un bateau **dans le noir** dérive, poussé par le vent de la tempête.
- Les rochers n'apparaissent **que dans la lumière**, ou une seconde pendant un **éclair** : profite-en pour les repérer !
- 4 bateaux arrivent les uns après les autres. **2 naufrages = défaite.** Sinon, l'aube se lève et tu as gagné.
- À la fin, clique ou appuie sur **R** pour rejouer.

## Jouer dans le navigateur

À chaque modification envoyée sur la branche `main`, GitHub construit automatiquement la version web et la publie sur GitHub Pages.

Première fois seulement : dans le dépôt GitHub, va dans **Settings → Pages**, et sous **Source** choisis **GitHub Actions**. Le lien du jeu apparaît ensuite en haut de cette même page (de la forme `https://<ton-pseudo>.github.io/phare-des-echos/`).

## Ouvrir le projet dans Godot (pour le modifier)

1. Télécharge **Godot 4.3** (gratuit) sur [godotengine.org/download](https://godotengine.org/download). Prends la version standard, pas « .NET ».
2. Télécharge ce dépôt : bouton vert **Code → Download ZIP** sur GitHub, puis décompresse-le.
3. Lance Godot, clique **Importer**, et choisis le fichier `project.godot` du dossier.
4. Appuie sur **F5** (ou le bouton ▶ en haut à droite) pour lancer le jeu.

## Changer la difficulté

Ouvre `scripts/night.gd` : tout en haut, la section « Réglages » contient les valeurs à modifier, par exemple :

| Réglage | Effet |
|---|---|
| `BEAM_HALF_ANGLE` | largeur du rayon (plus grand = plus facile) |
| `BEAM_TURN_SPEED` | vitesse de rotation du rayon |
| `SHIP_COUNT` | nombre de bateaux dans la nuit |
| `SPAWN_INTERVAL` | secondes entre deux bateaux (plus petit = plus dur) |
| `MAX_WRECKS` | nombre de naufrages qui fait perdre |

## Organisation des fichiers

- `project.godot` : la configuration du projet.
- `scenes/night.tscn` : la scène de la nuit.
- `scripts/night.gd` : toute la logique et le dessin du prototype, commentés en français.
- `export_presets.cfg` : le réglage d'export web.
- `.github/workflows/web.yml` : la construction automatique de la version web.

## Licence des contenus

Pour l'instant tout est dessiné par le code, sans image ni son externe. Les futurs graphismes et sons seront uniquement libres de droits (par exemple CC0), et leur source sera notée ici.
