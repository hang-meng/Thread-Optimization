### 蓝奏云下载地址(密码:1314)
- [点击转跳](https://wwbez.lanzouw.com/b01bjf7ufa)

### 注意
- [Github地址](https://github.com/hang-meng/Thread-Optimization)
- [查看适配应用列表](https://github.com/hang-meng/Thread-Optimization/blob/main/%E9%80%82%E9%85%8D%E5%BA%94%E7%94%A8.md)

### 更新日志
### **v1.0.2**
- **紧急修复**：v1.0.1 引入的同名线程 TID 索引语法（`{ThreadName[n]}`）在解析时未能区分 fnmatch 括号表达式（`[Rr]ender*`、`[Ww]orker*`、`[0-9]` 等），导致这些规则被整行丢弃，AppOpt 启动后无规则可用、进程自动退出。
- **错误提示简化**：action.sh 不再刷屏输出 `[W] 第X行无效TID索引` 日志，替换为一句话提示，日志详情仍可到文件查看。

### **30.5**
- **模块重命名**为「线程优化++」，作者 M_eang。
- **AppOpt 二进制全面重构**：
  - 修复 `proc_collect` 内存泄漏。
  - 新增前后台感知调度。
  - 核心分配架构自动适配重构（拓扑占位符方案）。
  - 合并重复 `sched_getaffinity` 调用。
  - 自适应轮询间隔。
  - 线程数据智能复用（~80% 扫描跳过）。
  - `tracked_pids` 改为 `uthash` 哈希表。
  - 移除 `-static`，二进制 ~45KB。
- **fix_applist_conf 性能优化**：sed 合并为 1 次调用。
- **同名线程 TID 索引**：`{ThreadName[n]}` 语法精确区分同名线程，例如 `{GameThread[0]}=6-7` 只绑第一个。
