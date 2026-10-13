// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on ImagePickerUtils.java originally written by
// Copyright 2013 The Flutter Authors.

import bundleManager from '@ohos.bundle.bundleManager';
import { AsyncCallback, BusinessError } from '@ohos.base';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { abilityAccessCtrl, common, PermissionRequestResult } from '@kit.AbilityKit';

const TAG: string = "ImagePickerUtils";
const CAMERA_PERMISSION: string = "ohos.permission.CAMERA";
let bundleFlag: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_REQUESTED_PERMISSION;

export default class ImagePickerUtils {
  private static isPermissionPresentInManifest(permissionName: string, callback: AsyncCallback<boolean>): void {
    try {
      bundleManager.getBundleInfoForSelf(bundleFlag, (error, bundleInfo) => {
        if (bundleInfo == null) {
          Log.w(TAG, "get req permission bundleInfo is empty");
          callback(null, false);
          return;
        }
        for (let permission of bundleInfo.reqPermissionDetails) {
          Log.i(TAG, "permission : " + permission.name)
          if (permission.name === permissionName) {
            Log.i(TAG, "get req permission");
            callback(null, true);
            return;
          }
        }
        Log.i(TAG, "not find target permission");
        callback(null, false);
      });
    } catch (err) {
      Log.e(TAG, "get application info error")
      callback(null, false);
    }
  }

  /**
   * Camera permission need request if it present in manifest
   *
   * <p>Camera permission may be used in another package, as example flutter_barcode_reader.
   * https://github.com/flutter/flutter/issues/29837
   *
   * @param callback return true, if need request camera permission, otherwise false
   */
  public static needRequestCameraPermission(callback: AsyncCallback<boolean>): void {
    return ImagePickerUtils.isPermissionPresentInManifest(CAMERA_PERMISSION, callback);
  }

  // 动态获取请求
  public static async requestCameraPermission(context: common.Context): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
          context,
          ['ohos.permission.CAMERA']
        );
      const grantStatus = result.authResults;

      if (!grantStatus || grantStatus.length === 0) {
        Log.e(TAG, 'requestCameraPermission: empty authResults');
        return false;
      }

      return grantStatus[0] === 0;
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, `requestCameraPermission error: ${err.code}, ${err.message}`);
      return false;
    }
  }
}