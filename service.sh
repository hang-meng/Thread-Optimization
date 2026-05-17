wait_sys_boot_completed() {
	local i=9
	until [ "$(getprop sys.boot_completed)" == "1" ] || [ $i -le 0 ]; do
		i=$((i-1))
		sleep 25
	done
}

wait_sys_boot_completed


if [ -d "/data/adb/modules/AppOpt" ] && [ ! -f "/data/adb/modules/AppOpt/disable" ];then
    echo "
    - 您已选择 Suto 大佬的模块，该模块不会运行！
    "
    exit 0
fi


#杀死上次运行的程序
killall -15 AppOpt >/dev/null 2>&1
#检查AppOpt
[ ! -f "${0%/*}/AppOpt" ] && echo "- 嘿？！他娘的！我徒弟呢？"
#尝试修复开机不自动执行
cd "${0%/*}"
chmod -R a+x "${0%/*}/AppOpt" "${0%/*}/Scripts" 2>/dev/null
#配置文件路径
module_config="${0%/*}/applist.prop"
[ -f "${0%/*}/applist.conf" ] && module_config="${0%/*}/applist.conf"
#简单日志
log_file="${0%/*}/affinity_manager.log"
: > "${log_file}"
#启动AppOpt
nohup "${0%/*}/AppOpt" -c "${module_config}" >> "${log_file}" 2>&1 &
#控制服务脚本
for script in "${0%/*}/Scripts"/*.sh
do
	nohup "$script" >/dev/null 2>&1 &
done
