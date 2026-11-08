# QGIS 配套数据：需要补给什么

QGIS 桌面程序可以打开 `同济四平路校区.qgz`。`.qgz` 主要保存图层清单、样式、地图范围和数据源位置；建筑面、门点、道路、候选点等几何实际保存在它引用的 GeoPackage（`.gpkg`）里。当前收到工程文件，没有收到这些 GPKG，所以图层名能看到，但地图要素/数量不能读取。

## 请发一个压缩包

最方便的是：在 QGIS 项目所在文件夹里，把工程引用的 `.gpkg` 文件连同 `同济四平路校区.qgz` 一起压缩。若原文件夹里还有同名 `.gpkg-wal` / `.gpkg-shm`，请先在 QGIS 关闭工程后再压缩。不要只发 `.qgz`。

需要的文件如下：

| 文件 | 用途 |
|---|---|
| `research_buildings.gpkg` | 重点研究建筑边界与名称 |
| `building_entrances.gpkg` | 各建筑楼门位置；图层标签写“40个”，需核实要素和归属 |
| `roads.gpkg`, `nodes.gpkg` | 道路与节点底图 |
| `model_roads.gpkg`, `model_nodes.gpkg` | 可供 Agent 行走的模拟路网 |
| `interventions.gpkg` | “约50m”候选干预点，核实真实点数和字段 |
| `other_buildings.gpkg`, `other_sports.gpkg`, `sports_fields.gpkg` | 灰色背景建筑与运动空间 |
| `green_spaces.gpkg`, `campus_boundary.gpkg`, `water_bodies.gpkg` | 校园背景、边界、绿地和水体 |

## 收到后会核验

- GPKG 是否可读、坐标系和字段是否完整；
- 西北/西南宿舍各自分了哪些栋，核对暂列的西北二舍名称；
- 校园校门与建筑楼门分别有多少、各自属于哪栋，门点如何接入路网；
- 道路与节点是否连通，建筑到路网有没有断点；
- 干预候选点的真实数量、分布和字段；
- 重点建筑与普通背景建筑的分类是否能映射到模型。

核验后会把 GIS 特征转换为 GAMA 可读的 GeoJSON/网络 JSON，再用 1,474 人、固定随机种子进行全日基线运行。
