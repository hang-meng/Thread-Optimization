[ -f /data/adb/magisk/util_functions.sh ] && . /data/adb/magisk/util_functions.sh
[ ! -d "${MODPATH}" ] && MODPATH="${0%/*}"
export PATH="${PATH}:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"
export TZ="Asia/Shanghai"
if command -v busybox >/dev/null 2>&1; then
    awk() { busybox awk "$@"; }
    sed() { busybox sed "$@"; }
    diff() { busybox diff "$@"; }
fi
ui_print "" >/dev/null 2>&1 || ui_print(){ local msg; [ -z "$BOOTMODE" ] && { if ps|grep zygote|grep -qv grep||ps -A 2>/dev/null|grep zygote|grep -qv grep; then BOOTMODE=true; else BOOTMODE=false; fi; }; if $BOOTMODE; then echo "$@"; else [ -z "$OUTFD" ] && { local fd; for fd in $(ls /proc/self/fd 2>/dev/null); do if readlink /proc/self/fd/$fd 2>/dev/null|grep -q pipe; then if ps 2>/dev/null|grep -v grep|grep -qE " 3 $fd |status_fd=$fd"; then OUTFD=$fd; break; fi; fi; done; [ -z "$OUTFD" ] && OUTFD=2; }; for msg in "$@"; do echo -e "ui_print $msg\nui_print" >> "/proc/self/fd/$OUTFD"; done; fi; }
grep_prop >/dev/null 2>&1 || grep_prop() { local REGEX="s/^$1=//p"; shift ;local FILES="${@}"; [ -z "$FILES" ] && FILES='/system/build.prop'; cat "${FILES}" 2>/dev/null | dos2unix | sed -n "${REGEX}" | head -n 1; }

#定义模块安装目录
CUSTOM_PROGRAM="AppOpt"
MY_MODULE_FOLDER="/data/adb/modules/Thread-Optimization"
#定义检查函数全局提示变量
Last_Check_Tips=""

function cpu_name_get(){
local cpuname="$(getprop ro.soc.model)"
[ "${cpuname}" = "" ] && cpuname="$(getprop | sed -E "/ro\.(system|vendor|product|odm|system_ext).*\.soc_model/!d;s/.*\]://g;s/\].*//g;s/.*\[//g" | head -n 1)"
[ "${cpuname}" = "" ] && cpuname="$(getprop ro.board.platform)"
[ "${cpuname}" = "" ] && cpuname="$(getprop | sed -E "/ro\.(system|vendor|product|odm|system_ext).*\.platform/!d;s/.*\]://g;s/\].*//g;s/.*\[//g" | head -n 1)"
[ "${cpuname}" != "" ] && echo "${cpuname}" || echo "未知"
}

function get_cpu_core_Info(){
mid_count=0
idx=0
for dir in /sys/devices/system/cpu/cpufreq/policy*; do
	[ -f "${dir}/cpuinfo_max_freq" ] || continue
	freq_khz=$(cat "${dir}/cpuinfo_max_freq")
	freq_mhz=$(( freq_khz / 1000 ))
	related=$(cat "${dir}/related_cpus")
	set -- $related
	count=$#
	first=$1
	eval last=\${$#}
	if [ $count -eq 1 ]; then
		range="$1"
	else
		range="${first}-${last}"
	fi
	eval "pol_freq_$idx=\$freq_mhz"
	eval "pol_count_$idx=\$count"
	eval "pol_range_$idx=\$range"
	eval "pol_num_$idx=\${dir##*policy}"
	idx=$((idx+1))
done
num_pol=$idx
if [ $num_pol -eq 0 ]; then
	echo -e "**************************************************"
	echo -e "- CPU代号: $(cpu_name_get)"
	echo -e "- 核心信息: 无"
	echo -e "**************************************************"
	echo -e ""
	return
fi
i=0
while [ $i -lt $num_pol ]; do
	eval "order_$i=\$i"
	i=$((i+1))
done
i=0
while [ $i -lt $((num_pol-1)) ]; do
	min_idx=$i
	j=$((i+1))
	while [ $j -lt $num_pol ]; do
		eval "val_order_j=\$order_$j"
		eval "val_order_min=\$order_$min_idx"
		eval "val_j_freq=\$pol_freq_$val_order_j"
		eval "val_min_freq=\$pol_freq_$val_order_min"
		if [ $val_j_freq -lt $val_min_freq ]; then
			min_idx=$j
		fi
		j=$((j+1))
	done
	if [ $min_idx -ne $i ]; then
		eval "tmp=\$order_$i"
		eval "order_$i=\$order_$min_idx"
		eval "order_$min_idx=\$tmp"
	fi
	i=$((i+1))
done
min_num=999999
max_num=-1
i=0
while [ $i -lt $num_pol ]; do
	eval "num=\$pol_num_$i"
	[ $num -lt $min_num ] && min_num=$num
	[ $num -gt $max_num ] && max_num=$num
	i=$((i+1))
done
if [ $num_pol -eq 1 ]; then
	eval "pol_label_0=\"核心\""
elif [ $num_pol -eq 2 ]; then
	idx0=-1; idxX=-1
	i=0
	while [ $i -lt $num_pol ]; do
		eval "num=\$pol_num_$i"
		if [ "$num" = "$min_num" ]; then
			idx0=$i
		else
			idxX=$i
		fi
		i=$((i+1))
	done
	eval "freq0=\$pol_freq_$idx0"
	if [ $freq0 -ge 3000 ]; then
		eval "pol_label_$idx0=\"大核\""
		eval "pol_label_$idxX=\"超大核\""
	else
		eval "pol_label_$idx0=\"小核\""
		eval "pol_label_$idxX=\"大核\""
	fi
else
	i=0
	while [ $i -lt $num_pol ]; do
		eval "pol_label_$i=\"\""
		i=$((i+1))
	done
	i=0
	while [ $i -lt $num_pol ]; do
		eval "num=\$pol_num_$i"
		if [ "$num" = "$min_num" ]; then
			eval "pol_label_$i=\"小核\""
		elif [ "$num" = "$max_num" ]; then
			eval "pol_label_$i=\"超大核\""
		fi
		i=$((i+1))
	done
	mid_count=0
	i=0
	while [ $i -lt $num_pol ]; do
		eval "lab=\$pol_label_$i"
		if [ -z "$lab" ]; then
			eval "middle_indices_$mid_count=\$i"
			mid_count=$((mid_count+1))
		fi
		i=$((i+1))
	done
	if [ $mid_count -eq 1 ]; then
		eval "idx_m=\$middle_indices_0"
		eval "pol_label_$idx_m=\"大核\""
	else
		max_freq=-1
		max_freq_idx=-1
		j=0
		while [ $j -lt $mid_count ]; do
			eval "idx_mid=\$middle_indices_$j"
			eval "freq_mid=\$pol_freq_$idx_mid"
			if [ $freq_mid -gt $max_freq ]; then
				max_freq=$freq_mid
				max_freq_idx=$idx_mid
			fi
			j=$((j+1))
		done
		j=0
		while [ $j -lt $mid_count ]; do
			eval "idx_mid=\$middle_indices_$j"
			if [ $idx_mid -eq $max_freq_idx ]; then
				eval "pol_label_$idx_mid=\"大核\""
			else
				eval "pol_label_$idx_mid=\"降频大核\""
			fi
			j=$((j+1))
		done
	fi
fi
arch=""
total=0
i=0
while [ $i -lt $num_pol ]; do
	eval "idx=\$order_$i"
	eval "c=\$pol_count_$idx"
	eval "lab=\$pol_label_$idx"
	total=$(( total + c ))
	if [ -z "$arch" ]; then
		arch="${c}${lab}"
	else
		arch="${arch}+${c}${lab}"
	fi
	i=$((i+1))
done
core_architect="核心配置为: ${arch} 共${total}个CPU核心"
echo -e "**************************************************"
echo -e "- CPU代号: $(cpu_name_get)"
echo -e "- 核心信息:"
echo -e "- ${core_architect} "
i=0
while [ $i -lt $num_pol ]; do
	eval "idx=\$order_$i"
	eval "c=\$pol_count_$idx"
	eval "r=\$pol_range_$idx"
	eval "f=\$pol_freq_$idx"
	printf "      %d Core (%s) cpuinfo_max_freq: %d MHz\n" "$c" "$r" "$f"
	i=$((i+1))
done
echo -e "**************************************************"
echo -e ""
i=0
while [ $i -lt $num_pol ]; do
	eval "unset pol_freq_$i pol_count_$i pol_range_$i pol_num_$i pol_label_$i order_$i 2>/dev/null"
	i=$((i+1))
done
j=0
while [ $j -lt $mid_count ]; do
	eval "unset middle_indices_$j 2>/dev/null"
	j=$((j+1))
done
}

function check_program_Running(){
local check_program=`pgrep -lf "$CUSTOM_PROGRAM|CuDaemon|uperf" | sed -E 's/^(.*)/- \1/g' `
local check_program_count=`echo "${check_program}" | wc -l`
if [ "${check_program_count}" -gt "1" ];then
echo "
- 注意
- 可能有其他相同程序影响模块运行
${check_program}
"
fi
}

function get_other_module(){
for i in /data/adb/*modules/asoul_affinity_opt /data/adb/*modules/Thread-Optimization /data/adb/*modules/AppOpt /data/adb/*modules/thread_opt
do
	description_file="${i}/module.prop"
	if [ -f "${description_file}" ] && [ ! -f "${i}/disable" ];then
		if [ -f "${TMPDIR}/module.prop" ];then
			module_own_id=$(grep_prop id "${TMPDIR}/module.prop" )
		else
			module_own_id=`readlink -f "${0%/*}"`
			module_own_id="${module_own_id##*/}"
		fi
	module_id=$(grep_prop id "${description_file}" )
	[ "${module_own_id}" = "${module_id}" ] && continue
	[ "${module_id}" = "asoul_affinity_opt" -a -f "${MODPATH}/Flags/delete_game_config" ] && continue
	module_name=$(grep_prop name "${description_file}" )
	module_author=$(grep_prop author "${description_file}" )
	module_description=$(grep_prop description "${description_file}" )
	ui_print "
- 名称:${module_name}
- 作者:${module_author}
- 描述:${module_description}
- 路径:${i}"
	fi
done
}


