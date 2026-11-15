# 建院交接文件清单

交接来源：建院组提供的大学路遮荫项目材料。清单中的哈希以收到的原文件计算；仓库相对路径不含个人电脑绝对路径。

| 原文件 | 仓库路径 | 字节数 | SHA-256 | 处理 |
|---|---|---:|---|---|
| `HeatWeave_Final.gh` | `source/HeatWeave_Final.gh` | 973,773 | `F8264A36FC113D183DC1B93A93D19C5B24A95553A121DEB942FB86576E6F6E05` | 原样复制 |
| `0614_1300_sum.csv` | 交付包内 `raw/project_original.csv` | 14,960,506 | `0FD72549C31BBD3F283B37201357E4CE8F7FEFC383B3AE8C4B99291084EC9FC3` | 不重复存储；与交付包内文件 SHA-256 一致 |
| `大学路遮荫数据_20261113_交付.zip` | `source/大学路遮荫数据_20261113_交付.zip.part001` 至 `.part004` | 19,098,769 | `954986FB275E3E0324FCE29C8C373345D0A0B7E45DDC7676616987D71CC72B0B` | 按原始字节分段保存；运行 `python reassemble_delivery_archive.py` 可重组并校验 |
| `Attune_知荫_汇报.zip` | 原包未入 Git；原交互预览见 `../preview/Attune_知荫_汇报/interactive/` | 344,281,594 | `DCEB7EACA06007166AD094E38B13EF53D7ACC4D92AEAD7B6B78DCC2F6443B08A` | 交互子目录原样解包并公开；完整汇报页和含可辨认行人的照片/视频留在本地完整解包副本，由 `.gitignore` 排除 |

辐射 CSV 的网格字段为 `grid_id, x, y, z, H_Wh_m2`。将其用于新方案前，仍需把坐标参考、单位、时间片与目标空间范围逐项写入数据字典。

原交接包没有随附开放许可文件。仓库保留来源归属，不据此宣称材料采用开放许可。

公开的交互预览文件及其 SHA-256 见 [`interactive_preview_manifest.csv`](interactive_preview_manifest.csv)。
