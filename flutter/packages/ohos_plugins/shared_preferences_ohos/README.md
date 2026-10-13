
<p align="center">
  <h1 align="center"> <code>shared_preferences</code> </h1>
</p>

本项目基于 [shared_preferences@2.5.3](https://pub.dev/packages/shared_preferences/versions/2.5.3) 开发。

## 1. 安装与使用

### 1.1 安装方式

进入到工程目录并在 pubspec.yaml 中添加以下依赖：

<!-- tabs:start -->

#### pubspec.yaml

```yaml
...

dependencies:
  shared_preferences:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_packages.git
      path: packages/shared_preferences/shared_preferences
      # ref: shared_preferences-v2.5.3-ohos-1.0.1
      ref: TAG  #   请根据下方TAG版本对应表选择TAG
...
```

执行命令

```bash
flutter pub get
```

<!-- tabs:end -->

**TAG 版本对应表**

| Flutter 框架版本 | TAG1 | TAG2 | 分支 |
| :--- | :--- | :--- | :--- |
| 3.41 | `shared_preferences-v2.5.4-ohos-1.0.0` | `shared_preferences-v2.5.4-ohos-1.0.1` | `br_shared_preferences-v2.5.4_ohos` |
| 3.35 | `shared_preferences-v2.5.4-ohos-1.0.0` | `shared_preferences-v2.5.4-ohos-1.0.1` | `br_shared_preferences-v2.5.4_ohos` |
| 3.27 | `shared_preferences-v2.5.3-ohos-1.0.0` | `shared_preferences-v2.5.3-ohos-1.0.1` | `br_shared_preferences-v2.5.3_ohos` |
| 3.22 | `shared_preferences-v2.3.2-ohos-1.0.0` | `shared_preferences-v2.3.2-ohos-1.0.1` | `br_shared_preferences-v2.3.2_ohos` |
| 3.7 | `shared_preferences-v2.2.2-ohos-1.0.0` | `shared_preferences-v2.2.2-ohos-1.0.1` | `master` |

## 1.2 使用案例

使用案例详见 [shared_preferences_ohos/example](./example)

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过

1. Flutter: 3.35.7; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;

## 3. 属性

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

#### 存储类型

| Name         | Description    | Type   | **ohos Support** |
| ------------ | -------------- | ------ | ---------------- |
| String       | 存储字符串值   | String | yes              |
| int          | 存储整数值     | int    | yes              |
| double       | 存储浮点数值   | double | yes              |
| bool         | 存储布尔值     | bool   | yes              |
| List<String> | 存储字符串列表 | List   | yes              |



#### 参数

| Name   | Description                                             | Type    | **ohos Support** |
| ------ | ------------------------------------------------------- | ------- | ---------------- |
| key    | 存储值的唯一标识符                                      | String  | yes              |
| value  | 要存储的值（String、int、double、bool 或 List<String>） | dynamic | yes              |
| prefix | 所有键的可选前缀，避免命名冲突                          | String  | yes              |

## 4. API

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

#### SharedPreferences

| Name            | **return value**          | Description                 | Type     | **ohos Support** |
| --------------- | ------------------------- | --------------------------- | -------- | ---------------- |
| getInstance()   | Future<SharedPreferences> | 返回 SharedPreferences 实例 | function | yes              |
| getString()     | String                    | 获取存储的字符串值          | function | yes              |
| getInt()        | Int                       | 获取存储的整数值            | function | yes              |
| getDouble()     | Double                    | 获取存储的浮点数值          | function | yes              |
| getBool()       | Bool                      | 获取存储的布尔值            | function | yes              |
| getStringList() | StringList                | 获取存储的字符串列表        | function | yes              |
| setString()     | Future<bool>              | 存储字符串值                | function | yes              |
| setInt()        | Future<bool>              | 存储整数值                  | function | yes              |
| setDouble()     | Future<bool>              | 存储浮点数值                | function | yes              |
| setBool()       | Future<bool>              | 存储布尔值                  | function | yes              |
| setStringList() | Future<bool>              | 存储字符串列表              | function | yes              |
| remove()        | Future<bool>              | 移除存储的值                | function | yes              |
| clear()         | Future<bool>              | 移除所有存储的值            | function | yes              |
| reload()        | Future<bool>              | 从磁盘重新加载存储的值      | function | yes              |
| containsKey()   | bool                      | 检查首选项中是否存在某个键  | function | yes              |
| getKeys()       | Set<String>               | 返回首选项中的所有键        | function | yes              |

## 5. 遗留问题

## 6. 开源协议

本项目基于 [BSD-3-Clause](https://gitcode.com/openharmony-tpc/flutter_packages/blob/br_shared_preferences-v2.5.3_ohos/packages/shared_preferences/shared_preferences/LICENSE)，请自由地享受和参与开源。

> 模板版本: v0.0.1
