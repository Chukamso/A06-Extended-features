#!/system/bin/sh

#Layer 1: 10s
sleep 10
ALL_PACKAGES=$(pm list packages -s | cut -d: -f2)
for pkg in $ALL_PACKAGES; do
    cmd package install-existing "$pkg" >/dev/null 2>&1
done

#Layer 2: 30s
sleep 30
for pkg in $ALL_PACKAGES; do
    cmd package install-existing "$pkg" >/dev/null 2>&1
done

#Layer 3: 40s
sleep 40
for pkg in $ALL_PACKAGES; do
    cmd package install-existing "$pkg" >/dev/null 2>&1
done

# rebloat cycle finished in 80 seconds.

pm enable com.google.android.gms/.measurement.AppMeasurementService
pm enable com.google.android.gms/.measurement.AppMeasurementJobService
pm enable com.google.android.gms/.tron.CollectionService
pm enable com.google.android.gms/.measurement.service.MeasurementBrokerService
pm enable com.google.android.gms/.dtdi.lifecycle.LifecycleService
pm enable com.google.android.gms/.fitness.sync.FitnessSyncAdapterService
pm enable com.google.android.gms/.location.reporting.service.ReportingSyncService

#Clean up  log files
[ -f "/data/local/tmp/A06-EF.log" ] && rm -f "/data/local/tmp/A06-EF.log"
[ -f "/data/local/tmp/.tweaks_applied" ] && rm -f "/data/local/tmp/.tweaks_applied"