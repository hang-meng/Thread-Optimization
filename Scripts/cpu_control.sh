if command -v busybox >/dev/null 2>&1 && ! command -v pgrep >/dev/null 2>&1; then
    pgrep() { busybox pgrep "$@"; }
fi
[ ! -d "${MODPATH}" ] && Scripts_DIR="${0%/*}" && MODPATH="${Scripts_DIR%/*}"
until [ -d "/data/user/0/android" ];do sleep 180; done
#锁定值
function lock_value(){
local val="$1"
local file="$2"
[ ! -f "$file" ] && return
chmod 0777 "$file" 2>/dev/null
	echo "$val" > "$file"
chmod 0444 "$file" 2>/dev/null
}

#mount --bind 对应值
function mount_hide_val() {
local file="${1}"
local hide_value="${2}"
local tmp_file="/dev/Aloazny${file}"
if [ -e "${file}" ]; then
	umount "${file}" 2>/dev/null
		[ ! -f "$tmp_file" ] && mkdir -p "${tmp_file%/*}" && cp -af "${file}" "${tmp_file}" 2>/dev/null
    	if [ "${hide_value}" != "" ];then
    		chmod 0777 "${file}" "${tmp_file}" 2>/dev/null 
				echo "${hide_value}" > "${tmp_file}"
				echo "${hide_value}" > "${file}"
			chmod 0444 "${tmp_file}" "${file}" 2>/dev/null 
    	fi
	mount --bind "${tmp_file}" "${file}"
fi
}

#禁用某些服务
function disable_some_service(){
local msm_irqbalance_service="vendor.${1}"
[ "$(getprop init.svc.$msm_irqbalance_service)" = "" ] && msm_irqbalance_service=$(getprop | sed -E "/init\.svc\.(system|vendor|odm|product|system_ext|my_product)\.${1}/!d; {s/(.*)(init\.svc)\.(.*${1})(\].*)/\3/g}" )
[ "${msm_irqbalance_service}" = "" ] && echo "- 未找到${1}服务" && return 0

if [ "$(getprop init.svc.$msm_irqbalance_service )" != "stopped" ];then
	setprop ctl.stop $msm_irqbalance_service >/dev/null 2>&1
	setprop init.svc.$msm_irqbalance_service stopped >/dev/null 2>&1
	stop $msm_irqbalance_service >/dev/null 2>&1
fi
}

#转换CPU掩码
function cpus_to_hex() {
local cpus="$1"
local mask=0
for item in $(echo "$cpus" | tr ',' ' '); do
if echo "$item" | grep -q '-'; then
	start=$(echo "$item" | cut -d'-' -f1)
	end=$(echo "$item" | cut -d'-' -f2)
	[ $start -gt $end ] && echo "- 无效规则 [ ${item} ]" && return
	for i in $(seq $start $end)
	do
		mask=$((mask | (1 << i)))
	done
else
	mask=$((mask | (1 << item)))
fi
done
    printf "%x\n" $mask
}

#合并cpus_to_hex
#方便直接调用函数实现CPU亲和设定
function set_target_cpuaffinity(){
local program="${1}"
local cpu_mask="${2}"
local pids="$(pgrep -f "$program" 2>/dev/null || pgrep -ef "$program" 2>/dev/null || pgrep "$program" 2>/dev/null)"
local hex_mask=0
local mask=0
for item in $(echo "$cpu_mask" | tr ',' ' '); do
	if echo "$item" | grep -q '-'; then
		start=$(echo "$item" | cut -d'-' -f1)
		end=$(echo "$item" | cut -d'-' -f2)
		[ $start -gt $end ] && echo "- 无效规则 [ ${item} ]" && return
		for i in $(seq $start $end);do mask=$((mask | (1 << i))); done
    else
		mask=$((mask | (1 << item)))
	fi
done
hex_mask=$(printf "%x\n" $mask)
for tid in $pids
do
	echo "- Cpus: [${cpu_mask}] >> Hex: [${hex_mask}]"
	taskset -a -p "${hex_mask}" "${tid}" 2>/dev/null || taskset -p "${hex_mask}" "${tid}"
done
}

