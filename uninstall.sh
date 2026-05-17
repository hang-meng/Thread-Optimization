wait_for_system_reboot(){
local number=3
until [ "$(getprop sys.boot_completed)" = "1" ] || [ "$number" -le "0" ]
do
	number=$((number-1))
	sleep 60
done
}

wait_for_screen_on(){
local number=3
until [ "$(dumpsys deviceidle get screen 2>/dev/null )" = "true" ] || [ "${number}" -le "0" ] && [ -d "/data/user/0/android" ]
do
	number=$((number-1))
	sleep 60
done
}

uninstall_module(){
wait_for_system_reboot
if [ "$(pgrep -f oiface)" = "" ];then
	if [ -n "$(getprop persist.sys.oiface.enable)" ]; then
		prop_value=$(grep -E '^persist\.sys\.oiface\.enable=' /system_ext/etc/build.prop | cut -d= -f2)
  	  if [ -n "$prop_value" ]; then
		 	resetprop persist.sys.oiface.enable "$prop_value"
		else
			resetprop persist.sys.oiface.enable 2
		fi
	fi
fi
wait_for_screen_on
if [ "$(pm list package com.xiaomi.joyose)" != "" ] ;then
	pm enable com.xiaomi.joyose >/dev/null 2>&1
	pm enable com.xiaomi.joyose/.smartop.SmartOpService >/dev/null 2>&1
	#staging为测试服，russia为俄罗斯服，international为国际服，china为国服。
	am broadcast -a update_profile --es cloud_current_enviroment china -n com.miui.powerkeeper/com.miui.powerkeeper.cloudcontrol.CloudUpdateReceiver
	#staging为测试服，russia为俄罗斯服，international为国际服，official为国服。
	am broadcast -a update_profile --es profile_server official -n com.xiaomi.joyose/.cloud.CloudServerReceiver
fi
}

#给Kernel SU？？？？？？真服了，卸载模块到底有没有标准？
Scripts_DIR="${0%/*}"
if [ -n "$(echo "$Scripts_DIR" | cut -d/ -f5)" ] && [ -n "$(echo "$Scripts_DIR" | grep '/data/adb/modules/' )" ] ;then
	MODULE_DIR="$Scripts_DIR"
else
	MODULE_DIR="/data/adb/modules/AppOpt_Aloazny"
fi
if [ -f "$MODULE_DIR/remove" ] ;then
	rm -rf "$MODULE_DIR" "${MODULE_DIR/modules/modules_update}"
fi
#修复MT管理器26040453版本的卸载bug，其他MT管理器版本没这问题
#这个版本没法后台运行卸载脚本，只能前台
if [ -d "/data/user/0/android" ] && [ "$(getprop sys.boot_completed)" = "1" ] && [ "$(dumpsys deviceidle get screen 2>/dev/null )" = "true" ]; then
	uninstall_module
else
	(uninstall_module &)
fi
