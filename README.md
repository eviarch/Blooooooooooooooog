# Eviarch's blog

[![CI build](https://github.com/eviarch666/Blooooooooooooooog/actions/workflows/ci-build.yml/badge.svg)](https://github.com/eviarch666/Blooooooooooooooog/actions/workflows/ci-build.yml)

Personal blog built with [Hexo](https://hexo.io/) and the [Redefine](https://github.com/EvanNotFound/hexo-theme-redefine) theme. Posts are rendered with Pandoc.

## Blog URL

https://blog.eviarch.com

## Local preview

Pandoc must be installed. Node.js 20 matches the CI workflow.

```bash
npm install
npm run server
```

`npm run build` generates the site into `public/`. `make preview` and `make deploy` do the same two steps.

Pushing to `main` runs the CI workflow, which builds the site and force-pushes the result to the `deploy` branch.

## File tree

```text
.
├── source
│   ├── _posts/                         # published posts
│   ├── _data/
│   │   ├── bookmarks.yml               # /bookmarks/
│   │   ├── essays.yml                  # Moments page (/essays/)
│   │   ├── links.yml                   # friend links (/links/)
│   │   └── masonry.yml                 # waterfall gallery (/masonry/)
│   ├── bookmarks/
│   ├── categories/
│   ├── essays/
│   ├── links/
│   ├── masonry/
│   ├── tags/
│   ├── post_images/                    # one folder per post, plus shared assets
│   │   ├── background_image/
│   │   ├── moments_images/
│   │   └── <post-title>/
│   └── masonry_images/                 # gallery images; see IMAGE_SIZE_GUIDELINES.md
├── notes/                              # drafts and logs; Hexo does not publish this folder
│   ├── UnfinishedNotes/
│   └── WorkLog/
├── scaffolds/                          # hexo new templates
├── .github/workflows/ci-build.yml
├── _config.yml                         # Hexo site config
├── _config.redefine.yml                # Redefine theme config
├── Makefile
├── package.json
└── vercel.json
```

The theme package is `hexo-theme-redefine`. `themes/` in this repo only holds a placeholder.

## Acknowledgement

🩵Thanks to [Shetty Yttehs](https://github.com/Yttehs-HDX) for technical support while building this site.

❤️Thanks to [AeRonMeri](https://x.com/Aeronmeri_19198) for the background image. Bilibili: [AERONM](https://space.bilibili.com/1151788364).

## License

- this project use MIT license
- blog posts use [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0) license
- posts that in **notes** folder also use [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0) license
- Background images and avatars are not allowed to be used. All rights reserved.