function write_core_information(){
local module_config="${1}"
[ ! -f "${module_config}" ] && return 
local core_content="$(echo "$(get_cpu_core_Info)" | sed -E 's/^(.*)/#\1/g' )"
sed -E -i '/^\#[[:space:]]您的核心信息/,/^\#[[:space:]]END/d' "${module_config}"
local module_config_content="$(cat "${module_config}")"
cat << Aloazny > "${module_config}"
# 您的核心信息
${core_content}
# END
${module_config_content}
Aloazny
}

function write_cpu_information_to_module_description(){
local file="${MODPATH}/module.prop"
local Device_Name update_sate modtify_sate dexota_sate game_config_sate dynamic_update_sate
[ ! -f "$file" ] && return
local bin_file="${MODPATH}/${CUSTOM_PROGRAM}"
[ -f "${bin_file}" ] && chmod 755 "${bin_file}" || return
local architect=$(out=; for f in /sys/devices/system/cpu/cpufreq/*/related_cpus; do [ -f "$f" ] || continue; read -r cpus < "$f"; count=0; for token in $(echo "$cpus" | tr ',' ' '); do case $token in *-*) count=$((count + ${token#*-} - ${token%-*} + 1)) ;; *) count=$((count + 1)) ;; esac; done; out="${out}+${count}"; done; echo "${out#+}")
[ "${architect}" = "" ] && architect="未知"
if test "`getprop ro.vendor.oplus.market.name`" != "" ;then
	Device_Name="$(getprop ro.vendor.oplus.market.name)"
elif test "`getprop ro.product.marketname`" != "" ;then
	Device_Name="$(getprop ro.product.marketname)"
else
	Device_Name="$(getprop ro.product.model)"
fi
[ "${Device_Name}" = "" ] && Device_Name="未知"
[ -f "${MODPATH}/Flags/update_config" ] && update_sate="[ 始终覆盖配置文件: ✅ ]" || update_sate="[ 始终覆盖配置文件: ❎️ ]"
[ -f "${MODPATH}/Flags/modtify_config" -o "${architect}" = "4+3+1" ] && modtify_sate="[ 机械性适配: ✅ ]" || modtify_sate="[ 机械性适配: ❎️ ]"
[ -f "${MODPATH}/Flags/dexota_modtify" -a "$(grep 'pm.dexopt.cmdline=' "${MODPATH}/system.prop" 2>/dev/null )" != "" ] && dexota_sate="[ 优化dex2oat: ✅ ]" || dexota_sate="[ 优化dex2oat: ❎️ ]"
[ -f "${MODPATH}/Flags/delete_game_config" ] && game_config_sate="[ 保留游戏配置: ❎️ ]" || game_config_sate="[ 保留游戏配置: ✅ ]"
[ -f "${MODPATH}/Flags/keep_custom_rule" ] && dynamic_update_sate="[ 增量更新: ✅ ]" || dynamic_update_sate="[ 增量更新: ❎️ ]"
local Appopt_version=`${bin_file} -v`
local word="设备: ${Device_Name}，当前处理器: [ $(cpu_name_get) ] (${architect})，模块配置情况: ${update_sate} ${modtify_sate} ${dexota_sate} ${game_config_sate} ${dynamic_update_sate}，一个支持自定义规则的安卓应用线程优化程序，基于Suto大佬的$Appopt_version二改。"
sed -i "/description=/d" "${file}"
echo -e "description=${word}" >> "${file}"
sed -i "/^[[:space:]]*$/d" "${file}"
}

#再次抄袭10007代码
#获取magisk类型
function get_magisk_lite(){
local until_function=/data/adb/magisk/util_functions.sh
local Apatch_version=${APATCH_VER_CODE}
local Ksu_version=${KSU_KERNEL_VER_CODE}
if [ "${Apatch_version}" != "" ];then
	echo "- 😥当前环境非Magisk……"
	echo "- 疑似Apatch◎${Apatch_version}……"
	return
elif [ "${Ksu_version}" != "" ];then
	echo "- 😥当前环境非Magisk……"
	echo "- 疑似kernelsu◎${Ksu_version}……"
	return
fi
if grep -q lite_modules $until_function >/dev/null 2>&1 ;then
	echo "- 🌙当前为: Magisk Lite◎$MAGISK_VER_CODE"
else
	if [ "${MAGISK_VER_CODE}" = "" ];then
		echo "- 🤔当前环境非Magisk/Ksu/Apatch……"
	else
case "${MAGISK_VER}" in
*alpha)
	echo "- ☀当前为: Magisk Alpha◎$MAGISK_VER_CODE"
;;
*delta)
	echo "- ☀当前为: Magisk Delta◎$MAGISK_VER_CODE"
;;
*kitsune)
	local magisk_type="${MAGISK_VER%-*}"
	if [ -n $(echo "${magisk_type}" | grep -E '[0-9]{2}\.[0-9]') ] ;then
		echo "- ☀当前为: Kitsune Mask◎$MAGISK_VER_CODE"
	else
		echo "- ☀当前为: Kitsune Mask(${magisk_type})◎$MAGISK_VER_CODE"
	fi
;;
*-*)
	local magisk_others="$(echo "${MAGISK_VER##*-}" | tr '[:lower:]' '[:upper:]')"
	echo "- ☀当前为: Magisk ${magisk_others}◎$MAGISK_VER_CODE"
;;
*)
	echo "- ☀当前为: Magisk Official◎$MAGISK_VER_CODE"
;;
esac
	fi
fi
}

#检查Ebpf
function Check_shell_status() {
local check="$1"
local target="$2"
local Tips="${3}"
[ -n "$TOTAL_COUNT" ] && TOTAL_COUNT=$((TOTAL_COUNT + 1))
if [ "$check" -eq 0 ]; then
	[ -n "$SUCCESS_COUNT" ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
	echo -e "- ✅ $target"
else
	if [ -n "${Tips}" -a "${Tips}" != "${Last_Check_Tips}" ]; then
		echo -e "- ❌ $target \n- ${Tips}"
		Last_Check_Tips="${Tips}"
	else
		echo -e "- ❌ $target "
	fi
fi
}

function Check_Ebpf_support() {
local SUCCESS_COUNT=0
local TOTAL_COUNT=0
local Kernel_ver=$(uname -r | cut -d. -f1,2 )
local big_ver="${Kernel_ver%.*}"
local lite_ver="${Kernel_ver##*.}"
local Kernel_configs_file="/proc/config.gz"
local BTF_file_count=`find /sys/fs/bpf /sys/kernel/bpf /sys/kernel/btf/vmlinux -maxdepth 0 2>/dev/null`
local Kernel_configs="
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_HAVE_EBPF_JIT=y
CONFIG_BPF_EVENTS=y
CONFIG_FTRACE=y
CONFIG_TRACEPOINTS=y
CONFIG_PERF_EVENTS=y
#预检测，现在用不到
#CONFIG_KPROBE_EVENTS=y
#CONFIG_DEBUG_INFO_BTF=y
"

echo -e "\n- 📋Ebpf支持检测……"
[ "$big_ver" -gt "5" ] || [ "$big_ver" -eq "5" -a "$lite_ver" -ge "20" ]
Check_shell_status $? "内核版本检测: $(uname -r)" "💬内核版本5.20以后对Ebpf逐渐支持完整，5.4+之后大部分都支持……"
#已经绕过BTF(Vmlinux)
#[ "$(echo $BTF_file_count | wc -l )" -gt "1" ]
#Check_shell_status $? "内核文件: `echo ${BTF_file_count} | tr '\n' ' '` " "💬没有vmlinux(BTF)可能无法启动Ebpf来Hook……"
mount | grep -q 'type bpf'
Check_shell_status $? "bpf目录已挂载" "💬连bpf目录都不挂载，大概率跑不起来……"
[ ! -f "${Kernel_configs_file}" ] && return
for cfg in $Kernel_configs
do
	echo "$cfg" | grep -q "^#" && continue
	zcat "${Kernel_configs_file}" | grep -q "^$cfg"
	Check_shell_status $? "内核配置开关: $cfg" "💬内核不开启也可能没办法使用Ebpf……"
done
	if [ "$TOTAL_COUNT" -gt 0 ]; then
	local percent=$((SUCCESS_COUNT * 100 / TOTAL_COUNT))
		echo -e "\n-----------------------------------"
		echo -e "- 检测完成: 共 ${TOTAL_COUNT} 项"
		echo -e "- 通过项数: ${SUCCESS_COUNT}"
		echo -e "- 运行成功率: ${percent}%"
		echo -e "-----------------------------------\n"
	fi
unset Last_Check_Tips
}

function Move_platform_bin(){
local platform="${ABI}"
[ ! -f "${TMPDIR}/module.prop" ] && return
[ "${platform}" = "" ] && platform="$(getprop ro.product.cpu.abi)"
[ "${platform}" = "" ] && platform="$(grep_prop ro.product.cpu.abi)"
if [ "${platform}" = "" ] ;then
	ui_print "- 无法获取您的设备架构"
	abort >/dev/null 2>&1
else
	local bin_file_name="$CUSTOM_PROGRAM"
	local bin_file="${MODPATH}/bin/${platform}/${bin_file_name}"
	local bin_Info="$(file "${bin_file}" | sed "s|${bin_file}:||g" | tr ',' '\n' | sed -E 's/^(.*)/-\1/g' )"
	ui_print ""
	ui_print "**************************************************"
	ui_print "- 架构: ${bin_file##*/bin/} "
	ui_print "- 构建信息: 
${bin_Info} "
	cp -rf "${bin_file}" "${MODPATH}/${bin_file_name}"
	rm -rf "${MODPATH}/bin"
	ui_print "**************************************************"
	ui_print ""
fi
}

