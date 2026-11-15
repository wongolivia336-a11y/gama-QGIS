# TongjiDailyScope 全天工程包（2026-11-08）

这是用户提供工程包中用于复跑 GAMA 原型的最小输入集。模型是基于行为规则生成的合成 Agent 推演，不包含真实个人 GPS 或真实选课名单。

## 文件

- `models/TongjiDailyScope.gaml`：07:30–17:30 全天模型，GAMA 2025.6.4。
- `includes/daily_plan.json.gz`：固定种子生成的场景计划；其中含道路、建筑、入口、候选点、路径和活动任务输入。GeoJSON 来源和要素审计摘要见 `includes/input_audit.json`。
- `includes/population.csv`：1474 人五专业合成 Agent 表。
- `includes/course_aggregation.json`：由排课记录聚合的时段课程参与率；不是独立学生数量。
- `validation/verification.json`：随包基线/设施结果核验摘要。

## 复跑

1. 使用 GAMA 2025.6.4 或兼容版本，在本目录将 `includes/daily_plan.json.gz` 解压为 `includes/daily_plan.json`。
2. 保留 `models/` 与 `includes/` 的相对位置；在 GAMA 中打开 `models/TongjiDailyScope.gaml`。
3. 默认运行无设施吸引的观察基线。结果默认写入 `results/live/`；对比时保持同一计划和随机种子。

压缩日计划是已生成的场景快照，不是从个人选课重建的日程。更新 GIS 或行为参数后，应重新生成并审计计划；不要将此快照解释为现场调查数据。

## 输入核验边界

原始 QGIS `.qgz` 引用的 GPKG 未包含在本目录。日计划使用用户交付包中的 GeoJSON 导出；其中 4 个校园接入候选有 3 个来自 OSM 推定，西北二舍未定位。包内数量与路网可供原型运行，不代表 QGIS 源图层及现场门位已最终确认。
