### 蓝奏云下载地址(密码:111)
- [点击转跳](https://aloazny.lanzouo.com/b00je9nu1i)
- [1.3.5版本](https://aloazny.lanzouo.com/b00jeipeeb)
- [实时模式](https://aloazny.lanzouo.com/b00jeku6cd)
- [Ebpf版本(测试)](https://aloazny.lanzouv.com/b00jf0lz0h)
- [小飞机盘](https://share.feijipan.com/s/AN2lFUeN)

### 注意
- [Github地址](https://github.com/Aloazny/AppOpt_Aloazny)
- [查看适配应用列表](https://aloazny.github.io/AppOpt_Aloazny/#%E9%80%82%E9%85%8D%E5%88%97%E8%A1%A8)
- [查看Flags文件说明](https://aloazny.github.io/AppOpt_Aloazny/#%E6%8F%90%E7%A4%BA)

### 更新日志
### **30.3**
- 修复`Get_mem_val`函数一个bug。
- 调整**dex2oat优化值**。
#### **30.2**
- 调整`6+2`高性能核心，日用应用`RenderThread`使用`4-5`大核，`*.ui`和`*.raster`使用大核簇+超大核簇，减少固定使用超大核带来的功耗开销。
- 调整`2+3+2+1`的日用应用`RenderThread`使用`2-4`大核心，如果感到卡顿，可以退回上个版本。
- `Aloazny.sh`脚本利用`Get_mem_val`函数获取内存信息，减少对`awk`依赖。