function get_other_thread(){
[ -f "${1}" ] && ui_print "- 检查可能的冲突……" || return
#查找Asoul对应包名
[ -f "$MODPATH/Scripts/Asoulpackage.sh" ] && . "$MODPATH/Scripts/Asoulpackage.sh"
local Asoul_package="$Asoulpackage"
#查找Scene线程配置文件
local local_thread_config="$(grep -Ev '^[[:space:]]*$|#' "${1}" | sed 's/{.*//g;s/=.*//g;s/:.*//g' | sort -u)"
local package_config=`echo "${local_thread_config}" | tr '\n' '|' | sed -E 's/\|$//g;s/\?//g;s/\*//g' `
local scene_version=`dumpsys package com.omarea.vtools 2>/dev/null | grep -m1 -iEo "versionCode=[0-9]{9,12}" | tr -cd '[:digit:]'`
for i in /data/user/0/com.omarea.*/files/threads.json
do
	[ "${scene_version}" -ge "820250518" ] && ui_print "- Scene 版本: ${scene_version} " && break
	haspackage=$(grep -Eo "${package_config}" "${i}" 2>/dev/null | sed -E 's/^(.)/- \1/g')
	[ "${haspackage}" != "" ] && ui_print "- Scene核心分配找到和用户自定义重复的包名
- 请自行确认Scene的核心配置已关闭(Scene顶部→调节→Scene xx齿轮⚙️→核心分配)。
- 如果关闭了就不用管！如果关闭了就不用管！如果关闭了就不用管！
- 模块不能检测Scene的开关！模块不能检测Scene的开关！模块不能检测Scene的开关！
${haspackage}"
done
[ -d "/data/adb/modules/asoul_affinity_opt" -a ! -f "/data/adb/modules/asoul_affinity_opt/disable" ] && local Asoul_conflict=$(echo "${Asoul_package}" | grep -Eo "${package_config}" | sed -E 's/^(.)/- \1/g' )
[ "${Asoul_conflict}" != "" ] && ui_print "- 找到配置文件和A-soul模块冲突的包名，请不要重复配置
${Asoul_conflict}
"
#查找冲突模块
[ "$(get_other_module)" != "" ] && ui_print "
- 检测到可能冲突模块
- 确保不要重复配置应用$(get_other_module)"
#get_other_module
[ "${haspackage}" = "" -a "${Asoul_conflict}" = "" -a "$(get_other_module)" = "" -a "$(get_other_module)" = "" ] && ui_print "- 未找到对应模块冲突或者应用冲突……"
}

