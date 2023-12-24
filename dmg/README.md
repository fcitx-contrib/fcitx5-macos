This directory contains files necessary to generate Fcitx5.dmg.

[fcitx.icns](./fcitx.icns) is generated from the official [logo](../fcitx5/data/icon/scalable/apps/org.fcitx.Fcitx5.svg).

[backgroud.tiff](./background.tiff) is generated with
```sh
tiffutil -cathidpicheck background.png background@2x.png -out background.tiff
```
where the 2 PNGs are exported from draw.io with 100% and 200% scale.
