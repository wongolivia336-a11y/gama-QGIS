# 建院交接原项目

本目录保存交接原件和原始浏览器预览。源文件不在此处改写；我们组的新设计另见 `../02_我们组最终原型/`。

## 原型内容

- `source/HeatWeave_Final.gh`：Rhino/Grasshopper 参数化模型文件，可在安装对应 Rhino 与 Grasshopper 的电脑中打开和重算。
- `source/大学路遮荫数据_20261113_交付.zip.part001` 至 `.part004`：交付 ZIP 的原始字节分段。压缩包内 `raw/project_original.csv` 与单独交接的 `0614_1300_sum.csv` 完全相同。
- `source/reassemble_delivery_archive.py`：重组并校验交付 ZIP 的脚本。
- `preview/index.html`：公开预览入口。
- `preview/Attune_知荫_汇报/interactive/index.html`：原 Three.js 交互预览，代码与模型数据由交接 ZIP 原样解出。

交互预览文件的校验清单见 [`source/interactive_preview_manifest.csv`](source/interactive_preview_manifest.csv)。完整交接压缩包还含有可辨认行人的照片/视频；其本地解包副本保留在此工作区，但由仓库 `.gitignore` 排除，不发布到 GitHub。

## 本地打开

克隆仓库后，如需恢复原始数据 ZIP，在本目录执行：

```powershell
python source/reassemble_delivery_archive.py
```

脚本会在 `source/` 中生成原始 ZIP，并核对清单中的 SHA-256。解压后可在 `raw/project_original.csv` 找到单独交接的 CSV。

从仓库根目录启动：

```powershell
python -m http.server 8766 --bind 127.0.0.1
```

浏览器访问：

- 公开预览入口：`http://127.0.0.1:8766/02_大学路遮荫/01_建院交接原项目/preview/`
- 交互模型：`http://127.0.0.1:8766/02_大学路遮荫/01_建院交接原项目/preview/Attune_知荫_汇报/interactive/`

本预览是静态 HTML/CSS/JavaScript 页面，三维部分使用 Three.js/WebGL 并加载随包模型数据。页面展示打包好的数据与交互规则；不连接真实相机、传感器或电机。Grasshopper 文件需要 Rhino/Grasshopper 环境，GitHub Pages 不会运行 `.gh`。

## 来源、完整性与使用范围

文件来源、字节数和 SHA-256 见 [`source/manifest.md`](source/manifest.md)。Attune 压缩包原件为 344 MB，单个文件超过 GitHub 普通 Git 的 100 MiB 上限；公开仓库保留原 Three.js 交互页所需文件，完整报告页及人物影像/视频保留在本地解包副本并由 `.gitignore` 排除。交接资料没有附开放许可文件，后续引用、展示和再分发遵循交接方约定并保留归属。
