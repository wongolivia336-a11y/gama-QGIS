# 大学路 GAMA 选址模拟

## 推荐位置

沿大学路从智星路向锦创路量约 **130–140 m**，西北侧步行带是当前优选试点区间。图面若需要一个标注点，使用 140 m：暂定坐标 `121.506010°E, 31.306401°N`。该坐标由 OSM 道路轴线加假设的 6.5 m 侧向偏移得到，供地图定位和踏勘使用，不是放样坐标。原 B 点 135 m 与模拟名义最优点只差 5 m，二者的模拟差异很小。

140 m 在 2020-08-13 与 2022-07-13 两个高温天气的情景平均中都取得最低行人短波暴露代理；相对无装置基线分别降低 34.874 和 30.957 W/m²。130–140 m 的点位差小于模型假设的不确定性，因此结论是一个踏勘区间，不是精确到 1 m 的预测。

## 运行方式

使用 GAMA 2025.6.4 打开 `model/DaxueRoadHeatPilot.gaml`，运行 `PilotPreview` 可查看动态平面场景。沿线每 10 m 粗扫使用 `model/DaxueRoadSiteSweepProbe.gaml` 的 `SiteSweep10m` 实验；六位置人群敏感性复核分别使用：

- `model/DaxueRoadSiteSweepShortlistFixed.gaml`：2020-08-13
- `model/DaxueRoadSiteSweepShortlistFixed2022.gaml`：2022-07-13

本目录附有 GAMA 模型和批量结果；[OBS 实录视频（PilotPreview，140 m）](results/GAMA_PilotPreview_OBS_140m.mp4)（约 19 秒）使用 OBS 的“GAMA 实际运行”场景捕捉 GAMA 应用窗口，展示 140 m 名义点的预览情景。

批量实验会把原始 CSV 写入同级 `results/`。`*_raw.csv` 是 GAMA 直接输出；整理版 CSV 额外给出 `site_label`。位置分析以数值字段 `candidate_s_m` 为准；原始输出中的旧 `site_id` 字段保留了初筛时的标签，不用于 10、130、140、260 m 的位置识别。

## 主要文件

- `方法与结果说明.md`：行为变量、六类环境因子、实验方法、位置结果和推理边界。
- `model/`：GAMA 模型源文件及情景参数。
- `data/`：逐小时天气、OSM 树点和树荫代理区间。ERA5 是区域再分析，不是大学路现场微气候；OSM 树点不代表树冠边界。
- `results/gama_site_sweep_10m_2020-08-13.csv`：27 个链程位置的粗扫结果。
- `results/gama_site_sweep_shortlist_summary.csv`：两个高温日期各候选位置的 27 次/点情景均值。
- `results/gama_site_sweep_shortlist_2020-08-13.csv`、`results/gama_site_sweep_shortlist_2022-07-13.csv`：逐次 GAMA 输出整理表。
- `results/candidate_site_screen.csv`：候选点的链程、近似坐标与 OSM 树点距离。

## 解释限制

指标是简化的行人活动时间加权短波辐射暴露代理，不是 UTCI、PET、气温下降或人体热舒适预测。人群为 96 人合成 cohort；路线比例、短停意向和装置光学参数都是情景假设。模拟没有核验树冠、建筑反射、人行道净宽、地下管线、产权或现场客流。正式放置前要在 130–140 m 区间核对树荫、通行和施工条件。

数据来源及署名要求见 `方法与结果说明.md` 和 `data/input_metadata.json`；复用时保留 OpenStreetMap 与天气数据来源说明。
