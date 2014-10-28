LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)
FLINGD_PATH := $(LOCAL_PATH)

.phony: flingd
flingd:
	cd $(FLINGD_PATH); npm install --production; cd $(ANDROID_BUILD_TOP)
	mkdir -p $(TARGET_OUT)/usr/lib/node_modules/flingd
	rm -rf $(TARGET_OUT)/usr/lib/node_modules/flingd/*
	cp -rf $(FLINGD_PATH)/bin $(TARGET_OUT)/usr/lib/node_modules/flingd/
	cp -rf $(FLINGD_PATH)/lib $(TARGET_OUT)/usr/lib/node_modules/flingd/
	cp -rf $(FLINGD_PATH)/node_modules $(TARGET_OUT)/usr/lib/node_modules/flingd/
	mkdir -p $(TARGET_OUT)/bin
	rm -rf $(TARGET_OUT)/bin/flingd
	ln -sf ../usr/lib/node_modules/flingd/bin/flingd $(TARGET_OUT)/bin/flingd
	chmod a+x $(TARGET_OUT)/bin/flingd

ALL_MODULES += flingd
ALL_MODULES.flingd.INSTALLED := flingd
