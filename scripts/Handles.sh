#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/openwrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	HP_RULE="surge"
	HP_PATH="./feeds/luci/applications/luci-app-homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy数据已更新!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
    echo " "
	
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale修复成功!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust修复成功!"
fi

#修复DiskMan编译失败
DM_FILE="../package/luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "
 
	sed -i 's/fs-ntfs/fs-ntfs3/g' $DM_FILE
	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman修复成功!"
fi

#修复状态灯
LED_FILE="../target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6000-re-ss-01.dts"
if [ -f "$LED_FILE" ]; then
	echo " "
 
	sed -i 's/led-boot = &led_status_green;/led-boot = &led_status_blue;/g' $LED_FILE
 	sed -i 's/led-running = &led_status_blue;/led-running = &led_status_green;/g' $LED_FILE

	cd $PKG_PATH && echo "状态灯修复完成!"
fi

#修复5G不支持160
WIRELESS_FILE="../feeds/luci/modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js"

# 检查文件是否存在
if [ -f "$WIRELESS_FILE" ]; then
    echo "正在修复 wireless.js 文件..."

    # 删除 'VHT160', '160 MHz', htmodelist.VHT160
    sed -i "/'VHT160', '160 MHz', htmodelist.VHT160/d" $WIRELESS_FILE

    # 删除 'HE160', '160 MHz', htmodelist.HE160
    sed -i "/'HE160', '160 MHz', htmodelist.HE160/d" $WIRELESS_FILE

    # 删除 if (/HE20|HE40|HE80|HE160/.test(htval)) 中的 |HE160
    # 注意：这里需要更精确的匹配，以避免删除其他地方的 HE160
    sed -i "s/|HE160\(\/.test(htval))\)/\1/g" $WIRELESS_FILE

    # 删除 else if (/VHT20|VHT40|VHT80|VHT160/.test(htval)) 中的 |VHT160
    # 注意：这里需要更精确的匹配，以避免删除其他地方的 VHT160
    sed -i "s/|VHT160\(\/.test(htval))\)//g" $WIRELESS_FILE

    cd $PKG_PATH && echo "wireless.js 文件修复完成！"
else
    echo "错误：文件 wireless.js 未找到。"
fi

# 自定义v2ray-geodata下载
V2RAY_FILE="../feeds/packages/net/v2ray-geodata"
MF_FILE="$GITHUB_WORKSPACE/package/v2ray-geodata/Makefile"
SH_FILE="$GITHUB_WORKSPACE/package/v2ray-geodata/init.sh"
UP_FILE="$GITHUB_WORKSPACE/package/v2ray-geodata/v2ray-geodata-updater"
if [ -d "$V2RAY_FILE" ]; then
	echo " "

	cp -f "$MF_FILE" "$V2RAY_FILE/Makefile"
	cp -f "$SH_FILE" "$V2RAY_FILE/init.sh"
	cp -f "$UP_FILE" "$V2RAY_FILE/v2ray-geodata-updater"

	cd $PKG_PATH && echo "v2ray-geodata替换完成!"
fi

#设置nginx默认配置和修复quickstart温度显示
wget "https://gist.githubusercontent.com/huanchenshang/df9dc4e13c6b2cd74e05227051dca0a9/raw/nginx.default.config" -O ../feeds/packages/net/nginx-util/files/nginx.config
wget "https://gist.githubusercontent.com/puteulanus/1c180fae6bccd25e57eb6d30b7aa28aa/raw/istore_backend.lua" -O ../package/luci-app-quickstart/luasrc/controller/istore_backend.lua

# 修改软件源为immortalwrt
lean_def_dir="$GITHUB_WORKSPACE/openwrt/package/lean/default-settings"
zzz_default_settings="$lean_def_dir/files/zzz-default-settings"

# 检查是否存在 lean_def_dir 和 zzz_default_settings
if [ -d "$lean_def_dir" ] && [ -f "$zzz_default_settings" ]; then

    # 使用更简单的模式删除包含特定内容的行
    sed -i '/openwrt_luci/d' "$zzz_default_settings"
    sed -i '/mirrors.tencent.com/d' "$zzz_default_settings"

    # 使用 cat 命令将新的软件源配置追加到文件末尾
    cat << 'NEW_END' >> "$zzz_default_settings"

