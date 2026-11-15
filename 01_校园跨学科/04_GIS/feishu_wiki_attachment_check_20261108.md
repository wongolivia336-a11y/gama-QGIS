# 飞书 Wiki 附件核查（2026-11-08）

核查页面：<https://s111qne3aie.feishu.cn/wiki/PXqAwgAPti7w8dkPpJIcDWTknOg>

页面可见四个文件附件：

- `meeting_02.mp4`：20.42 MB
- `meeting_03.mp4`：17.35 MB
- `同济大学PLAN.DWG`：1.15 MB；页面可点击下载，但浏览器预览不支持 DWG
- `CampuScope.zip`：1.56 MB

页面可见附件中没有 QGIS 工程引用的 `.gpkg`。本地已提供的 `CampuScope.zip` 内有示例 `roads_32651.geojson`、`buildings_32651.geojson`、`entrances_32651.geojson`、干预区域 GeoJSON、属性 CSV 和 `CampuScope.gaml`；不是完整校园 GeoPackage 数据包。

`同济大学PLAN.DWG` 可能是可转换的 CAD 底图源，但目前尚未读取其图层、坐标系、覆盖范围和门位信息。因此它只能列为待核验的候选源，不能替代缺失的 13 个 GPKG。飞书页面未提供稳定的公开直链；附件需在页面内点击下载。
