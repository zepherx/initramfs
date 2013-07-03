#!/sbin/busybox sh
# Logging
#/sbin/busybox cp /data/user.log /data/user.log.bak
#/sbin/busybox rm /data/user.log
#exec >>/data/user.log
#exec 2>&1

#!/sbin/busybox sh

if [ -f /data/bkp.profile ]; then
chown root.system /data/bkp.profile
chmod 0777 /data/bkp.profile
fi

mkdir /data/.siyah
chmod 0777 /data/.siyah

. /res/customconfig/customconfig-helper

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a${ccxmlsum}" != "a`cat /data/.siyah/.ccxmlsum`" ];
then
  rm -f /data/.siyah/*.profile
  echo ${ccxmlsum} > /data/.siyah/.ccxmlsum
fi
[ ! -f /data/.siyah/default.profile ] && cp /res/customconfig/default.profile /data/.siyah

read_defaults
read_config

#cpu undervolting
echo "${cpu_undervolting}" > /sys/devices/system/cpu/cpu0/cpufreq/vdd_levels

if [ "$logger" == "on" ];then
insmod /lib/modules/logger.ko
fi

if [ "$frandom" == "on" ];then
insmod /lib/modules/frandom.ko
fi

# disable debugging on some modules
if [ "$logger" == "off" ];then
  rm -rf /dev/log
  echo 0 > /sys/module/ump/parameters/ump_debug_level
  echo 0 > /sys/module/mali/parameters/mali_debug_level
  echo 0 > /sys/module/kernel/parameters/initcall_debug
  echo 0 > /sys//module/lowmemorykiller/parameters/debug_level
  echo 0 > /sys/module/earlysuspend/parameters/debug_mask
  echo 0 > /sys/module/alarm/parameters/debug_mask
  echo 0 > /sys/module/alarm_dev/parameters/debug_mask
  echo 0 > /sys/module/binder/parameters/debug_mask
  echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask
fi

# for ntfs automounting
insmod /lib/modules/fuse.ko
mount -o remount,rw /
mkdir -p /mnt/ntfs
chmod 777 /mnt/ntfs
mount -o mode=0777,gid=1000 -t tmpfs tmpfs /mnt/ntfs
mount -o remount,ro /

/sbin/busybox sh /sbin/ext/properties.sh

/sbin/busybox sh /sbin/ext/install.sh

##### Early-init phase tweaks #####
/sbin/busybox sh /sbin/ext/tweaks.sh

/sbin/busybox mount -t rootfs -o remount,ro rootfs

##### EFS Backup #####
(
# make sure that sdcard is mounted
sleep 30
/sbin/busybox sh /sbin/ext/efs-backup.sh
) &

#apply last soundgasm level on boot
/res/uci.sh soundgasm_hp $soundgasm_hp

# apply STweaks defaults
export CONFIG_BOOTING=1
/res/uci.sh apply
export CONFIG_BOOTING=

#usb mode
/res/customconfig/actions/usb-mode ${usb_mode}

if [ "$Boostpulse" == "on" ];then
#install modded powerhal
su
mount -o remount,rw /system
rm /system/lib/hw/power.default.so
cp /res/power.default.so.boostpulse /system/lib/hw/power.default.so
chown root.root /system/lib/hw/power.default.so
chmod 0664 /system/lib/hw/power.default.so
chown root.system /sys/devices/system/cpu/cpufreq/ondemand/boostpulse
chown root.system /sys/devices/system/cpu/cpufreq/ondemand/boostfreq
chmod 0664 /sys/devices/system/cpu/cpufreq/ondemand/boostpulse
chmod 0664 /sys/devices/system/cpu/cpufreq/ondemand/boostfreq
echo "1" > /sys/devices/system/cpu/cpufreq/ondemand/boostpulse
else
#install default powerhal
mount -o remount,rw /system
rm /system/lib/hw/power.default.so
cp /res/power.default.so /system/lib/hw/power.default.so
chown root.root /system/lib/hw/power.default.so
chmod 0664 /system/lib/hw/power.default.so
fi

# Enables JIT compiler for packet filters (needs kernel support)
echo "1" > /proc/sys/net/core/bpf_jit_enable

# 50k sampling rate for ondemand (default is 100k)
echo "50000" > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate

# cgroup_timer_slack
echo 50000 > /sys/fs/cgroup/timer_slack.min_slack_ns
echo 70000 > /sys/fs/cgroup/timer_slack.effective_slack_ns

# sd card tweak (thanks @infected_)
echo "4096" > /sys/devices/virtual/bdi/179:0/read_ahead_kb

# Flags blocks as non-rotational and increases cache size (thanks @infected_)
LOOP=`ls -d /sys/block/loop*`;
RAM=`ls -d /sys/block/ram*`;
MMC=`ls -d /sys/block/mmc*`;
for j in $LOOP $RAM
do
echo "0" > $j/queue/rotational;
echo "4096" > $j/queue/read_ahead_kb;
done

# ext4 tweaks (thanks @infected_)
tune2fs -f -o journal_data_writeback /dev/block/mmcblk0p9
tune2fs -f -O ^has_journal /dev/block/mmcblk0p9
tune2fs -f -o journal_data_writeback /dev/block/mmcblk0p7
tune2fs -f -O ^has_journal /dev/block/mmcblk0p7
tune2fs -f -o journal_data_writeback /dev/block/mmcblk0p10
tune2fs -f -O ^has_journal /dev/block/mmcblk0p10

# battery tweaks (thanks @infected_)
if [ "$battery" == "on" ];then
echo "500" > /proc/sys/vm/dirty_expire_centisecs
echo "1000" > /proc/sys/vm/dirty_writeback_centisecs
fi

### Helps Scrolling Responsiveness
setprop windowsmgr.max_events_per_sec 300
setprop ro.max.fling_velocity 12500
setprop ro.min.fling_velocity 8300
### Faster DNS Resolution Tweaks
setprop net.ppp0.dns1 8.8.8.8
setprop net.ppp0.dns2 8.8.4.4
setprop net.dns1 8.8.8.8
setprop net.dns2 8.8.4.4
### Hardware Acceleration Enabled
setprop persist.sys.ui.hw 1
### Force GPU Rendering on 2d Operations (build.prop part)
setprop debug.performance.tuning 1
setprop debug.sf.hw 1
setprop debug.egl.profiler 1
setprop debug.composition.type gpu
### Allow the purge of assets to free-up more RAM
setprop persist.sys.purgeable_assets 1
### Enable Adaptive Multi-Rate Wideband
setprop ro.ril.enable.amr.wideband 1
### Disables Built In Error Reporting
setprop profiler.force_disable_err_rpt 1
setprop profiler.force_disable_ulog 1
# Video Tuning
setprop ro.media.enc.jpeg.quality 100,100,100
# Define TCP buffer sizes for various networks
#   ReadMin, ReadInitial, ReadMax, WriteMin, WriteInitial, WriteMax,
    setprop net.tcp.buffersize.default 4096,87380,704512,4096,16384,110208
    setprop net.tcp.buffersize.wifi    524288,1048576,2097152,262144,524288,1048576
    setprop net.tcp.buffersize.lte     4096,87380,1220608,4096,16384,563200
    setprop net.tcp.buffersize.umts    4096,87380,563200,4096,16384,110208
    setprop net.tcp.buffersize.hspa    4096,87380,704512,4096,16384,110208
    setprop net.tcp.buffersize.hsupa   4096,87380,704512,4096,16384,262144
    setprop net.tcp.buffersize.hsdpa   4096,87380,704512,4096,16384,262144
    setprop net.tcp.buffersize.hspap   4096,87380,1220608,4096,16384,393216
    setprop net.tcp.buffersize.edge    4096,26280,35040,4096,16384,35040
    setprop net.tcp.buffersize.gprs    4096,8760,11680,4096,8760,11680
    setprop net.tcp.buffersize.evdo    4096,87380,563200,4096,16384,262144
    setprop net.tcp.buffersize.evdo_b  4096,87380,704512,4096,16384,262144
# Disable Google OTA Update checkin
setprop ro.config.nocheckin 1

setprop dalvik.vm.execution-mode int:jit

exec /sbin/ext/modules.sh

##### init scripts #####
/sbin/busybox sh /sbin/ext/run-init-scripts.sh