#控制内存管理
function Memory_control(){
local architect=$(out=; for f in /sys/devices/system/cpu/cpufreq/*/related_cpus; do [ -f "$f" ] || continue; read -r cpus < "$f"; count=0; for token in $(echo "$cpus" | tr ',' ' '); do case $token in *-*) count=$((count + ${token#*-} - ${token%-*} + 1)) ;; *) count=$((count + 1)) ;; esac; done; out="${out}+${count}"; done; echo "${out#+}")
case "${architect}" in
4+3+1|4+4)
low_cpu="0-3"
middle_cpu="0-5"
heavy_cpu="4-6"
touch_kernel_proc_cpu="4-7"
;;
3+4+1)
low_cpu="0-2"
middle_cpu="0-4"
heavy_cpu="3-6"
touch_kernel_proc_cpu="3-7"
;;
2+3+2+1)
low_cpu="0-1"
middle_cpu="4-6"
heavy_cpu="2-4"
touch_kernel_proc_cpu="2-7"
;;
6+2)
low_cpu="0-3"
middle_cpu="3-6"
heavy_cpu="4-6"
touch_kernel_proc_cpu="1-6"
;;
*)
if [ -f "$MODPATH/Scripts/util_func.sh" ];then
	. "$MODPATH/Scripts/util_func.sh"
	low_cpu="$efficiency_core"
	middle_cpu="$mix_all_low_core"
	heavy_cpu="$performance_core"
	touch_kernel_proc_cpu="$mix_all_core"
else
	return
fi
;;
esac

if [ "${heavy_cpu}" != "" ];then
	#使用小核簇
	#一般二进制文件用不到超大核，如果不是真的需要，交给小核/大核即可，用到说明优化不好
	#并且如果二进制文件突然异常，绑定到超大核容易造成超大核唤醒和耗电
	set_target_cpuaffinity "lmkd" "${low_cpu}"
	set_target_cpuaffinity "logd" "${low_cpu}"
	set_target_cpuaffinity "mdnsd" "${low_cpu}"
	set_target_cpuaffinity "zygiskd" "${low_cpu}"
	set_target_cpuaffinity "magiskd" "${low_cpu}"
	set_target_cpuaffinity "lspd" "${low_cpu}"
	set_target_cpuaffinity "charge_logger" "${low_cpu}"
	set_target_cpuaffinity "zn-zygisk" "${low_cpu}"
	set_target_cpuaffinity "zn-nsdaemon" "${low_cpu}"
	#使用小核簇+大核簇
	#内存碎片管理，一般小核可应付，但是防止小核繁忙，大核也可加上
	set_target_cpuaffinity "kcompactd" "${middle_cpu}"
	#使用大核簇，避免超大核簇
	#内存回收，内存回收是一个持续的动作，也就是有可能一段时间内占用100%，避免抢占超大核簇和让小核簇为难，使用大核快速回收，并且减少耗电概率。
	set_target_cpuaffinity "kswapd" "${heavy_cpu}"
	set_target_cpuaffinity "kcompressd" "${heavy_cpu}"
	set_target_cpuaffinity "hybridswapd" "${heavy_cpu}"
	#触控内核进程测试
	#set_target_cpuaffinity "irq/.*ts" "${touch_kernel_proc_cpu}"
fi

}

#保证最大核心
function lock_max_cpus(){
local qit_boost_hotplug="/sys/kernel/msm_performance/events/cpu_hotplug"
[ -f "${qit_boost_hotplug}" ] && echo " " > "${qit_boost_hotplug}" && chmod 000 "${qit_boost_hotplug}" 2>/dev/null
for core in /sys/devices/system/cpu/cpu*/core_ctl/max_cpus
do
	#指定一个CPU簇的最大核心。
	#一般一个簇的核心不会超过8，所以填9也可以，但是我懒得再改，直接18。
	mount_hide_val "${core%/*}/need_cpus" "18" 
	mount_hide_val "${core%/*}/max_cpus" "18" 
	mount_hide_val "${core%/*}/min_cpus" "18" 
	#禁用核心控制
	mount_hide_val "${core%/*}/enable" "0"
done
for core in /sys/devices/system/cpu/cpu*/online
do
	mount_hide_val "${core}" "1"
done
}

function lock_cpu_set_dir(){
local cpu_set_file="
/dev/cpuset/top-app/cpus
/dev/cpuset/foreground/cpus
/dev/cpuset/gamelite/cpus
/dev/cpuset/game/cpus
/dev/cpuset/rt/cpus
"
max_cpus=$(cat /sys/devices/system/cpu/present 2>/dev/null )
if [ "$(echo "${max_cpus}" | grep '[0-9]' )" != "" ];then
	for cpus in ${cpu_set_file}
	do
		lock_value "${max_cpus}" "${cpus}"  
	done
fi
#rmdir /dev/cpuset/background/untrustedapp 2>/dev/null
#rmdir /dev/cpuset/foreground/boost 2>/dev/null
}

#来源于Scene
function disable_miui_migt(){
local migt=/sys/module/migt/parameters
local glk=/proc/sys/glk
local proc_migt=/proc/sys/migt
local sched_walt_migt=/sys/module/sched_walt/holders/migt/parameters
local metis_path=/sys/module/metis/parameters

chmod 0664 -R $metis_path $sched_walt_migt $proc_migt $glk $migt 2>/dev/null

if [ -d "${metis_path}" ];then
    for i in $metis_path/*reset*
 	  do
  		echo "1" > "${i}"
  	done
  	
  	for i in $metis_path/*affinity*
 	  do
  		echo " " > "${i}"
  	done
  	
#    for i in $metis_path/*enable $metis_path/cluaff_control
    for i in $metis_path/cluaff_control
 	  do
  		lock_value "0" "${i}"
   done
fi

#仅禁用migt的核心分配
if [ -d "${migt}" ];then
    for i in $migt/*reset* $proc_migt/*reset* $sched_walt_migt/*reset*
 	  do
  		echo "1" > "${i}"
  	done
  	
  	for i in $migt/*affinity* $sched_walt_migt/*affinity* $proc_migt/*affinity*
 	  do
  		echo " " > "${i}"
  	done
  	
    for i in $migt/cluaff_control $sched_walt_migt/cluaff_control $proc_migt/cluaff_control
 	  do
  		lock_value "0" "${i}"
   done
fi

#  if [ -d $migt ]; then
#    mount_hide_val $migt/glk_freq_limit_start '0'
#    mount_hide_val $migt/glk_freq_limit_walt '0'
#    lock_value 1 $migt/glk_disable
#    lock_value 0 $migt/mi_freq_enable
#    lock_value 0 $migt/force_stask_to_big
#    lock_value 0 $migt/glk_fbreak_enable
#    mount_hide_val $migt/enable_pkg_monitor '0'
#    chmod 000 $migt/*
#  fi

#  if [ -d $glk ]; then
#    mount_hide_val $glk/glk_disable '1'
#    mount_hide_val $glk/freq_break_enable '0'
#    mount_hide_val $glk/game_minfreq_limit '0 0 0'
#    mount_hide_val $glk/game_maxfreq_limit '0 0 0'
#    mount_hide_val $glk/game_lowspeed_load '30 30 30'
#    mount_hide_val $glk/game_hispeed_load '80 80 80'
#  fi
  
#  if [ -d $proc_migt ]; then
#    mount_hide_val $proc_migt/force_stask_tob '0'
#    mount_hide_val $proc_migt/enable_pkg_monitor '0'
#    mount_hide_val $proc_migt/boost_pid '0'
#  fi
  
#  if [ -d $sched_walt_migt ]; then
#  	chmod 000 $sched_walt_migt/*
#  fi
}

function disable_color_os_service(){
local max_cpus=$(cat /sys/devices/system/cpu/present 2>/dev/null )
local oppo_game_opt="/proc/game_opt"
if [ -d "${oppo_game_opt}" ]; then
	[ "${max_cpus}" = "0-7" ] && mount_hide_val "${oppo_game_opt}/cpu_max_freq" "0:2147483647 1:2147483647 2:2147483647 3:2147483647 4:2147483647 5:2147483647 6:2147483647 7:2147483647"
	[ "${max_cpus}" = "0-7" ] && mount_hide_val "${oppo_game_opt}/cpu_min_freq" "0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0"
	mount_hide_val "${oppo_game_opt}/disable_cpufreq_limit" "1"
fi
}

#禁用高通irqbalance服务
disable_some_service "tcpdump"
disable_some_service "cnss_diag"
disable_some_service "mm-pp-dpps"
disable_some_service "msm_irqbalance"
#锁定核心
lock_max_cpus
#禁用miui的migt
disable_miui_migt 2>/dev/null
#禁用oppo加设备部分限制
#disable_color_os_service 2>/dev/null
#设置前台应用所有可用CPU
lock_cpu_set_dir
#设置内存管理进程
Memory_control
