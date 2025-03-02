# 发布新版本

* 确保当前位于和 GitHub 同步的 master 分支，工作树干净。
* `python scripts/prepare-release.py`，它会
  * 对当前 commit 打 tag；
  * 将新版本插入 [version.jsonl](../version.jsonl) 首行；
  * 更新 [CMakeLists.txt](../CMakeLists.txt) 中的版本号；
  * 将上述两个文件的更改加入暂存区。
* `git push origin 版本号`，这会在 GitHub 上创建一个新的 draft release。
* 编辑日志，删除 debug tar，点击 Publish release。
* 在 [fcitx5-plugins](https://github.com/fcitx-contrib/fcitx5-plugins) 中发布新版插件。
* `git push origin master`，这将更新 latest 中的 version.json，