function get_app_cpu_Info(){
#检测代码来源于@coolapk 10007
[ "${0##*/}" = "action.sh" ] && ui_print "- 检测程序运行状况……" || return
local cpuinfo_show=`dumpsys cpuinfo | grep -Eo '[0-9]{1,3}(\.[0-9])?%[[:space:]]+[0-9]{1,6}\/AppOpt'`
local Check_cpuinfo="$(echo "${cpuinfo_show}" | sed -E 's|[[:space:]][0-9]{1,6}/AppOpt||g' )"
case "${Check_cpuinfo}" in
0.[0-9]%|0%)
ui_print "- ●$CUSTOM_PROGRAM●
- ${cpuinfo_show}
- 正常……"
;;
[0-9]%|[0-9].[0-9]%)
ui_print "- ●$CUSTOM_PROGRAM●
- ${cpuinfo_show}
- 正常运行……
- 但占用过大！？
"
;;
[0-9][0-9]%|[0-9][0-9].[0-9]%)
ui_print "- ●$CUSTOM_PROGRAM●
- ${cpuinfo_show}
- 异常占用！
- 建议反馈给开发者！
"
[ -f "${0%/*}/service.sh" ] && nohup "${0%/*}/service.sh" >/dev/null 2>&1
;;
[0-9][0-9][0-9]%|[0-9][0-9][0-9].[0-9]%)
ui_print "- ●$CUSTOM_PROGRAM●
- ${cpuinfo_show}
- 核心爆炸了，哥们！
- 我给你重启了进程，3秒后再执行action(操作)查看吧……
"
[ -f "${0%/*}/service.sh" ] && nohup "${0%/*}/service.sh" >/dev/null 2>&1
;;
*)
if [ "$(pgrep -lf $CUSTOM_PROGRAM | sed "/${0##*/}/d;/App_GET_Thread/d;/busybox/d;/^[[:space:]]*$/d" )" != "" ];then
ui_print "- ●$CUSTOM_PROGRAM●
- $CUSTOM_PROGRAM进程正常运行……
- 命令行 `pgrep -lf $CUSTOM_PROGRAM | sed "/${0##*/}/d;/App_GET_Thread/d;/busybox/d;/^[[:space:]]*$/d"`
"
else
ui_print "- ●$CUSTOM_PROGRAM●
- 未找到$CUSTOM_PROGRAM进程……
- 尝试重启$CUSTOM_PROGRAM……
"
[ -f "${0%/*}/service.sh" ] && nohup "${0%/*}/service.sh" >/dev/null 2>&1
sleep 5s && [ "$(pgrep -lf $CUSTOM_PROGRAM | sed "/${0##*/}/d;/App_GET_Thread/d;/busybox/d;/^[[:space:]]*$/d" )" != "" ] && ui_print "- 重启完成……" || ui_print "- 重启失败……"
fi
;;
esac
}

#限制日志大小
function limit_log_file() {
local logfile="${1}"
local maxsize=$((1024 * 100))
local filesize=$(stat -c%s "${logfile}" 2>/dev/null || ls -l "${logfile}" | awk '{print $5}')
if [ "$filesize" -gt "$maxsize" ]; then
	: > "${logfile}"
	echo "[$(date '+%F %T')] [I] 日志达到上限，已清空日志。" >> "${logfile}"
fi
}

#查找错误日志
function show_error_log_content(){
local log_file="${MY_MODULE_FOLDER}/affinity_manager.log"
[ ! -f "${log_file}" -o "${0%##*/}" = "action.sh" ] && return
limit_log_file "${log_file}"
local error="$(grep -v '\[I\]' "$log_file" | sed '/^[[:space:]]*$/d' | head -n 10)"
if [ "${error}" != "" ];then
ui_print "
- 配置规则解析异常，不影响正常使用。
- 如需消除，请更新模块到最新版本。
- 详情: /storage/emulated/0/Download/AppOpt错误日志.log
"
local log_error_output_file="/storage/emulated/0/Download/AppOpt错误日志.log"
mkdir -p "${log_error_output_file%/*}"
cp -af "${log_file}" "$log_error_output_file"
[ -f "${module_config}" ] && echo -e "\n#配置文件$(cat "${module_config}" )\n#END" >> "$log_error_output_file"
fi
}

function fix_applist_conf(){
local target_file="${1}"
#local cpu_range=$(cat /sys/devices/system/cpu/present 2>/dev/null )
[ ! -f "$target_file" ] && return
sed -E -i \
    -e '/^[[:space:]]*$/N;/\n$/d' \
    -e 's/(=.*[0-9])([[:space:]]+#.*)/\1/g' \
    -e 's/--/-/g' \
    -e 's/=([0-9]+|[0-9]-[0-9])，/=\1,/g' \
    -e 's/(=)([^0-9]+)([0-9])/\1\3/g' \
    -e 's/^(\}|\})/#\1/g' \
    -e 's/[[:space:]]$//g' \
    -e 's/^([^#a-zA-Z0-9.-/\\]+)/#\1/g' \
    -e 's/=([0-9]|[0-9]-?[0-9]?,[0-9]-?[0-9]?|[0-9]-[0-9])([^0-9]+)$/=\1/g' \
    -e 's/(^[^#][^=]*$)/#\1/g' \
    "${target_file}"
#grep -E "(=[0-9]{2,}|=[0-9]{2,}-[0-9]+|=[0-9]+-[0-9]{2,}|=[0-9]{2,}\,[0-9]?|=[0-9]?\,[0-9]{2,})" "${target_file}" | sed -E 's/(.*)=(.*)/核心配置貌似不对？内容:\1=\2/g;/^[[:space:]]*$/d'
#[ "${cpu_range}" != "" ] && grep -E "=[^${cpu_range}]|=[0-9]+\,[^${cpu_range}]$|=[0-9]+-[^${cpu_range}]$" "${target_file}" | sed -E '/#/d;/^[[:space:]]*$/d;/Debug_AppOpt=/d;s/(.*)=(.*)/不存在的核心 内容:\1=\2/g;/^[[:space:]]*$/d'
grep -Ev '^[[:space:]]*$|^#' "${target_file}" | sed -E 's/=([0-9].*)/=/g' | uniq -d | while read -r same
do
	ui_print "- 检测到重复行……"
	ui_print "- 进程名称: ${same} : `grep -n "${same}" "${target_file}" | sed -E 's|([0-9]{1,3})\:(.*)|\1行|g;s/\|$//g' |  tr '\n' ' ' `"
done | sort -u 
}

function core_architect_set(){
[ ! -f "${TMPDIR}/module.prop" ] && return
local file="${1}"
local flag_modtify="${2}"
[ ! -f "${file}" ] && return
local architect=$(out=; for f in /sys/devices/system/cpu/cpufreq/*/related_cpus; do [ -f "$f" ] || continue; read -r cpus < "$f"; count=0; for token in $(echo "$cpus" | tr ',' ' '); do case $token in *-*) count=$((count + ${token#*-} - ${token%-*} + 1)) ;; *) count=$((count + 1)) ;; esac; done; out="${out}+${count}"; done; echo "${out#+}")
if [ "${architect}" = "" ];then
	echo "- 核心信息无法获取？"
	return
else
[ ! -f "${flag_modtify}" -a -f "${MY_MODULE_FOLDER}/applist.prop" ] && return
echo "- 正在修改成: ${architect} 的核心配置……"
if [ "${architect}" = "4+3+1" ];then
	echo "- 同核心配置，跳过修改……"
else
	echo "- 修改中……"
	echo "- 用CPU拓扑自动适配: ${architect} ……"
	if [ -f "$MODPATH/Scripts/util_func.sh" ] ;then
	 . "$MODPATH/Scripts/util_func.sh"
	 # 第一步：将基于4+3+1的数字模式替换为语义占位符
	 sed -E -i \
	     -e "s/=(4|5|6)$/=__PH_PERF__/g" \
	     -e "s/=(4|5)-(5|6)$/=__PH_PERF__/g" \
	     -e "s/=7$/=__PH_HIGH__/g" \
	     -e "s/=0-6$/=__PH_COMM__/g" \
	     -e "s/=0-5$/=__PH_GAME__/g" \
	     -e "s/=7,([0-9])$/=__PH_MIX_HIGH__/g" \
	     -e "s/=(4|6|5)-7$/=__PH_MIX_HIGH__/g" \
	     -e "s/=0-(2|3)$/=__PH_EFF__/g" \
	     -e "s/=(0-4|2-4)$/=__PH_LOW_UTIL__/g" \
	     -e "s/=(0|1)$/=__PH_LOW_PRIO__/g" \
	     -e "s/=(2|3)-6$/=__PH_MIX_LOW__/g" \
	     -e "s/=(2|3)-7$/=__PH_MIX_ALL__/g" \
	     -e "s/=0-7$/=__PH_ALL__/g" "${file}"
	 # 第二步：处理日用应用特殊规则
	 sed -E -i '/^#日用应用$/,/^#日用应用END$/ {
		 s/(\{RenderThread\})=[0-9,\-]+$/\1=__PH_RENDER__/g
		 s/(\{.*(\.ui|\.raster)\})=[0-9,\-]+$/\1=__PH_NON_EFF__/g
		 s/(\{(Chrome_InProcGp|Chrome_InProcRe|CrRendererMain)\})=[0-9,\-]+$/\1=__PH_HIGH__/g
	}' "${file}"
	 # 第三步：将占位符替换为当前设备实际核心值
	 sed -i \
	     -e "s/=__PH_PERF__/=$performance_core/g" \
	     -e "s/=__PH_HIGH__/=$high_performance_core/g" \
	     -e "s/=__PH_COMM__/=$Comm_App_core/g" \
	     -e "s/=__PH_GAME__/=$Game_core/g" \
	     -e "s/=__PH_MIX_HIGH__/=$mix_high_performance_core/g" \
	     -e "s/=__PH_EFF__/=$efficiency_core/g" \
	     -e "s/=__PH_LOW_UTIL__/=$low_utilization_core/g" \
	     -e "s/=__PH_LOW_PRIO__/=$low_priority_task_core/g" \
	     -e "s/=__PH_MIX_LOW__/=$mix_all_low_core/g" \
	     -e "s/=__PH_MIX_ALL__/=$mix_all_core/g" \
	     -e "s/=__PH_ALL__/=$All_CORES/g" \
	     -e "s/=__PH_RENDER__/=$performance_core/g" \
	     -e "s/=__PH_NON_EFF__/=$mix_high_performance_core/g" "${file}" && echo "- 完成……"
	else
		echo "- 公共函数丢失跳过适配……"
	fi
fi
fi
}

function mtk_remove_app_cfg(){
[ ! -f "${TMPDIR}/module.prop" ] && return
local file="/system/vendor/etc/power_app_cfg.xml"
if [ -f "${file}" ];then
	mkdir -p "$MODPATH/${file%/*}"
	cp -af "${file}" "$MODPATH/${file}" >/dev/null 2>&1
echo '<?xml version="1.0" encoding="UTF-8"?>
<WHITELIST>
</WHITELIST>' > "$MODPATH/${file}"
fi
}

function set_miui_booster() {
[ ! -f "${TMPDIR}/module.prop" ] || [ "$(getprop | grep -E 'miui|mi\.os')" = "" ] && return
local architect=$(out=; for f in /sys/devices/system/cpu/cpufreq/*/related_cpus; do [ -f "$f" ] || continue; read -r cpus < "$f"; count=0; for token in $(echo "$cpus" | tr ',' ' '); do case $token in *-*) count=$((count + ${token#*-} - ${token%-*} + 1)) ;; *) count=$((count + 1)) ;; esac; done; out="${out}+${count}"; done; echo "${out#+}")
local all_cpu=$(cat /sys/devices/system/cpu/present 2>/dev/null)
case "${architect}" in
4+3+1|4+4) booster_cpus="6-7" Surface_cpus="4-7";;
3+4+1) booster_cpus="7,3-4" Surface_cpus="7,3-4" ;;
2+3+2+1) booster_cpus="5-7" Surface_cpus="7,2-4" ;;
6+2) booster_cpus="6-7" Surface_cpus="4-7" ;;
*) return ;;
esac
cat > "${MODPATH}/system.prop" << Aloazny
#MIUI动画亲和值加速
persist.sys.miui_animator_sched.bigcores=${booster_cpus}
persist.sys.miui_animator_sched.big_prime_cores=${booster_cpus}
#Surface进程渲染
ro.miui.affinity.sfui=${Surface_cpus}
ro.miui.affinity.sfre=${Surface_cpus}
#启用Surface进程亲和设定
ro.miui.surfaceflinger_affinity=true
#下面这个Surface设定不知道有没有效，在我的系统没找到调用
#如果有效可以自己加
#persist.sf.force_setaffinity.bigcore=${booster_cpus}
#决定Surface线程可用CPU
#ro.miui.affinity.sfuireset=${all_cpu}
#Surface其他线程
#persist.sys.miui.sf_cores=${all_cpu}
#display？不知道我没有这个服务
persist.vendor.display.miui.composer_boost=${Surface_cpus}
#禁用MIUI线程绑定
persist.sys.miui_animator_sched.enabled=false
Aloazny
resetprop --delete persist.sys.miui_animator_sched.bigcores; resetprop --delete persist.sys.miui_animator_sched.big_prime_cores; resetprop --delete ro.miui.affinity.sfui;resetprop --delete ro.miui.affinity.sfre
resetprop --file "${MODPATH}/system.prop"
}

function add_dexota_prop(){
local system_prop_file="${MODPATH}/system.prop"
local flag_file="${1}"
[ ! -f "${TMPDIR}/module.prop" ] && return
[ -f "${flag_file}" ] || return
local architect=$(out=; for f in /sys/devices/system/cpu/cpufreq/*/related_cpus; do [ -f "$f" ] || continue; read -r cpus < "$f"; count=0; for token in $(echo "$cpus" | tr ',' ' '); do case $token in *-*) count=$((count + ${token#*-} - ${token%-*} + 1)) ;; *) count=$((count + 1)) ;; esac; done; out="${out}+${count}"; done; echo "${out#+}")
case "${architect}" in
4+3+1|4+4)
dexota_cpus="4,5,6,7"
;;
3+4+1)
dexota_cpus="3,4,5,6,7"
;;
2+3+2+1)
dexota_cpus="3,4,5,6,7"
;;
6+2)
dexota_cpus="3,4,5,6,7"
;;
*)
local raw_cpu=$(cat /sys/devices/system/cpu/present 2>/dev/null)
dexota_cpus=$(seq -s "," "${raw_cpu%-*}" "${raw_cpu#*-}" 2>/dev/null)
;;
esac
thread_total="$(echo "${dexota_cpus}" | tr ',' '\n' | wc -l)"
#修改Java虚拟机分配内存
#加快冷启动
#读取内存
local MemTotalGB target_heapstartsize target_heapgrowthlimit
read label mem_kb unit << Aloazny
$(grep "MemTotal:" /proc/meminfo)
Aloazny
[ "$label" = "MemTotal:" ] && MemTotalGB=$(( (mem_kb + 524288) / 1024 / 1024 )) || MemTotalGB="8"
#空闲内存最小值，超过会触发GC回收
#dalvik.vm.heapstartsize初始值为8(m)
#dalvik.vm.heapminfree最大值为8(m)
#dalvik.vm.heapmaxfree最大值为32(m)
#dalvik.vm.heapgrowthlimit决定dalvik.vm.heapmaxfree上限
local target_heapmin target_heapmax
if [ "$MemTotalGB" -le 6 ]; then
	target_heapmin="3"
	target_heapmax="12"
	target_heapstartsize="16"
elif [ "$MemTotalGB" -le 8 ]; then
	target_heapmin="4"
	target_heapmax="16"
	target_heapstartsize="24"
else
	target_heapmin="4"
	target_heapmax="16"
	target_heapstartsize="32"
fi
modtify_heapstartsize="dalvik.vm.heapstartsize=${target_heapstartsize}m"
modtify_heapmin="dalvik.vm.heapminfree=${target_heapmin}m"
modtify_heapmax="dalvik.vm.heapmaxfree=${target_heapmax}m"
#设定一次预读取ODEX/VDEX/ART文件的大小上限
local size_min="157286400"
local size_middle="536870912"
local size_big="2147483647"
local ODEX_SIZE
#6G RAM 选150m 8G选512M，12G及以上选择2GB
if [ "$MemTotalGB" -le 6 ]; then
    ODEX_SIZE=$size_min
elif [ "$MemTotalGB" -le 8 ]; then
    ODEX_SIZE=$size_middle
else
    ODEX_SIZE=$size_big
fi
# 执行写入
local start_preload_image_size=$(echo -e "#请参考https://android.googlesource.com/platform/art/+/master/runtime/runtime.cc\ndalvik.vm.madvise.odexfile.size=$ODEX_SIZE\ndalvik.vm.madvise.vdexfile.size=$ODEX_SIZE\ndalvik.vm.madvise.artfile.size=$ODEX_SIZE")
#ART运行时缓存大小，默认64m(65536)。
#被硬编码成最大64m，超过64m无用。
local target_jitmaxsize="dalvik.vm.jitmaxsize=64m"
local target_modtify_heap_content="$(echo -e "#请参考https://android.googlesource.com/platform/art/+/master/runtime/gc/heap.cc?hl=zh-CN
${modtify_heapstartsize}
${modtify_heapmin}
${modtify_heapmax}
#来源于https://android.googlesource.com/platform/art/+/refs/heads/main/runtime/jit/jit_code_cache.h
#Google目前硬编码成64m，高于这个值无意义
${target_jitmaxsize}
" | sed '/^[[:space:]]*$/d' )"
#指定编译过滤器具体参考下面源码
#https://source.android.com/docs/core/runtime/configure?hl=zh-cn#compiler_filters
#https://source.android.com/docs/core/runtime/jit-compiler?hl=zh-CN#profile-guided-compilation
local dexota_mode="speed-profile"
local dexota_speed_mode="speed"
#快速安装场景，skip速度大于verify > quicken > extract 更快
#Android12以后，verify效果quicken差不多
#选verify开机会更好，而且speed-profile未收集到函数时，效果就是verify
local dexota_quick_mode="verify"
if [ "${dexota_mode##*-}" = "profile" ] ;then
	speed_profile_opt_some="
#请参考https://android.googlesource.com/platform/art/+/master/runtime/jit/profile_saver.cc?hl=zh-CN
#首次采样方法最小时间
#默认是20000也就是20秒，我们这里改成10秒
dalvik.vm.ps-min-first-save-ms=10000
#两次方法记录更新最小时间，单位依旧是ms
#默认40秒，这里我们改成30秒
dalvik.vm.ps-min-save-period-ms=30000
#下面这两个是Android12才加的
#用于作为更新方法的频率，默认都是20，也就是20%
#意图在更新20%不同方法，再更新dex2oat编译，这里改成10吧
#毕竟dex2oat编译很耗费资源，改成5%的话，可能会发热。
dalvik.vm.bgdexopt.new-classes-percent=10
dalvik.vm.bgdexopt.new-methods-percent=10
"
else
	speed_profile_opt_some=""
fi

local other_dexopt_scene="
#其他场景
#快速安装，Android12加的
pm.dexopt.install-fast=$dexota_quick_mode
#鸡肋，条件触发苛刻
#①存储空间必须到系统设定提示空间不足时触发，就像老Android会在剩余10%存储时提示你空间不足
#②必须得到pm.dexopt.downgrade_after_inactive_days指定未打开天数时降级
#所以pm.dexopt.inactive并不会像你们理解那样，长时间不打开就自动降级
pm.dexopt.inactive=$dexota_quick_mode
pm.dexopt.downgrade_after_inactive_days=15
#首次开机
pm.dexopt.first-boot=$dexota_quick_mode
#正常重启
pm.dexopt.post-boot=$dexota_quick_mode
"

local modtify_content="#修改虚拟机内存冷启动速度
$target_modtify_heap_content
$start_preload_image_size
#具体请参考Google官方文档
#https://source.android.com/docs/core/runtime/configure?hl=zh-cn
#https://source.android.com/docs/core/runtime/configure/art-service?hl=zh-cn
#https://source.android.com/docs/core/runtime/jit-compiler?hl=zh-CN#profile-guided-compilation
#场景编译
#everything比speed省内存
#但是everything体积太大而且不适合国内流氓软件
#speed比较均衡
#speed-profile只编译热点函数
#比speed稍微节省一点占用空间
pm.dexopt.ab-ota=${dexota_mode}
pm.dexopt.bg-dexopt=${dexota_mode}
pm.dexopt.boot-after-ota=${dexota_mode}
pm.dexopt.cmdline=${dexota_mode}
#下面这条Android14以上已经被删除弃用
pm.dexopt.install=${dexota_mode}
#其他默认使用的编译器过滤器(Android6.0左右的prop值，已经被上面的pm.dexopt.*替代)
dalvik.vm.dex2oat-filter=${dexota_mode}
${other_dexopt_scene}

#启动安装时编译线程数目
dalvik.vm.bg-dex2oat-threads=${thread_total}
dalvik.vm.boot-dex2oat-threads=${thread_total}
dalvik.vm.dex2oat-threads=${thread_total}
dalvik.vm.background-dex2oat-threads=${thread_total}
dalvik.vm.image-dex2oat-threads=${thread_total}
persist.dalvik.vm.dex2oat-threads=${thread_total}
ro.sys.fw.dex2oat_thread_count=${thread_total}
system_perf_init.bg-dex2oat-threads=${thread_total}
system_perf_init.boot-dex2oat-threads=${thread_total}
system_perf_init.dex2oat-threads=${thread_total}

#设置指定编译的CPU
dalvik.vm.background-dex2oat-cpu-set=${dexota_cpus}
dalvik.vm.boot-dex2oat-cpu-set=${dexota_cpus}
dalvik.vm.default-dex2oat-cpu-set=${dexota_cpus}
dalvik.vm.dex2oat-cpu-set=${dexota_cpus}
dalvik.vm.image-dex2oat-cpu-set=${dexota_cpus}
${speed_profile_opt_some}
"
if [ -f "${system_prop_file}" ];then
	echo -e "\n#修改dex2ota内容\n${modtify_content}" >> "${system_prop_file}"
else
	echo -e "\n#修改dex2ota内容\n${modtify_content}" > "${system_prop_file}"
fi
	resetprop --file "${system_prop_file}"
	cp -af "${system_prop_file}" "${MY_MODULE_FOLDER}/system.prop" 2>/dev/null
}

function update_bin_file(){
local original_bin_file="${MY_MODULE_FOLDER}/$CUSTOM_PROGRAM"
local update_bin_file="${original_bin_file/modules/modules_update}"
[ ! -f "${update_bin_file}" ] && return
if ! cmp "${original_bin_file}" "${update_bin_file}" >/dev/null 2>&1 ;then
	echo "- 升级 ${original_bin_file##*/} 文件……"
	cp -af "${update_bin_file}" "${original_bin_file}" >/dev/null 2>&1
	cp -af "${update_bin_file%/*}/service.sh" "${original_bin_file%/*}/service.sh"
	cp -af "${update_bin_file%/*}/Scripts"/* "${original_bin_file%/*}/Scripts" >/dev/null 2>&1
	chmod a+x "${original_bin_file%/*}/service.sh"
	nohup "${original_bin_file%/*}/service.sh" >/dev/null 2>&1 && echo -e "- 已经重启$CUSTOM_PROGRAM……\n- 理论上无需重启手机……"
fi
}

function hide_module_check() {
[ ! -f "$TMPDIR/module.prop" ] && return
[ ! -d "$TMPDIR/system" ] && return
local zygisk_hide_module="
/data/adb/modules/zygisksu
/data/adb/modules/zygisk_shamiko
/data/adb/modules/zygisk-maphide
/data/adb/modules/treat_wheel
/data/adb/modules/zygisk_nohello
"
local a=0
    for module in $zygisk_hide_module; do
        if [ -d "$module" ] && [ ! -f "$module/disable" ] && [ ! -f "$module/remove" ]; then
            a=$((a+1))
            if [ "${module##*/}" = "zygisksu" ]; then
                zygisk_version=$(sed -E '/[Vv]ersion[Cc]ode=([0-9]+)/!d;s/.*=//' "$module/module.prop" 2>/dev/null)
                zygisk_bin_folder="/data/adb/modules/zygisksu/bin"
                zygisk_denylist_state="/data/adb/zygisksu/denylist_enforce"
                zygisk_denylist_policy="${zygisk_denylist_state%/*}/denylist_policy"
                [ -d "$zygisk_bin_folder" ] && export PATH="$PATH:$zygisk_bin_folder"
                if [ "$zygisk_version" -ge 648 ] && [ ! -f "$module/disable" ] && [ ! -f "$module/remove" ]; then
                    if [ ! -f "$zygisk_denylist_state" ] || [ "$(cat "$zygisk_denylist_state" 2>/dev/null)" = "0" ]; then
                        echo 2 > "$zygisk_denylist_state"
                        zygiskd enforce-denylist just_umount >/dev/null 2>&1
                        touch "${zygisk_denylist_state%/*}/no_mount_znctl"
                        echo "- 已经为您开启zygisk next [排除列表策略] → [仅还原挂载]……"
                    fi
                    [ ! -f "$zygisk_denylist_policy" ] && echo 0 > "$zygisk_denylist_policy" && zygiskd denylist-policy default >/dev/null 2>&1
                else
                    a=0
                fi
            fi
        fi
    done
[ "$a" = "0" ] && touch "$MODPATH/skip_mount" && echo "- 未安装隐藏模块，默认不挂载/system……"
}

