wait_screen_wakeup(){
local number=3
until [ "$(dumpsys deviceidle get screen 2>/dev/null )" = "true" ] || [ "${number}" -le "0" ] && [ "$(getprop sys.boot_completed)" = "1" ] && [ -d "/data/user/0/android" ]
do
	number=$((number-1))
	sleep 30
done
}

modtify_system_prop_file(){
wait_screen_wakeup
[ ! -d "${MODPATH}" ] && Scripts_DIR="${0%/*}" && MODPATH="${Scripts_DIR%/*}"
prop_file="$MODPATH/system.prop"
[ -f "$prop_file" ] && resetprop --file "$prop_file"
}

if [ "$(getprop sys.boot_completed)" = "1" ] && [ -d "/data/user/0/android" ] ;then
	modtify_system_prop_file
else
	(modtify_system_prop_file &)
fi
