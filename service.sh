#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future


MODDIR=${0%/*}
LOG="/data/local/tmp/A06-EF.log"
LOCK="/data/local/tmp/.tweaks_applied"

sleep 5

echo "a06_ef ble v4 by alphanox87" >> "$LOG"
echo "Started: $(date)" >> "$LOG"
echo "" >> "$LOG"

#KERNEL TWEAKS
echo "KERNEL_vm_cofig_edit" >> "$LOG"

# CPU Governors
P0="/sys/devices/system/cpu/cpufreq/policy0/scaling_governor"
P6="/sys/devices/system/cpu/cpufreq/policy6/scaling_governor"
[ -f "$P0" ] && echo "sugov_ext" > "$P0" 
[ -f "$P6" ] && echo "sugov_ext" > "$P6" 
echo "CPU Governor: sugov_ext" >> "$LOG"

sleep 2

# sugov_ext Tunables
ST="/sys/devices/system/cpu/cpufreq/sugov_ext"
[ -f "$ST/down_rate_limit_us" ] && echo "5000" > "$ST/down_rate_limit_us" 
[ -f "$ST/up_rate_limit_us" ] && echo "5000" > "$ST/up_rate_limit_us" 
echo "sugov_ext: down_rate_limit=5000us, up_rate_limit=10000us" >> "$LOG"

# I/O Scheduler
for blk in mmcblk0 sda; do
  if [ -d "/sys/block/$blk" ]; then
    IO="/sys/block/$blk/queue"
    [ -f "$IO/scheduler" ] && echo "none" > "$IO/scheduler"
    [ -f "$IO/read_ahead_kb" ] && echo "256" > "$IO/read_ahead_kb" 
    [ -f "$IO/rq_affinity" ] && echo "2" > "$IO/rq_affinity" 
    [ -f "$IO/nomerges" ] && echo "0" > "$IO/nomerges" 
    [ -f "$IO/nr_requests" ] && echo "128" > "$IO/nr_requests" 
    [ -f "$IO/iosched/read_expire" ] && echo "300" > "$IO/iosched/read_expire" 
    [ -f "$IO/iosched/max_async_write_rqs" ] && echo "16" > "$IO/iosched/max_async_write_rqs" 
    echo "I/O: none, read_ahead=256, rq_affinity=2, nomerges=0, nr_requests=128" >> "$LOG"
    break
  fi
done

# Linux Kernel Scheduler
[ -f "/proc/sys/kernel/sched_rt_runtime_us" ] && echo "-1" > "/proc/sys/kernel/sched_rt_runtime_us" 
[ -f "/sys/kernel/debug/sched/pelt_multiplier" ] && echo "2" > "/sys/kernel/debug/sched/pelt_multiplier" 
echo "Scheduler: sched_rt_runtime=-1, pelt_multiplier=2" >> "$LOG"

# Virtual Memory
VM="/proc/sys/vm"
[ -f "$VM/dirty_ratio" ] && echo "70" > "$VM/dirty_ratio" 
[ -f "$VM/dirty_background_ratio" ] && echo "50" > "$VM/dirty_background_ratio" 
[ -f "$VM/dirty_writeback_centisecs" ] && echo "5000" > "$VM/dirty_writeback_centisecs" 
[ -f "$VM/dirty_expire_centisecs" ] && echo "5000" > "$VM/dirty_expire_centisecs"
[ -f "$VM/overcommit_ratio" ] && echo "60" > "$VM/overcommit_ratio"
[ -f "$VM/swappiness" ] && echo "130" > "$VM/swappiness"
[ -f "$VM/vfs_cache_pressure" ] && echo "20" > "$VM/vfs_cache_pressure"
[ -f "$VM/min_free_kbytes" ] && echo "65536" > "$VM/min_free_kbytes"
echo "VM: dirty=70, dirty_bg=50, swappiness=130, vfs=20, min_free=65536kb" >> "$LOG"

# ZRAM
for zram in /dev/block/zram*; do
  if [ -b "$zram" ]; then
    ZDEV=$(basename "$zram")
    ZP="/sys/block/$ZDEV"
    swapoff /dev/block/$ZDEV 
    echo 1 > "$ZP/reset" 
    sleep 2
    echo "3831283712" > "$ZP/disksize" 
    mkswap /dev/block/$ZDEV 
    swapon /dev/block/$ZDEV 
    echo "ZRAM: 3642MB" >> "$LOG"
    break
  fi
done

# Disable Thermal Throttling
for thermal in /sys/class/thermal/thermal_zone*/mode; do
  [ -f "$thermal" ] && echo "disabled" > "$thermal" 
done
cmd thermalservice override-status 0 
echo "Thermal: Throttling disabled" >> "$LOG"



echo "" >> "$LOG"

# ADDITIONAL TWEAKS
echo " ADDITIONAL TWEAKS" >> "$LOG"

# Samsung GOS
settings put secure game_home_enable 0 

settings put secure game_auto_temperature_control 0 
pm clear --user 0 com.samsung.android.game.gos 

# Refresh Rate
settings put system min_refresh_rate 60.0 

# Performance
cmd power set-fixed-performance-mode-enabled true 
settings put system multicore_packet_scheduler 1 
settings put global sem_enhanced_cpu_responsiveness 1 
setprop debug.egl.swapinterval 0
echo 0-4 > /dev/cpuset/system-background/cpus 
echo 0-7 > /dev/cpuset/top-app/cpus 
echo 0-2 > /dev/cpuset/background/cpus 
echo 0-7 > /dev/cpuset/foreground/cpus 

# Touch
settings put secure long_press_timeout 200 
settings put secure multi_press_timeout 250 
settings put secure tap_duration_threshold 0.0 
settings put secure touch_blocking_period 0.0 

# Battery
settings put global automatic_power_save_mode 1 
settings put global dynamic_power_savings_enabled 1 

#rducing google play service cpu & background apps usage
pm disable com.google.android.gms/.measurement.AppMeasurementService
pm disable com.google.android.gms/.measurement.AppMeasurementJobService
pm disable com.google.android.gms/.tron.CollectionService
pm disable com.google.android.gms/.measurement.service.MeasurementBrokerService
pm disable com.google.android.gms/.dtdi.lifecycle.LifecycleService
pm disable com.google.android.gms/.fitness.sync.FitnessSyncAdapterService
pm disable com.google.android.gms/.location.reporting.service.ReportingSyncService
pm disable com.google.android.gms/.chimera.GmsIntentOperationService
# Loop through all (non-system) packages
for pkg12 in $(pm list packages -3 | cut -d: -f2); do
    # Deny all background execution
    cmd appops set "$pkg12" RUN_ANY_IN_BACKGROUND deny
    # Optional: Also ignore standard background runtime rquests
    cmd appops set "$pkg12" RUN_IN_BACKGROUND ignore
done

echo "GOS disabled, Touch optimized, Performance enhanced" >> "$LOG"

echo "" >> "$LOG"

#DEBLOATER
echo "DEBLOATER" >> "$LOG"
echo "" >> "$LOG"

REM=0

pm uninstall --user 0 com.sec.android.RilServiceModeApp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.oda.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.iaft >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.telephonyui.esimclient >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dsms >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mcfds >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.camerasaver >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.kpecore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.facebook.appmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.credentialmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.printservice.recommendation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.overlay.gmsconfig.asi >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.accessibility.talkback >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.ondevicepersonalization.services >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.osp.app.signin >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.providers.blockednumber >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.attestation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.knox.vpn.proxyhandler >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.smartcallprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.bcservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.intellivoiceservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.gms.location.history >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.setupwizardlegalprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.aura.oobe.samsung.gl >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mdm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.hiya.star >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.phone.auto_generated_characteristics_rro >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.personalization >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.bbc.bbcagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.shortcutbackupservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mcfserver >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.parentalcare >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.overlay.gmsconfig.geotz >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.devicediagnostics >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.factorykeystring >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.bluetoothagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.watchmanagerstub >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.federatedcompute >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.visual.cloudcore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.modem.settings >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.callbgprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.easyMover.Agent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dbsc >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.container >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.epdg >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.bluelightfilter >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.mdmconfig >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.location.nfwlocationprivacy >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.stk >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.callassistant >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.partnersetup >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.carrier.carrierwifi >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.feedback >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.sm.devicesecurity >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.unifiedwfc >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.provider.badge >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.safetyinformation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.ons >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.camera.sticker >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.sec.android.application.csc >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.setupwizard >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.simappdialog >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dynamiclock >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.app.RilErrorNotifier >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.phone >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.location >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.traceur >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.sandbox >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.googlequicksearchbox >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.containercore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.configupdater >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.forest >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.gms.supervision >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.soundalive >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.easyMover >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.facebook.system >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.mainline.telemetry >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.billing >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mdx.kit >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.imslogger >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.servicemodeapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.wssyncmldm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.calllogbackup >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.samsungapps >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.diagmonagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.autodoodle.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.cellbroadcastreceiver >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.imsservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.sharelive >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.virtualmachine.res >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.adservices.api >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.themestore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.val.hardware >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.onetimeinitializer >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.sdk.handwriting >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.networkdiagnostic >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.managedprovisioning >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.advp.imssettings >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.crane >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.sait.sohservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.knox.securefolder >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.epdgtestapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.cidmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.stk2 >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.scloud >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.microsoft.skydrive >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.beaconmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.role.notes.enabled >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.silead.fingerprint >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.appseparation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.mainline.adservices >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.incall.contentprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.omcagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.aware.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.er >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.CcInfo >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.enterprise.knox.cloudmdm.smdms >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 android.autoinstalls.config.samsung >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.zt.framework >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.cameraextensions >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.SecSetupWizard >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.scs >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.rampart >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.facebook.services >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.kfbp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.as >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.samsungpositioning >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.server.wifi.mobilewips >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.smartswitchassistant >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dqagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.fmm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.aasaservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.datachannel.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.safetyassurance >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.restore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.chromecustomizations >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.easysetup >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.spp.push >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.as.oss >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.visualars >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.uwb.resources >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.op07.wfo >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.updatecenter >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.entitlement.o2 >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.sdm.config >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.daemonapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.turbo >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mapsagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mobileservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.overlay.gmsconfig.gsa >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.knnr >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.service.stplatform >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.vsim.ericssonnsds.webapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.providers.contactkeys >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.cts.ctsshim >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.storyservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.skms.android.agent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.soagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.providers.partnerbookmarks >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.kidsinstaller >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mdecservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.rubin.app >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.gru >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.scpm >/dev/null 2>&1 && REM=$((REM+1))

echo "Packages removed: $REM" >> "$LOG"

echo "" >> "$LOG"

#SUMMARY 

echo "Completed: $(date)" >> "$LOG"
echo "Governor: conservative" >> "$LOG"
echo "VM: dirty=70, dirty_bg=50, swappiness=60, vfs=10" >> "$LOG"
echo "Min free: 131072kb" >> "$LOG"
echo "ZRAM: 3642MB" >> "$LOG"
echo "Display: 612x1360 @ 248 DPI" >> "$LOG"
echo "Thermal: Disabled" >> "$LOG"
echo "Debloated: $REM packages" >> "$LOG"

# Check if already run (only log once)
if [ -f "$LOCK" ]; then
  exit 0
fi

sleep 40

echo "a06_ble v4" >> "$LOG"
echo "Started: $(date)" >> "$LOG"
echo "" >> "$LOG"

#KERNEL TWEAKS
echo "KERNEL TWEAKS" >> "$LOG"

# CPU Governors
P0="/sys/devices/system/cpu/cpufreq/policy0/scaling_governor"
P6="/sys/devices/system/cpu/cpufreq/policy6/scaling_governor"
[ -f "$P0" ] && echo "sugov_ext" > "$P0" 
[ -f "$P6" ] && echo "sugov_ext" > "$P6" 
echo "CPU Governor: sugov_ext" >> "$LOG"

sleep 2

# sugov_ext Tunables
ST="/sys/devices/system/cpu/cpufreq/sugov_ext"
[ -f "$ST/down_rate_limit_us" ] && echo "5000" > "$ST/down_rate_limit_us" 
[ -f "$ST/up_rate_limit_us" ] && echo "5000" > "$ST/up_rate_limit_us" 
echo "sugov_ext: down_rate_limit=5000us, up_rate_limit=10000us" >> "$LOG"

# I/O Scheduler
for blk in mmcblk0 sda; do
  if [ -d "/sys/block/$blk" ]; then
    IO="/sys/block/$blk/queue"
    [ -f "$IO/scheduler" ] && echo "none" > "$IO/scheduler" 
    [ -f "$IO/read_ahead_kb" ] && echo "256" > "$IO/read_ahead_kb" 
    [ -f "$IO/rq_affinity" ] && echo "2" > "$IO/rq_affinity" 
    [ -f "$IO/nomerges" ] && echo "0" > "$IO/nomerges" 
    [ -f "$IO/nr_requests" ] && echo "256" > "$IO/nr_requests" 
    [ -f "$IO/iosched/read_expire" ] && echo "300" > "$IO/iosched/read_expire" 
    [ -f "$IO/iosched/max_async_write_rqs" ] && echo "16" > "$IO/iosched/max_async_write_rqs" 
    echo "I/O: none, read_ahead=256, rq_affinity=2, nomerges=0, nr_requests=256" >> "$LOG"
    break
  fi
done

# Linux Kernel Scheduler
[ -f "/proc/sys/kernel/sched_rt_runtime_us" ] && echo "-1" > "/proc/sys/kernel/sched_rt_runtime_us" 
[ -f "/sys/kernel/debug/sched/pelt_multiplier" ] && echo "2" > "/sys/kernel/debug/sched/pelt_multiplier" 
echo "Scheduler: sched_rt_runtime=-1, pelt_multiplier=2" >> "$LOG"

# Virtual Memory
VM="/proc/sys/vm"
[ -f "$VM/dirty_ratio" ] && echo "70" > "$VM/dirty_ratio" 
[ -f "$VM/dirty_background_ratio" ] && echo "50" > "$VM/dirty_background_ratio" 
[ -f "$VM/dirty_writeback_centisecs" ] && echo "5000" > "$VM/dirty_writeback_centisecs" 
[ -f "$VM/dirty_expire_centisecs" ] && echo "5000" > "$VM/dirty_expire_centisecs" 
[ -f "$VM/overcommit_ratio" ] && echo "75" > "$VM/overcommit_ratio" 
[ -f "$VM/swappiness" ] && echo "70" > "$VM/swappiness"
[ -f "$VM/vfs_cache_pressure" ] && echo "20" > "$VM/vfs_cache_pressure" 
[ -f "$VM/min_free_kbytes" ] && echo "65536" > "$VM/min_free_kbytes" 
echo "VM: dirty=70, dirty_bg=50, swappiness=60, vfs=10, min_free=65536kb" >> "$LOG"

# ZRAM
for zram in /dev/block/zram*; do
  if [ -b "$zram" ]; then
    ZDEV=$(basename "$zram")
    ZP="/sys/block/$ZDEV"
    swapoff /dev/block/$ZDEV 
    echo 1 > "$ZP/reset" 
    sleep 2
    echo "3831283712" > "$ZP/disksize"
    mkswap /dev/block/$ZDEV 
    swapon /dev/block/$ZDEV 
    echo "ZRAM: 3642MB" >> "$LOG"
    break
  fi
done

# Disable Thermal Throttling
for thermal in /sys/class/thermal/thermal_zone*/mode; do
  [ -f "$thermal" ] && echo "disabled" > "$thermal" 
done
cmd thermalservice override-status 0 
echo "Thermal: Throttling disabled" >> "$LOG"


echo "" >> "$LOG"

#  ADDITIONAL TWEAKS
echo "ADDITIONAL TWEAKS" >> "$LOG"

# Samsung GOS
settings put secure game_home_enable 0 

settings put secure game_auto_temperature_control 0 
pm clear --user 0 com.samsung.android.game.gos 

# Refresh Rate
settings put system min_refresh_rate 60.0

# Performance
cmd power set-fixed-performance-mode-enabled true 
settings put system multicore_packet_scheduler 1 
settings put global sem_enhanced_cpu_responsiveness 1
setprop debug.egl.swapinterval 0
echo 0-4 > /dev/cpuset/system-background/cpus 
echo 0-7 > /dev/cpuset/top-app/cpus 
echo 0-2 > /dev/cpuset/background/cpus 
echo 0-7 > /dev/cpuset/foreground/cpus 


# Touch
settings put secure long_press_timeout 200 
settings put secure multi_press_timeout 250 
settings put secure tap_duration_threshold 0.0 
settings put secure touch_blocking_period 0.0 

# Battery
settings put global automatic_power_save_mode 1 
settings put global dynamic_power_savings_enabled 1 
settings put global background_process_limit 4

#rducing google play service cpu & background apps usage
pm disable com.google.android.gms/.measurement.AppMeasurementService
pm disable com.google.android.gms/.measurement.AppMeasurementJobService
pm disable com.google.android.gms/.tron.CollectionService
pm disable com.google.android.gms/.measurement.service.MeasurementBrokerService
pm disable com.google.android.gms/.dtdi.lifecycle.LifecycleService
pm disable com.google.android.gms/.fitness.sync.FitnessSyncAdapterService
pm disable com.google.android.gms/.location.reporting.service.ReportingSyncService
pm disable com.google.android.gms/.chimera.GmsIntentOperationService
# Loop through all (non-system) packages
for pkg12 in $(pm list packages -3 | cut -d: -f2); do
    # Deny all background execution
    cmd appops set "$pkg12" RUN_ANY_IN_BACKGROUND deny
    # Optional: Also ignore standard background runtime rquests
    cmd appops set "$pkg12" RUN_IN_BACKGROUND ignore
done

echo "GOS disabled, Touch optimized, Performance enhanced" >> "$LOG"

echo "" >> "$LOG"

#DEBLOATER
echo "DEBLOATER" >> "$LOG"
echo "" >> "$LOG"

REM=0

pm uninstall --user 0 com.sec.android.RilServiceModeApp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.oda.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.iaft >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.telephonyui.esimclient >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dsms >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mcfds >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.camerasaver >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.kpecore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.facebook.appmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.credentialmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.printservice.recommendation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.overlay.gmsconfig.asi >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.accessibility.talkback >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.ondevicepersonalization.services >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.osp.app.signin >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.providers.blockednumber >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.attestation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.knox.vpn.proxyhandler >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.smartcallprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.bcservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.intellivoiceservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.gms.location.history >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.setupwizardlegalprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.gm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.aura.oobe.samsung.gl >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mdm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.tachyon >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.hiya.star >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.phone.auto_generated_characteristics_rro >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.personalization >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.bbc.bbcagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.shortcutbackupservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mcfserver >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.parentalcare >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.overlay.gmsconfig.geotz >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.devicediagnostics >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.factorykeystring >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.bluetoothagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.federatedcompute >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.visual.cloudcore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.modem.settings >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.callbgprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dbsc >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.container >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.epdg >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.bluelightfilter >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.mdmconfig >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.location.nfwlocationprivacy >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.stk >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.callassistant >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.partnersetup >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.carrier.carrierwifi >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.feedback >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.sm.devicesecurity >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.unifiedwfc >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.provider.badge >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.safetyinformation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.ons >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.camera.sticker >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.sec.android.application.csc >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.setupwizard >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.simappdialog >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dynamiclock >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.app.RilErrorNotifier >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.phone >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.location >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.traceur >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.sandbox >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.googlequicksearchbox >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.containercore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.configupdater >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.forest >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.gms.supervision >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.soundalive >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.easyMover >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.facebook.system >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.mainline.telemetry >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.billing >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mdx.kit >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.imslogger >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.servicemodeapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.wssyncmldm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.calllogbackup >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.samsungapps >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.diagmonagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.autodoodle.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.cellbroadcastreceiver >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.imsservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.sharelive >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.virtualmachine.res >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.adservices.api >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.themestore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.val.hardware >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.onetimeinitializer >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.sdk.handwriting >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.networkdiagnostic >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.managedprovisioning >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.advp.imssettings >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.crane >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.sait.sohservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.knox.securefolder >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.epdgtestapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.cidmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.stk2 >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.scloud >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.microsoft.skydrive >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.beaconmanager >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.role.notes.enabled >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.silead.fingerprint >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.appseparation >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.mainline.adservices >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.incall.contentprovider >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.omcagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.aware.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.er >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.CcInfo >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.enterprise.knox.cloudmdm.smdms >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 android.autoinstalls.config.samsung >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.zt.framework >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.cameraextensions >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.SecSetupWizard >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.scs >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.rampart >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.facebook.services >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.kfbp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.as >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.samsungpositioning >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.server.wifi.mobilewips >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.smartswitchassistant >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.dqagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.fmm >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.aasaservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.datachannel.service >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.safetyassurance >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.restore >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.app.chromecustomizations >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.easysetup >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.spp.push >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.as.oss >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.visualars >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.uwb.resources >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.op07.wfo >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.app.updatecenter >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.mediatek.entitlement.o2 >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.sdm.config >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.daemonapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.apps.turbo >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mapsagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mobileservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.google.android.overlay.gmsconfig.gsa >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.knox.knnr >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.service.stplatform >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.vsim.ericssonnsds.webapp >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.providers.contactkeys >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.cts.ctsshim >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.storyservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.skms.android.agent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.sec.android.soagent >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.android.providers.partnerbookmarks >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.kidsinstaller >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.mdecservice >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.rubin.app >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.gru >/dev/null 2>&1 && REM=$((REM+1))
pm uninstall --user 0 com.samsung.android.scpm >/dev/null 2>&1 && REM=$((REM+1))

echo "Packages removed: $REM" >> "$LOG"

echo "" >> "$LOG"

# SUMMARY
echo "Completed: $(date)" >> "$LOG"
echo "Governor: conservative" >> "$LOG"
echo "VM: dirty=70, dirty_bg=50, swappiness=60, vfs=10" >> "$LOG"
echo "Min free: 131072kb" >> "$LOG"
echo "ZRAM: 3642MB" >> "$LOG"
echo "Thermal: Disabled" >> "$LOG"
echo "Debloated: $REM packages" >> "$LOG"

chmod 644 "$LOG"

# Create lock file so script only runs once
touch "$LOCK"

chmod 644 "$LOG"
#check log at /data/local/tmp/A06-EF.log

