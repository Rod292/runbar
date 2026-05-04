# RunBar — landing page

Landing page Next.js 14 (App Router) + Tailwind v3, conçue pour
promouvoir l'app menu-bar **RunBar** sur macOS.

## Direction

Pristine Light Mode · serif éditorial italique × grotesk · accent vermillon
trail breton (`#E5523D`) · narrative spine "tool / precision instrument" ·
hero Mini Minimalist · 6 sections, anchors et background modes variés
(stacked center → diptych moss/paper → gradient cinematic).

## Lancer

```sh
npm install
npm run dev   # http://localhost:3000
```

## Déployer le binaire

Le bouton "Télécharger pour macOS" pointe vers `/download/RunBar.dmg`.
Dépose le `.dmg` signé/notarisé dans `public/download/` avant publication
(ou remplace `href` par une URL GitHub Releases dans
`components/DownloadButton.tsx` + `components/Header.tsx`).

## Stack

- Next.js 14.2 · React 18.3 · Tailwind 3.4
- Aucune dépendance JS supplémentaire — animation runner en SVG inline + CSS keyframes
- Tout en français