cat << EOF > /etc/opkg/distfeeds.conf
src/gz openwrt_base https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base/
src/gz openwrt_luci https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci/
src/gz openwrt_packages https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages/
src/gz openwrt_routing https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing/
src/gz openwrt_telephony https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony/
EOF
NEW_END
    cd $PKG_PATH && echo "替换软件源完成！"
fi

# 移除 uhttpd 依赖
# 当启用luci-app-quickfile插件时，表示启动nginx，所以移除luci对uhttp(luci-light)的依赖
config_path="$GITHUB_WORKSPACE/openwrt/config/jdcloud-re-ss-01.config"
luci_makefile_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/collections/luci/Makefile"

if grep -q "CONFIG_PACKAGE_luci-app-quickfile=y" "$config_path"; then
    if [ -f "$luci_makefile_path" ]; then
        sed -i '/luci-light/d' "$luci_makefile_path"
        cd $PKG_PATH && echo "删除 uhttpd (luci-light) 依赖项,因为 luci-app-quickfile (nginx) 已启用."
    fi
fi

#修改CPU 性能优化调节名称显示
path="$GITHUB_WORKSPACE/openwrt/feeds/luci/applications/luci-app-cpufreq"
po_file="$path/po/zh_Hans/cpufreq.po"

if [ -d "$path" ] && [ -f "$po_file" ]; then
    sed -i 's/msgstr "CPU 性能优化调节"/msgstr "性能调节"/g' "$po_file"
    cd $PKG_PATH && echo "cpu调节更名完成"
else
    echo "cpufreq.po文件未找到"
    return 1
fi

#添加quickfile文件管理
repo_url="https://github.com/sbwml/luci-app-quickfile.git"
target_dir="$GITHUB_WORKSPACE/openwrt/package/lean/quickfile"
if [ -d "$target_dir" ]; then
    rm -rf "$target_dir"
fi
git clone --depth 1 "$repo_url" "$target_dir"

makefile_path="$target_dir/quickfile/Makefile"
if [ -f "$makefile_path" ]; then
    sed -i '/\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-\$(ARCH_PACKAGES)/c\
\tif [ "\$(ARCH_PACKAGES)" = "x86_64" ]; then \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-x86_64 \$(1)\/usr\/bin\/quickfile; \\\
\telse \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-aarch64_generic \$(1)\/usr\/bin\/quickfile; \\\
\tfi' "$makefile_path"
	cd $PKG_PATH && "添加quickfile成功"
fi

#修改argon背景图片
theme_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/background"
source_path="$GITHUB_WORKSPACE/images"
source_file="$source_path/bg1.jpg"
target_file="$theme_path/bg1.jpg"

if [ -f "$source_file" ]; then
    cp -f "$source_file" "$target_file"
    cd $PKG_PATH echo "背景图片更新成功：$target_file"
else
    echo "错误：未找到源图片文件：$source_file"
    return 1
fi

#修改quickfile菜单位置
quickfile_path="$GITHUB_WORKSPACE/openwrt/package/emortal/quickfile/luci-app-quickfile/root/usr/share/luci/menu.d/luci-app-quickfile.json"

if [ -d "$(dirname "$quickfile_path")" ] && [ -f "$quickfile_path" ]; then
    sed -i 's/system/nas/g' "$quickfile_path"
    cd $PKG_PATH echo "quickfile位置更改完成"
else
    echo "quickfile文件或目录不存在，跳过更改。"
	return 1
fi


#turboacc设置名称显示
tb_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/applications/luci-app-turboacc"
po_file="$tb_path/po/zh_Hans/turboacc.po"

if [ -d "$tb_path" ] && [ -f "$po_file" ]; then
    sed -i 's/msgstr "Turbo ACC 网络加速"/msgstr "网络加速"/g' "$po_file"
    cd $PKG_PATH echo "turboacc名称更改完成"
else
    echo "turboacc文件或目录不存在，跳过更改"
    return 1
fi