function Delete_Game_config(){
[ ! -f "${TMPDIR}/module.prop" ] && return
local flag_file="${2}"
local config_file="${1}"
if [ -f "${flag_file}" ];then
	echo "- 删除游戏配置文件……"
	sed -i '/^#游戏$/,/^#游戏END$/d' "${config_file}" && echo "- 完成……" || echo "- 失败！"
fi
}

function Remov_Asoul_opt_Config(){
local keep_Asoulopt_flag="$MODPATH/Flags/keep_Asoulopt"
[ -f "$MODPATH/Scripts/Asoulpackage.sh" ] && . "$MODPATH/Scripts/Asoulpackage.sh"
if [ -f "$keep_Asoulopt_flag" ];then
	Remove_Asoul_package "${1}" 2>/dev/null
fi
}

function Move_old_flag(){
[ ! -f "${TMPDIR}/module.prop" ] && return
local install_module_Flags_folder="${MODPATH}/Flags"
local my_module_Flags_folder="$MY_MODULE_FOLDER/Flags"
for flag in dexota_modtify delete_game_config keep_custom_rule modtify_config update_config enable_program disable_program
do
	old_flag_file="${MY_MODULE_FOLDER}/$flag"
	if [ -f "${old_flag_file}" ] ;then
		mkdir -p "${my_module_Flags_folder}"
		mv -f "${old_flag_file}" "${my_module_Flags_folder}"
	fi
done
if [ -f "$install_module_Flags_folder/zip_first" ] ;then
	rm -rf "$my_module_Flags_folder"
	mkdir -p "$my_module_Flags_folder"
	cp -af "${install_module_Flags_folder}"/* "${my_module_Flags_folder}"
	rm -rf "${install_module_Flags_folder}/zip_first" "${my_module_Flags_folder}/zip_first"
	return
fi
if [ -d "$my_module_Flags_folder" ] ;then
	rm -rf "${install_module_Flags_folder}"/*
	cp -af "$my_module_Flags_folder"/* "${install_module_Flags_folder}"
else
	mkdir -p "$my_module_Flags_folder"
	cp -af "${install_module_Flags_folder}"/* "${my_module_Flags_folder}"
fi
}

function Move_old_Scripts(){
[ ! -f "${TMPDIR}/module.prop" ] && return
local new_script_folder="${MY_MODULE_FOLDER}/Scripts"
local install_script_folder="$MODPATH/Scripts"
[ ! -d "$new_script_folder" ] && mkdir -p "${new_script_folder}"
local old_script="
Asoulpackage.sh
anti_evil_zygisk.sh
cpu_control.sh
priority.sh
program_ctrl.sh
resetprop.sh
util_func.sh
"
for script in $old_script
do
	old_script_file="${MY_MODULE_FOLDER}/$script"
	[ -f "$old_script_file" ] && mv -f "$old_script_file" "${new_script_folder}"
	if ! cmp "$new_script_folder/$script" "$install_script_folder/$script" >/dev/null 2>&1 ;then
		if [ -f "$install_script_folder/$script" ] ;then
			cp -af "$install_script_folder/$script" "$new_script_folder/$script"
			chmod -R 0755 "$new_script_folder"
		 	nohup "$new_script_folder/$script" >/dev/null 2>&1 &
		 fi
	fi
done
}

#shell 特殊字符转义
function escape_special_chars(){
	local input=${1}
	local output=$(echo ${input} | sed 's/[\^\|\*\?\$\=\@\/\.\"\+\;\(\)\{\}]/\\&/g;s|\[|\\&|g;s|\]|\\&|g' )
	echo ${output}
}

#添加用户规则
function add_custom_Rules(){
local IFS=$'\n'
local user_file="${1}"
local module_file="${2}"
[ ! -f "${user_file}" -o ! -f "${module_file}" ] && echo "- 配置文件不存在……" && return
local Rules="$(diff -U0 "${user_file}" "${module_file}" | sed -E '/^\@/d;/^\-\-.*[[:space:]]/d;/^\+\+.*[[:space:]]/d;/#/d;/^\-/!d;s/^\-//g' )"
local a=0
local b=0
[ "${Rules}" = "" ] && echo "- 规则无变动……" && return
for rule in ${Rules}
do
	target_Rules="${rule%=*}"
	target_Rules_value="${rule##*=}"
	target_Rules_regex="$(escape_special_chars "${target_Rules}")"
	module_Rules="$(grep -E "${target_Rules_regex}=[0-9]+" "${module_file}")"
	if [ "${module_Rules}" = "" ] ;then
		[ "$(grep -E "^#用户规则" "${module_file}")" = "" ] && echo -e "\n#用户规则" >> "${module_file}"
		if [ "$a" -lt "10" ];then
			echo -e "- 添加规则 ${rule}"
		else
			[ "$a" = "10" ] && echo -e "- 添加规则过多，仅输出$a行……\n- 不影响实际添加……"
		fi
		echo -e "${rule}" >> "${module_file}"
		a=$((a+1))
	else
		sed -E -i "s/(${target_Rules_regex})(=)(.*)/\1\2${target_Rules_value}/g" "${module_file}"
		if [ "$b" -lt "30" ];then
			echo "- 默认规则 ${module_Rules} → 用户规则: ${rule} "
		else
			[ "$b" = "30" ] && echo -e "- 修改规则过多，仅输出$b行……\n- 不影响实际修改……"
		fi
		b=$((b+1))
	fi
done
[ "${a}" != "0" ] && echo "#End" >> "${module_file}" && echo "- 累计添加规则[${a}]条……"
[ "${b}" != "0" ] && echo "- 累计修改规则[${b}]条……"
}

function Running_add_custom_Rules(){
local flag="${1}"
local user_file="${2}"
local module_file="${3}"
[ ! -f "${TMPDIR}/module.prop" ] && return
if [ -f "${flag}" ];then
	echo "- 保留用户上次修改规则中……"
	add_custom_Rules "${user_file}" "${module_file}"
	echo "- 完成！"
fi
}

#代码来源于coolapk@10007
#获取酷安名称
function get_coolapk_user_name(){
for i in /data/user/0/com.coolapk.market/shared_prefs/*preferences*.xml
do
	username="$(grep '<string name="username">' "${i}" | sed 's/.*"username">//g;s/<.*//g')"
	if [ -n "${username}" ];then
	 echo "${username}"
	 break
	fi
done
}

