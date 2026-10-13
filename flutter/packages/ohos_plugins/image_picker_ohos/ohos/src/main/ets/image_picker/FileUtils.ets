// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on FileUtils.java originally written by
// Copyright 2013 The Flutter Authors.

import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { systemDateTime } from '@kit.BasicServicesKit';

const TAG = "FileUtils";

export default class FileUtils {
  static getPathFromUri(context: common.Context | null, uri: string, defExtension?: string): string|null {
    Log.i(TAG, "getPathFromUri : " + uri);
    let inputFile: fs.File;
    try {
      inputFile = fs.openSync(uri);
    } catch (err) {
      Log.e(TAG, "open uri file failed err:" + err)
      return null;
    }
    if (inputFile == null) {
      return null;
    }
    const uuid = util.generateRandomUUID();
    if (!context) {
      fs.closeSync(inputFile);
      return null;
    }
    {
      const targetDirectoryPath = context.cacheDir + "/" + uuid;
      try {
        fs.mkdirSync(targetDirectoryPath);
        let targetDir = fs.openSync(targetDirectoryPath);
        Log.i(TAG, "mkdirSync success targetDirectoryPath:" + targetDirectoryPath + " fd: " + targetDir.fd);
        fs.closeSync(targetDir);
      } catch (err) {
        Log.e(TAG, "mkdirSync failed err:" + err);
        fs.closeSync(inputFile);
        return null;
      }

      const inputFilePath = uri.substring(uri.lastIndexOf("/") + 1);
      let inputFilePathSplits = inputFilePath.split(".");
      Log.i(TAG, "getPathFromUri inputFilePath: " + inputFilePath);
      let outputFileName: string = "";
      let extension: string = "";
      if (inputFilePathSplits.length === 1) {
        outputFileName = inputFilePathSplits[0];
        extension = "jpg";
      } else if (inputFilePathSplits.length === 2) {
        outputFileName = inputFilePathSplits[0];
        extension = inputFilePathSplits[1];
      } else if (inputFilePathSplits.length > 2) {
        extension = inputFilePathSplits.pop() || "";
        outputFileName = inputFilePathSplits.join(".");
      }
      if(!outputFileName){
        outputFileName = "image_picker";
      }
      if(!extension){
        if (defExtension) {
          extension = defExtension;
        } else {
          extension = "jpg";
        }
      }

      let timeStamp: string = systemDateTime.getTime().toString();
      const outputFilePath = targetDirectoryPath + "/" + outputFileName + timeStamp + "." + extension;
      const outputFile = fs.openSync(outputFilePath, fs.OpenMode.CREATE);
      try {
        Log.i(TAG, "copyFileSync inputFile fd:" + inputFile.fd + " outputFile fd:" + outputFile.fd);
        fs.copyFileSync(inputFile.fd, outputFilePath);
      } catch (err) {
        fs.closeSync(outputFile);
        Log.e(TAG, "copyFileSync failed err:" + err);
         try {
            fs.unlinkSync(outputFilePath);
          } catch (e) {
           Log.e(TAG, "unlinkSync failed err:" + e);}
          try {
            fs.rmdirSync(targetDirectoryPath);
          } catch (e) {
            Log.e(TAG, "rmdirSync failed err:" + e);
          }
        return null;
      } finally {
        fs.closeSync(inputFile);
        fs.closeSync(outputFile);
      }
      return outputFilePath;
    }
  }
}