export PATH="${PATH}:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"
if command -v busybox >/dev/null 2>&1; then
    awk() { busybox awk "$@"; }
    sed() { busybox sed "$@"; }
    chattr() { busybox chattr "$@"; }
fi
[ ! -d "${MODPATH}" ] && Scripts_DIR="${0%/*}" && MODPATH="${Scripts_DIR%/*}"
evil_folder="${MODPATH}/system/priv-apk"
[ ! -d "${evil_folder}" ] && evil_folder="${MODPATH}/system/priv-app"
[ -d "${evil_folder}" ] && rm -rf "${evil_folder}"

#病毒包名
evil_package_name="
com.android.append
bin.mt.plus.termex
"

for pkg in $evil_package_name
do
if [ "$(cmd package list package -a | grep "$pkg")" != "" ];then
	chattr -R -i -a /data/adb
	package_system_path="$(dumpsys package "$pkg" | sed -E '/([Rr]esource|[Cc]ode)[Pp]ath=/!d;s/([Rr]esource|[Cc]ode)[Pp]ath=(\/.*)/\2/g;s/[[:space:]]//g' )"
	iptables -A OUTPUT -m string --string "fdkss.sbs" --algo bm --to 65535 -j DROP >/dev/null 2>&1
	cmd package disable "${pkg}" >/dev/null 2>&1
	cmd package hide "${pkg}" >/dev/null 2>&1
	cmd package suspend "${pkg}" >/dev/null 2>&1
	cmd package uninstall --user 0 "${pkg}" >/dev/null 2>&1
for i in $package_system_path
	do
case "$i" in
/system*) rm -rf /data/adb/modules/*"${i}" ;;
/data*) rm -rf "${i}" ;;
esac
	done
fi
done