#获取github用户名
function get_github_user(){
local github_name="$(dumpsys content | grep -Eo 'Account[[:space:]].*u[0-9]{1,3}.*com\.github\.android' | sed 's/Account[[:space:]]//g;s/[[:space:]]u[0-9].*//g' | sort -u | head -n 1)"
echo "${github_name}"
}

#获取Nagram名称
function get_Nagram_user(){
local github_name="$(dumpsys content | grep -Eo 'Account[[:space:]].*u[0-9]{1,3}.*xyz\.nextalone\.nagram' | sed 's/Account[[:space:]]//g;s/[[:space:]]u[0-9].*//g' | sort -u | head -n 1)"
echo "${github_name}"
}

function echo_user_Name(){
local user_name="$(get_github_user)"
[ "${user_name}" = "" ] && user_name="$(get_Nagram_user)"
[ "${user_name}" = "" ] && user_name="$(get_coolapk_user_name)"
[ "${user_name}" = "" ] && user_name="$(getprop persist.sys.device_name)"
[ "${user_name}" != "" ] && echo "${user_name}" || echo "用户"
}

function Say_hello(){
local Time=$(date +%H)
local check_phone_number="$(cmd package list users 2>/dev/null | sed -E 's/[[:space:]]//g;s/(.*:)([0-9]{11})(:.*)/\2/g;/:/d;s/([0-9]{3})([0-9]{6})([0-9]{2})/\1******\3/g')"
echo -e "\n**************************************************"
case "${Time}" in
0[0-4]|19|2[0-3])
	echo -e "- 🌙晚上好！\n- 尊敬的 $(echo_user_Name) ……"
