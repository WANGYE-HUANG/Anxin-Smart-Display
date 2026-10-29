# 安芯智显多媒体终端——完整工程代码提交包

## 1. 版本与目录

本包对应已上板验收并由参赛者完成 Flash 固化、断电重启验证的 av_slide 版本。综合源码及 bitstream 与 2026-10-26 冻结版逐文件 SHA-256 一致；本次仅整理提交材料，没有修改逻辑或重新生成烧录文件。

- 器件：安路 EG4S20BG256；顶层：av_slide。
- 工具：Tang Dynasty 6.2.1（报告版本 V6.2.168116）。
- 板卡：DMZ-EG4S20 核心板及配套综合底板；SDRAM 为器件内部合封 2M×32 bit。
- 视频输出：800×600，约 60 Hz；音频：48 kHz、16 bit、双声道 PCM。

| 目录/文件 | 内容 |
|---|---|
| src/ | 最终综合所需全部 HDL、字体头文件、引脚约束、时序约束及原始构建脚本 |
| simulation/ | 测试平台、SDRAM 模型、参考数据及冻结时的仿真日志 |
| bitstream/av_slide.bit | 已验证的发布烧录文件 |
| reports/ | 最终布局布线资源、静态时序原始报告 |
| media/ | 两张校园海报及 24 秒晓晓纯人声，可复制到 TF 卡根目录 |
| build.ps1 | 在新建构建目录内运行 TD 原始构建流程，不覆盖发布 bit |
| verify_files.ps1、SHA256SUMS.txt | 逐文件完整性校验 |
| VERSION.json | 发布版本、固件摘要及素材参数 |

只提交最终版本及其复现依赖；不混入历史 bringup 工程、工具安装包或许可证文件。

## 2. 解压与编译

推荐解压到简短英文路径，例如 D:/fpga/Anxin_Display_av_slide。请勿在压缩包内部运行程序。

已安装 TD 6.2.1 的电脑上，在包根目录打开 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_files.ps1
powershell -ExecutionPolicy Bypass -File .\build.ps1 -TdExe 'D:/anlu TD/TD/bin/td_commands_prompt.exe'
```

安装路径不同，只修改 -TdExe 参数。构建脚本自动创建 build_时间戳 目录，复制 src 中全部依赖后执行原始 build.tcl。原始脚本按 import_device、read_hdl、read_adc、综合、布局布线、保持时间修复、最终时序分析、bitgen 顺序运行；建立或保持裕量小于 0 时终止发布。正常输出 av_slide.bit、av_area.rpt、av_timing.rpt。

也可在 TD 命令环境中切换到 src 的工作副本后执行 source build.tcl。build.tcl 是本工程的完整可复现入口，不依赖历史电脑的 GUI 工程文件。创建 GUI 工程时设置 EG4S20BG256、顶层 av_slide，按 build.tcl 的 read_hdl 清单加入文件，再加入 pins.adc 与 timing.sdc；不把 simulation 测试文件加入综合。

## 3. 外部 IP 与仿真依赖

hdmi_core.enc.v 是配套资料提供的加密 HDMI IP，原样保留；HDMI PHY、串化及 PLL 配套文件也已包含，保留原作者标识。加密模块没有可提供的明文，不将其声明为队伍原创。器件原语仿真库由合法安装的 TD 提供，不打包整个厂商安装目录或许可证。

仿真使用 ModelSim，测试目录需能访问 src 内的 RTL 与 info_font.vh，并以 simulation 为工作目录读取 .hex 参考数据。先编译 TD 的 EG4 仿真原语为 eg_lib，再编译 build.tcl 所列 RTL、sdram_model.v 以及所需测试平台。tb_slide_hdmi 和 tb_800_hdmi 需要同编译，后者包含共用参考模块；tb_800_info_reference.vh 位于 simulation。

主要测试入口：tb_slide_scan、tb_slide_timing、tb_slide_keys、tb_slide_policy、tb_slide_hdmi、tb_800_hdmi、tb_800_transport、tb_800_rate、tb_800_bcd、tb_800_system、tb_800_scaler。默认参数所需数据已包含，其他 PROFILE 参考数据也已补齐。用 run -all 运行；使用 HDMI/器件原语时加 -L eg_lib，tb_slide_policy 须同时加载 eg_lib.glbl。具体原始仿真命令及 PASS 结果见 sim_*.log。

仿真日志及资源时序报告是冻结时的真实记录；本次打包仅核对源码、固件和归档一致性，不把它表述为重新运行全套仿真或新增长时间实物测试。

## 4. TF 卡与上板

使用 FAT32 TF 卡，先将 media 内 TEST.BMP、ALT.BMP、AUDIO.WAV 三个文件复制到卡根目录，文件名保持不变。替换素材不需要重新生成 bit。当前海报均为 640×480、24 位未压缩 BMP；音频为标准 44 字节 WAV 头、48 kHz/16 bit/双声道 PCM。

卡采用 SPI 读取，解析 FAT32 目录与簇链；支持 MBR 首个 FAT32 主分区或从扇区 0 开始的直接 FAT32 卷。不是对任意分区/文件系统的支持，不使用 exFAT、NTFS 或 GPT。更换 TF 卡先断电。

视频连接：开发板 HDMI → MS2130S 采集卡 → 电脑 USB → OBS；电脑只负责供电、采集和显示。也可接兼容 HDMI 显示设备。核心板 USB 用于 FPGA 下载/供电，底板 DAP Link 不是核心 FPGA 下载口。

BitWriter 中选择 EG4S20BG256 和 bitstream/av_slide.bit。可先 Program SRAM、JTAG 5 MHz 验证，再依照所用核心板实际 Flash 型号和容量进行 Flash 固化。该包不自动执行烧录、不猜测 Flash 容量。正常运行 D0 闪烁、D6 灭、D7 亮。

## 5. 按键

- KEY0：音画暂停/继续；手动选页后从所选画面的对应音频段播放。
- KEY1：从第一页及音频起点重播。
- KEY2：打开/关闭应急文字覆盖；KEY3：按住查看诊断灯号。
- KEY4/KEY5：前/后选页并进入手动暂停；KEY6：恢复自动播放。
- KEY7：切换 WAV 与左 1 kHz、右 2 kHz 测试音。
- KEY8/KEY9：降低/提高亮度；KEY10/KEY11：降低/提高对比度；KEY12：恢复两项默认值。
- KEY13：切换向上滑动与淡入淡出转场。

## 6. 关键结果与边界

归档最终报告：LUT 15067、寄存器 7050、BRAM9K 36、DSP 23、PLL 1；建立最差裕量 0.187 ns、保持最差裕量 0.030 ns。具体以 reports 原始报告为准。

实现图片等比例适配、双线性缩放、两图自动/手动切换、音画控制、中文滚动字幕、应急覆盖、亮度/对比度调节、实际 PCM 波形及两种转场。图片输入尺寸与固定 HDMI 输出分辨率是不同概念；不宣称通用视频解码、FFT 频谱或联网功能。扩展尺寸上板测试的范围见技术文档，不能由当前示例素材推定所有格式都支持。
