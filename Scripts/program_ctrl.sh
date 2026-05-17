until [ -d "/data/user/0/android" ];do sleep 30; done
function crtl_Colors_oiface(){
local flag="${1}"
if [ "$(getprop persist.sys.oiface.enable)" != "" ];then
	if [ "${flag}" = "enable_program" -o -f "${flag}/enable_program" ];then
		echo "- 启用oiface……"
		[ "$(pgrep -f oiface)" = "" ] && resetprop persist.sys.oiface.enable 2
		[ "$(pgrep -f oiface)" = "" ] && resetprop persist.sys.oiface.enable 1
		start oiface 2>/dev/null || setprop ctl.restart oiface 2>/dev/null
		[ "$(pgrep -f oiface)" != "" ] && echo -e "- oiface已启动……\n- `pgrep -lf oiface`"
	elif [ "${flag}" = "disable_program" -o -f "${flag}/disable_program" ];then
		resetprop persist.sys.oiface.enable 0 && echo "- 禁用oiface……"
		stop oiface 2>/dev/null || setprop ctl.stop oiface 2>/dev/null
	fi
fi
}

function crtl_miui_Joyose(){
local flag="${1}"
if [ "$(pm list package com.xiaomi.joyose)" != "" ];then
	if [ "${flag}" = "enable_program" -o -f "${flag}/enable_program" ];then
		echo "- 恢复Joyose……"
		pm enable com.xiaomi.joyose >/dev/null 2>&1
		pm enable com.xiaomi.joyose/.smartop.SmartOpService >/dev/null 2>&1
		#staging为测试服，russia为俄罗斯服，international为国际服，china为国服。
		am broadcast -a update_profile --es cloud_current_enviroment china -n com.miui.powerkeeper/com.miui.powerkeeper.cloudcontrol.CloudUpdateReceiver
		#staging为测试服，russia为俄罗斯服，international为国际服，official为国服。
		am broadcast -a update_profile --es profile_server official -n com.xiaomi.joyose/.cloud.CloudServerReceiver
	elif [ "${flag}" = "disable_program" -o -f "${flag}/disable_program" ];then
		echo "- 禁用Joyose……"
		pm disable com.xiaomi.joyose/.smartop.SmartOpService >/dev/null 2>&1
		pm clear com.xiaomi.joyose
	fi
fi
}

function crtl_vivo_gamewatch(){
local flag="${1}"
if [ "$(pm list package com.vivo.gamewatch)" != "" ];then
	if [ "${flag}" = "enable_program" -o -f "${flag}/enable_program" ];then
		pm enable com.vivo.gamewatch >/dev/null 2>&1
	elif [ "${flag}" = "disable_program" -o -f "${flag}/disable_program" ];then
		echo -e "- 嘻嘻😁？没有适配，我感觉这个是弊大于利的😃\n- 根据自己需求修改gamewatch吧！"
		#pm disable com.vivo.gamewatch
		#pm clear com.vivo.gamewatch
	fi
fi
}

[ ! -d "${MODPATH}" ] && Scripts_DIR="${0%/*}" && MODPATH="${Scripts_DIR%/*}"
Flags_Folder="${MODPATH}/Flags"
#创建文件/data/adb/modules/AppOpt_Aloazny/Flags/enable_program或者把 "$Flags_Folder" 改成 "enable_program"来启用。
#创建/data/adb/modules/AppOpt_Aloazny/Flags/disable_program
#或者把 "$Flags_Folder" 改成 disable_program
#来禁用
crtl_Colors_oiface "$Flags_Folder"
crtl_miui_Joyose "$Flags_Folder"
crtl_vivo_gamewatch "$Flags_Folder"