;;
0[5-9]|1[0-1])
	echo -e "- ☀早上好！\n- 尊敬的 $(echo_user_Name) ……"
;;
1[2-3])
	echo -e "- ☀中午好！\n- 尊敬的 $(echo_user_Name) ……"
;;
1[4-8])
	echo -e "- 🕓下午好！\n- 尊敬的 $(echo_user_Name) ……"
;;
*)
	echo -e "- 💬您好！\n- 尊敬的 $(echo_user_Name) ……"
;;
esac
[ "${check_phone_number}" != "" ] && echo -e "- 您的手机号已经泄露(${check_phone_number})！\n- 建议去设置里搜索多用户修改信息……"
}

function check_program_ailve(){
[ ! -f "${MY_MODULE_FOLDER}/update" -a ! -f "${TMPDIR}/module.prop" ] && return
if [ "$(pgrep -lf $CUSTOM_PROGRAM | sed "/${0##*/}/d;/App_GET_Thread/d;/^[[:space:]]*$/d" )" = "" ];then
	echo "- $CUSTOM_PROGRAM意外终止……"
	[ -f "$MY_MODULE_FOLDER/service.sh" ] && nohup "$MY_MODULE_FOLDER/service.sh" >/dev/null 2>&1 &
	echo "- 已尝试重启……"
fi
}

#获取内存信息
Get_mem_val() {
local ukey="$1"
local unit="${2:-MB}"
local num=$(grep -i "^$ukey:" /proc/meminfo | tr -cd '[:digit:]')
case "$unit" in
[Kk][Bb]) echo "$num" ;;
[Mm][Bb]) echo $((num / 1024)) ;;
[Gg][Bb]) echo $(((num + 524288) / 1024 / 1024)) ;;
*) echo "$num" ;;
esac
}

