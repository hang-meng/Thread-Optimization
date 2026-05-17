export PATH="${PATH}:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"
export TZ="Asia/Shanghai"
if command -v busybox >/dev/null 2>&1; then
    awk() { busybox awk "$@"; }
    sed() { busybox sed "$@"; }
fi
init_cpu_vars() {
_e_h=false; _p_h=false; _hp_h=false; _a_h=false; _scan=0
_clean_cmd='{gsub(/,/," ");n=split($0,a,/[[:space:]]+/);j=0;for(i=1;i<=n;i++){if(split(a[i],r,"-")>1){for(v=r[1];v<=r[2];v++)if(!s[v]++)nums[++j]=v+0}else if(a[i]!=""&&!s[i]++){nums[++j]=a[i]+0}}for(i=1;i<j;i++){min=i;for(k=i+1;k<=j;k++)if(nums[k]<nums[min])min=k;if(min!=i){t=nums[i];nums[i]=nums[min];nums[min]=t}}for(i=1;i<=j;i++)printf "%s%s",nums[i],(i==j?"":" ");}'
[ -n "$e_core" ] && { _e_h=true; e_core=$(echo "$e_core" | awk "$_clean_cmd"); } || _scan=1
[ -n "$p_core" ] && { _p_h=true; p_core=$(echo "$p_core" | awk "$_clean_cmd"); } || _scan=1
[ -n "$hp_core" ] && { _hp_h=true; hp_core=$(echo "$hp_core" | awk "$_clean_cmd"); } || _scan=1
[ -n "$all_core" ] && { _a_h=true; all_core=$(echo "$all_core" | awk "$_clean_cmd"); } || _scan=1
if [ "$_scan" -eq 1 ]; then
_groups=$(for policy in /sys/devices/system/cpu/cpufreq/policy*
 do
	[ -d "$policy" ] || continue
		cpus=$(cat "$policy/related_cpus" 2>/dev/null)
		freq=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
		[ -z "$cpus" ] || [ -z "$freq" ] && continue
	echo "$freq:$cpus"
done | sort -n -t: -k1,1 | awk -F: '$1==p{c=c" "$2;next} p!=""{print p":"c} {p=$1;c=$2} END{if(p!="")print p":"c}'
)
eval "$(echo "$_groups" | awk -F: -v eh=$_e_h -v ph=$_p_h -v hph=$_hp_h '
BEGIN { e_c=""; p_c=""; hp_c=""; e_f=0; p_f=0; hp_f=0; n=0 }
{ f[++n]=$1; c[n]=$2 }
END {
if (n==0) exit
e_c=c[1]; e_f=f[1]
if (n>=2) { hp_c=c[n]; hp_f=f[n] }
if (n>=3) {
for (i=2; i<n; i++) {
p_c=p_c (p_c==""?"":" ") c[i]
if (f[i]>p_f) p_f=f[i]
}
}
if (eh=="false") printf "e_core=\"%s\"; e_core_freq=%d; ", e_c, e_f
if (ph=="false" && n>=3) printf "p_core=\"%s\"; p_core_freq=%d; ", p_c, p_f
if (hph=="false" && n>=2) printf "hp_core=\"%s\"; hp_core_freq=%d; ", hp_c, hp_f
printf "total_groups=%d;", n
}')"
	[ "$_a_h" = "false" ] && all_core="$(cat /sys/devices/system/cpu/present 2>/dev/null | awk "$_clean_cmd")"
fi
	unset _e_h _p_h _hp_h _a_h _scan _groups _clean_cmd
}

format_cpu_ranges() {
if [ -z "$(printf '%s' "${1}" | tr -d '[:space:]')" ]; then
	cat /sys/devices/system/cpu/present 2>/dev/null
	return
fi
echo "${1}" | awk '{
gsub(/,/, " ")
n=split($0, arr, /[[:space:]]+/)
j=0
for (i=1; i<=n; i++) {
if (split(arr[i], r, "-") > 1) {
for (v=r[1]; v<=r[2]; v++) if (!seen[v]++) nums[++j]=v+0
} else if (arr[i]!="" && !seen[arr[i]]++) {
nums[++j]=arr[i]+0
}
}
if (j==0) exit
for (i=1; i<j; i++) {
min=i
for (k=i+1; k<=j; k++) if (nums[k]<nums[min]) min=k
if (min!=i) { t=nums[i]; nums[i]=nums[min]; nums[min]=t }
}
start=last=nums[1]; sep=""
for (i=2; i<=j; i++) {
if (nums[i]==last+1) { last=nums[i]; continue }
printf "%s%s", sep, (start==last?start:start"-"last)
sep=","; start=last=nums[i]
}
printf "%s%s", sep, (start==last?start:start"-"last)
}'
}

Delete_Game_Config(){
local target_file="${1}"
if [ -f "${target_file}" ] ;then
	sed -i '/^#游戏$/,/^#游戏END$/d' "${target_file}"
	sed -i 's/[[:space:]]$//g;/^[[:space:]]*$/N;/\n$/d' "${target_file}"
fi
}

Delete_Comm_Config(){
local target_file="${1}"
if [ -f "${target_file}" ] ;then
	sed -i '/^#日用应用$/,/^#日用应用END$/d' "${target_file}"
	sed -i 's/[[:space:]]$//g;/^[[:space:]]*$/N;/\n$/d' "${target_file}"
fi
}

