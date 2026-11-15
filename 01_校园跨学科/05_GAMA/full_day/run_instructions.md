# 全天模型运行说明

## 本地目录结构

```text
full_day/
├── models/CampusScopeFullDay.gaml
├── includes/
│   ├── population_full_day.csv
│   ├── full_day_origin_allocation.csv
│   ├── full_day_activity_profile.json
│   └── QGIS转换后生成的 full_day_* 几何/网络文件
└── tools/build_full_day_gama.py
```

## 当前可复现内容

- GAMA 2025.6.4 可编译 `CampusScopeFullDay.gaml`。
- 代理人数量固定 1,474，人口构造种子为 20261105，GAMA 种子为 42。
- 模拟时间为 07:30–17:30；按时间段选择活动，下午回程窗口从 17:00 开始。
- 输入规范和分时权重见 `includes/`。若重新生成人口文件，运行 `python tools/build_full_day_gama.py`；脚本基于旧模型模板派生全日 GAML，并重写人口/参数文件。

## GIS 输入状态

全日模型期望以下文件位于 `includes/`：

- `full_day_map_meta.json`
- `full_day_buildings.geojson`
- `full_day_roads.geojson`
- `full_day_portals.geojson`
- `full_day_network.json`

当前用户提供的 QGIS 工程引用的 GPKG 尚未提供，不能用旧 NoonScope 几何代替全校区正式输入。`full_day_*` 的文件契约、建筑/多门/活动建筑映射要求见 `includes/全天网络输入约定.md`。获取 GPKG 后先核验拓扑和建筑归属，再转换这些输入。

## 结果解释边界

此前的全日 smoke test 用旧午间示意地图，只检查 Agent 数量、模型时钟、状态结束和输出流程。它不是本项目的全校区运行，也不支持基于旧图的空间结论。课表聚合权重已经整理到参数表，GAML 还没有接入逐条排课数据；当前全日规则是显式的行为推演基线。