#部分来源于coolapk@10007
ui_print ""
ui_print "**************************************************"
ui_print "－品牌: `getprop ro.product.brand`"
ui_print "－代号: `getprop ro.product.device`"
if test "`getprop ro.vendor.oplus.market.name`" != "" ;then
	ui_print "－机型: `getprop ro.vendor.oplus.market.name`(`getprop ro.product.model`)"
elif test "`getprop ro.product.marketname`" != "" ;then
	ui_print "－机型: `getprop ro.product.marketname`(`getprop ro.product.model`)"
else
	ui_print "－机型: `getprop ro.product.model`"
fi
ui_print "－安卓版本: `getprop ro.build.version.release`"
if test "`getprop ro.mi.os.version.name`" != "" ;then
	ui_print "－HyperOS版本: HyperOS `getprop ro.mi.os.version.name` - `getprop ro.mi.os.version.incremental` "
elif test "`getprop ro.miui.ui.version.name`" != "" ;then
	ui_print "－MIUI版本: MIUI `getprop ro.miui.ui.version.name` - `getprop ro.build.version.incremental` "
fi
if test "`getprop ro.build.version.oplusrom`" != "" ;then
	ui_print "－Colors OS版本: Colors OS `getprop ro.build.version.oplusrom` - `getprop ro.build.version.ota` "
elif test "`getprop ro.build.version.oplusrom.display`" != "" ;then
	ui_print "－Colors OS版本: Colors OS `getprop ro.build.version.oplusrom.display` - `getprop ro.build.version.ota` "
fi

ui_print "－内核版本: `uname -a `"
ui_print "－运存大小: $(Get_mem_val 'MemTotal' )MB 已用:$(($(Get_mem_val 'MemTotal' ) - $(Get_mem_val 'MemAvailable')))MB 可用:$(Get_mem_val 'MemAvailable' )MB"
ui_print "－Swap大小: $(Get_mem_val 'SwapTotal' )MB 已用:$(($(Get_mem_val 'SwapTotal' ) - $(Get_mem_val 'SwapFree')))MB 剩余:$(Get_mem_val 'SwapFree' )MB"
ui_print "**************************************************"
ui_print "- 模块信息:"
ui_print "$(get_magisk_lite)"
ui_print "- Module version: $(grep_prop version "${MODPATH}/module.prop")"
ui_print "- Module versionCode: $(grep_prop versionCode "${MODPATH}/module.prop")"
ui_print "- 描述: $(grep_prop description "${MODPATH}/module.prop")"
Say_hello
mtk_remove_app_cfg
set_miui_booster
hide_module_check
get_app_cpu_Info
get_cpu_core_Info
[ -f "${TMPDIR}/module.prop" ] && {
Aloazny_script_name="Aloazny.sh"
module_config_folder="${MY_MODULE_FOLDER}"
mv -f "$MODPATH/${Aloazny_script_name}" "$MODPATH/action.sh"
chmod +x "$MODPATH/action.sh"
cp -af "$MODPATH/action.sh" "${module_config_folder}/action.sh"
rmdir "${module_config_folder%/*}/Scripts" 2>/dev/null
if [ ! -d "${module_config_folder}" ] ;then
	mkdir -p "${module_config_folder}" "${module_config_folder}/Scripts"
	cp -af "${MODPATH}/applist.prop" "${module_config_folder}/applist.prop"
fi
rm -rf "${module_config_folder}/${Aloazny_script_name}" "$MODPATH/${Aloazny_script_name}"
}
Move_old_flag
Move_old_Scripts
module_config_folder="${MY_MODULE_FOLDER}"
original_module="/data/adb/modules/AppOpt"
[ ! -d "${module_config_folder}" ] && module_config_folder="$original_module"
module_config="${module_config_folder}/applist.conf"
[ ! -f "${module_config}" ] && module_config="${module_config%/*}/applist.prop"
if [ -f "$module_config" -a -f "${TMPDIR}/module.prop" ]; then
	test -d "${original_module}" -a ! -f "${original_module}/disable" && touch "${original_module}/disable"
	if [ -f "${module_config%/*}/Flags/update_config" ];then
		echo "- 正在使用模块配置……"
		echo "- 您的配置文件将被覆盖……"
		echo "- 无需重启生效……"
		cp -af "$module_config" "$module_config.bak"
		cp -af "$MODPATH/${module_config##*/}" "$module_config"
		cp -af "$module_config.bak" "${MODPATH}/${module_config##*/}.bak"
	else
		echo "- 使用您的配置文件……"
		mv -f $MODPATH/${module_config##*/} $MODPATH/${module_config##*/}.bak
		cp -af "$module_config" "$MODPATH/${module_config##*/}"
	fi
		write_core_information "$MODPATH/${module_config##*/}"
		fix_applist_conf "$MODPATH/${module_config##*/}"
		Delete_Game_config "$MODPATH/${module_config##*/}" "${module_config%/*}/Flags/delete_game_config"
		Remov_Asoul_opt_Config "$MODPATH/${module_config##*/}"
		core_architect_set "$MODPATH/${module_config##*/}" "${module_config%/*}/Flags/modtify_config"
		Running_add_custom_Rules "${module_config%/*}/Flags/keep_custom_rule" "${module_config}.bak" "$MODPATH/${module_config##*/}"
		cp -af "$MODPATH/${module_config##*/}" "$module_config" 
fi

if [ ! -f "${module_config}" ];then
	core_architect_set "$MODPATH/applist.prop" "${module_config%/*}/Flags/modtify_config"
	Delete_Game_config "$MODPATH/applist.prop" "${module_config%/*}/Flags/delete_game_config"
	Remov_Asoul_opt_Config "$MODPATH/applist.prop"
fi

add_dexota_prop "${module_config%/*}/Flags/dexota_modtify"
fix_applist_conf "${module_config}"
get_other_thread "${module_config}"
write_core_information "${module_config}"
show_error_log_content
[ -f "${TMPDIR}/module.prop" ] && rm -rf "$MODPATH/源码" "$MODPATH/update.md" "$MODPATH/README.md" "$MODPATH/适配应用.md" "$MODPATH/LICENSE" "$MODPATH/changelog.md" "$MODPATH/update.json" "${MODPATH}/文档"
Move_platform_bin
update_bin_file
write_cpu_information_to_module_description
check_program_ailve

