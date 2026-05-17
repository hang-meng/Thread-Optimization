# 线程优化++

基于 [AppOpt](https://gitee.com/sutoliu/AppOpt)（[Aloazny 二改版](https://aloazny.github.io/AppOpt_Aloazny/)）再改的 Magisk 模块，用于 Android 应用线程 CPU 亲和性调度优化。

## 简介

通过自定义规则将应用关键线程绑定到指定 CPU 核心，实现性能提升与功耗优化。支持通配符匹配、优先级排序、前后台感知调度，自动适配多种 CPU 架构（`4+4`、`6+2`、`3+4+1`、`2+3+2+1` 等）。

## 特性

- **线程级CPU亲和性**：精确控制应用线程绑核策略
- **前后台感知**：自动识别前后台进程，后台限入小核簇
- **自适应轮询**：空闲时自动降低扫描频率，减少 CPU 开销
- **智能数据复用**：同 PID 线程数未变时跳过 I/O，~80% 扫描可跳过
- **架构自动适配**：拓扑占位符方案，适配任意 CPU 架构无需改脚本
- **通配符 & 优先级**：进程名支持通配符，线程名支持精确优先匹配
- **二进制轻量化**：动态链接编译，体积 ~45KB（原 2.4MB）

## 安装

1. 安装 [Magisk](https://github.com/topjohnwu/Magisk) / [KernelSU](https://github.com/tiann/KernelSU) / [APatch](https://github.com/bmax121/APatch)
2. 下载模块压缩包刷入
3. 重启设备

## Flags 配置

所有 Flags 文件位于 `/data/adb/modules/Thread-Optimization/Flags/`，创建或删除后需重新刷入模块生效。

| Flags 文件 | 作用 | 默认 |
|---|---|---|
| `modtify_config` | 机械性适配不同 CPU 核心配置 | 开启 |
| `update_config` | 强制使用模块自带规则覆盖用户修改 | 开启 |
| `keep_custom_rule` | 增量更新，保留用户自定义规则 | 关闭 |
| `delete_game_config` | 删除模块自带的所有游戏配置 | 关闭 |
| `keep_Asoulopt` | 删除与 AsoulOpt 冲突的规则 | 关闭 |
| `dexota_modtify` | 开启 dex2oat 编译优化 | 关闭 |
| `disable_program` | 禁用冲突的系统进程 | 关闭 |
| `enable_program` | 启用被禁用的系统进程 | 关闭 |
| `zip_first` | 优先使用压缩包内 Flags（仅在压缩包内创建） | 关闭 |

详细说明见 [`文档/Flags文件说明.md`](文档/Flags文件说明.md)。

## 适配应用

已适配 500+ 应用与游戏，覆盖：
- 系统进程（`surfaceflinger`、`system_server` 等）
- MIUI / ColorOS / MyOS 系统应用
- 主流游戏（原神、王者荣耀、和平精英、崩坏、绝区零等 140+ 游戏）
- 日常应用（微信、QQ、抖音、淘宝、浏览器等 300+ 应用）

完整列表见 [`适配应用.md`](适配应用.md)。

## 自定义规则

编辑模块目录下的 `applist.prop`，格式：

```
com.example.app{Thread-1}=4-6
com.example.app{RenderThread}=7
com.example.*{Thread-*}=0-3
```

每行一个规则，修改后重启 AppOpt（执行模块 Action 按钮）即可生效。

## 感谢

- [AppOpt](https://gitee.com/sutoliu/AppOpt) - 原作 [@SutoLiu](https://www.coolapk1s.com/u/SutoLiu) (GPLv3)
- [AppOpt_Aloazny](https://aloazny.github.io/AppOpt_Aloazny/) - Aloazny 二改版
- [uthash](https://troydhanson.github.io/uthash/) - 哈希表库 (BSD)

## 协议

[GPLv3](LICENSE)
