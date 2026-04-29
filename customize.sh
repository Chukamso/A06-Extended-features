#!/system/bin/sh

ui_print "a06_ble v4 by alphanox87"
ui_print ">Editing Kernel values"
sleep 5
ui_print "Give us a second"
sleep 5
ui_print ">Inputting .prop files"
sleep 3

ui_print ">Injecting Debloat Script"
ui_print "(effects will be made after Reboot)"
sleep 3



MY_APK2="$MODPATH/display_assistant_7.apk"

# Check if the file exists
if [ -f "$MODPATH/display_assistant_7.apk" ]; then
    
     
    pm install -r -d "$MY_APK2"
    
    ui_print "- component install successful!"
else
    ui_print "! ERROR: display_assistant not found in module root modpath"
    ui_print "! Please ensure the file is in the root of your zip."
fi

# Function to detect volume button (extracted from magisk template)
chooseport() {
  while true; do
    getevent -lc 1 2>&1 | grep VOLUME | grep " DOWN" > "$TMPDIR/events"
    if $(cat "$TMPDIR/events" 2>/dev/null | grep -q VOLUMEUP); then
      return 0
    elif $(cat "$TMPDIR/events" 2>/dev/null | grep -q VOLUMEDOWN); then
      return 1
    fi
  done
}

ui_print "this will apply immediately to the current session"
sleep 5
ui_print " >Reduce resolution to 620x1377 @ 248 DPI?"
ui_print " >Better performance for gaming and less UI stutters"
ui_print " "
ui_print "Vol+ = YES, reduce resolution"
ui_print "Vol- = NO, keep native resolution"
ui_print " "

if chooseport; then
  ui_print "→ Reducing resolution..."
  wm size 620x1377
  wm density 248
  ui_print "→ Resolution set to 620x1377 @ 248 DPI"
else
  ui_print "→ Native resolution kept"
fi

ui_print "  Kernel SE mode"
ui_print "  Do you want to change SELinux mode?"
ui_print "  Vol+ = YES  |  Vol- = NO (leave as is)"

if chooseport; then
    ui_print "  Select SELinux mode:"
    ui_print "  Vol+ = Permissive  |  Vol- = Enforcing"
    if chooseport; then
        ui_print "> Permissive kernel selected "
        echo "setenforce 0" >> "$MODPATH/service.sh"
        FEATURE_SET="A"
    else
        ui_print "> Enforcing selected "
        echo "setenforce 1" >> "$MODPATH/service.sh"
        FEATURE_SET="B"
    fi
else
    ui_print "[*] SELinux mode left unchanged "
    FEATURE_SET="C"
fi

ui_print " >Finalizing changes"
ui_print ""
ui_print " >leave ur device idle for 2 minutes after initial reboot, and the reboot again, "
ui_print " >after that it may take a couple for u to feel the UI responsivness and lack of stutters."
sleep 7

ui_print "0x0 Script run complete"