Delete_System_Config(){
local target_file="${1}"
if [ -f "${target_file}" ] ;then
	sed -i '/^#系统进程$/,/^#系统进程END$/d' "${target_file}"
	sed -i 's/[[:space:]]$//g;/^[[:space:]]*$/N;/\n$/d' "${target_file}"
fi
}

#定义规则文件
[ ! -d "${MODPATH}" ] && Scripts_DIR="${0%/*}" && MODPATH="${Scripts_DIR%/*}"
Rules_file="${MODPATH}/applist.prop"
[ -f "${Rules_file%/*}/applist.conf" ] && Rules_file="${MODPATH}/applist.conf"

# ---------- format_cpu_ranges函数原版用法 ---------
# format_cpu_ranges函数用法：
# $(format_cpu_ranges "$e_core")           表示能效小核
# $(format_cpu_ranges "$p_core")           表示性能中核
# $(format_cpu_ranges "$hp_core")          为高性能大核
# 也可以组合一起用：
# $(format_cpu_ranges "$e_core $p_core")  为小核与中核
# $(format_cpu_ranges "$p_core $hp_core") 为中核与大核
# ---------- 原版用法如上面 ---------

#可以自定义CPU范围
#没有定义的情况下，由init_cpu_vars函数补充
#我只初步试了一下，复杂情况下，没做特别测试
# 这里的 可以写hp_core="6 7"
# 也可以写hp_core="6-7"/hp_core="6,7"
# 如果是 8E你认为不需要双超大核
# 那么就定义 p_core="6" 游戏的时候再写
# format_cpu_ranges "${hp_core} $(($hp_core + 1))"
# 6 6+1 也就是=6-7
# 我也不知道这有什么用，感觉没啥用
#不懂自定义，最好用init_cpu_vars初始化
#e_core="0-1"
#p_core="2-6"
#hp_core="7"
#初始化CPU
init_cpu_vars

# ------ Android的mksh的 # % 用法-------
# 首先要以 "${}" 包裹变量才能进行运算
# ##* 代表：从左侧开始，删除最长匹配（即保留最后一个元素）
# %% *代表：从右侧开始，删除最长匹配（即保留第一个元素）
# #* 代表：从左侧开始，删除最短匹配（即删掉第一个元素，保留剩下的）
# % *代表：从右侧开始，删除最短匹配（即删掉最后一个元素，保留剩下的）
# 以 e_core="0 1 2 3 4" 为例：
# "${e_core##* }" 结果为 "4" (获取最后一个核心)
# "${e_core%% *}" 结果为 "0" (获取第一个核心)
# "${e_core#* }"  结果为 "1 2 3 4" (去掉第一个，保留后续)
# "${e_core% *}"  结果为 "0 1 2 3" (去掉最后一个，保留前面)

# 实际场景示例：
# 如果 hp_core="6 7"，想取其中一个核心：
# first_hp="${hp_core%% *}"  # 得到 6
# last_hp="${hp_core##* }"   # 得到 7


#如果是6+2核心配置是没有性能核心(或者说性能核心会被脚本判断成能效核心e_core)的
#这里我们定义一下也就是e_core="0 1 2 3 4 5"取最后一个5，然后用shell内置的加减运算，5-2=3
#最后p_core=6 3 4 5 6
[ -z "${p_core}" ] && p_core="${hp_core%% *} $((${e_core##* } -2)) $((${e_core##* } -1)) ${e_core##* } ${hp_core%% *}"
#高性能核心
high_performance_core=$(format_cpu_ranges "${hp_core}")
#性能核心
performance_core=$(format_cpu_ranges "${p_core}")
#能效核心
efficiency_core=$(format_cpu_ranges "${e_core}")
#所有核心
All_CORES=$(format_cpu_ranges "${all_core}")

#预设线程核心
#多线程计算/高性能负载
#使用大核+超大核，降低功耗，处理速度稍差
#但是功耗比单超大核降低会很多
mix_high_performance_core=$(format_cpu_ranges "${p_core} ${hp_core}")
#小核可以应对的重要线程+可能需要处理突发的性能需求核心
low_utilization_core=$(format_cpu_ranges "${e_core} ${p_core%% *}")
#需要多核心繁重运算的线程
mix_all_core_base="${all_core#* }"
mix_all_core=$(format_cpu_ranges "${mix_all_core_base#* }")
#需要多核心运算并且可以不用超大核的线程
mix_all_low_core_base="${mix_all_core_base#* }"
mix_all_low_core=$(format_cpu_ranges "${mix_all_low_core_base% *}")
#消息进程，避免占用其他核心
massage_push_core=$(format_cpu_ranges "${e_core%%* } $((${e_core%% *} + 1))")
#异常(垃圾)线程，避免占用大核和超大核，导致无故卡顿和发热
low_priority_task_core=$(format_cpu_ranges "$((${e_core%% *} + 1))" )
#日用App其他线程核心
Comm_App_core=$(format_cpu_ranges "${e_core} ${p_core}")
#游戏其他线程核心
Game_core=$(format_cpu_ranges "${e_core} ${p_core% *}")
#适配2+3+2+1(8gen3)的核心，打游戏时，小核用处不大
[ "$total_groups" -ge "3" -a "$(echo "$p_core" | wc -w)" -ge "5" ] && Game_core="$(format_cpu_ranges "${p_core}")"
