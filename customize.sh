SKIPUNZIP=0
check_required_files() {
	REQUIRED_FILE_LIST="/sys/devices/system/cpu/present"
	for REQUIRED_FILE in $REQUIRED_FILE_LIST; do
		if [ ! -e $REQUIRED_FILE ]; then
			ui_print "**************************************************"
			ui_print "! $REQUIRED_FILE 文件不存在"
			ui_print "! 请联系模块作者"
			abort    "**************************************************"
		fi
	done
}

. "$MODPATH/Aloazny.sh"
check_required_files

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/*.sh" 0 2000 0755 0755
set_perm_recursive "$MODPATH/Scripts/*.sh" 0 2000 0755 0755
set_perm_recursive "$MODPATH/AppOpt" 0 2000 0755 0755
