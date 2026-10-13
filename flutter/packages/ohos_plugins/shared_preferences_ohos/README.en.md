
<p align="center">
  <h1 align="center"> <code>shared_preferences</code> </h1>
</p>

This project is based on  [shared_preferences@2.5.3](https://pub.dev/packages/shared_preferences/versions/2.5.3)  .

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml:

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
      ref: TAG  #   Select a TAG according to the TAG version table below
...
```

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

**TAG Version Table**

| Flutter Version | TAG1 | TAG2 | Branch |
| :--- | :--- | :--- | :--- |
| 3.41 | `shared_preferences-v2.5.4-ohos-1.0.0` | `shared_preferences-v2.5.4-ohos-1.0.1` | `br_shared_preferences-v2.5.4_ohos` |
| 3.35 | `shared_preferences-v2.5.4-ohos-1.0.0` | `shared_preferences-v2.5.4-ohos-1.0.1` | `br_shared_preferences-v2.5.4_ohos` |
| 3.27 | `shared_preferences-v2.5.3-ohos-1.0.0` | `shared_preferences-v2.5.3-ohos-1.0.1` | `br_shared_preferences-v2.5.3_ohos` |
| 3.22 | `shared_preferences-v2.3.2-ohos-1.0.0` | `shared_preferences-v2.3.2-ohos-1.0.1` | `br_shared_preferences-v2.3.2_ohos` |
| 3.7 | `shared_preferences-v2.2.2-ohos-1.0.0` | `shared_preferences-v2.2.2-ohos-1.0.1` | `master` |

## 1.2 Usage

For use cases [shared_preferences_ohos/example](./example)

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.35.7; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;

## 3. Properties

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

#### Storage type

| Name         | Description                 | Type   | **ohos Support** |
| ------------ | --------------------------- | ------ | ---------------- |
| String       | Store string values         | String | yes              |
| int          | Store integer values        | int    | yes              |
| double       | Store floating-point values | double | yes              |
| bool         | Store boolean values        | bool   | yes              |
| List<String> | Store string lists          | List   | yes              |

### Parameters

| Name   | Description                                                  | Type    | **ohos Support** |
| ------ | ------------------------------------------------------------ | ------- | ---------------- |
| key    | The unique identifier for storing values                     | String  | yes              |
| value  | The value to be stored (String, int, double, bool, or List<String>) | dynamic | yes              |
| prefix | An optional prefix for all keys to avoid naming conflicts    | String  | yes              |

## 4. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

#### SharedPreferences

| Name            | **return value**          | Description                          | Type     | **ohos Support** |
| --------------- | ------------------------- | ------------------------------------ | -------- | ---------------- |
| getInstance()   | Future<SharedPreferences> | Return a SharedPreferences instance  | function | yes              |
| getString()     | String                    | Get the stored string value          | function | yes              |
| getInt()        | Int                       | Get the stored integer value         | function | yes              |
| getDouble()     | Double                    | Get the stored floating-point value  | function | yes              |
| getBool()       | Bool                      | Get the stored boolean value         | function | yes              |
| getStringList() | StringList                | Get the stored string list           | function | yes              |
| setString()     | Future<bool>              | Store a string value                 | function | yes              |
| setInt()        | Future<bool>              | Store an integer value               | function | yes              |
| setDouble()     | Future<bool>              | Store a floating-point value         | function | yes              |
| setBool()       | Future<bool>              | Store a boolean value                | function | yes              |
| setStringList() | Future<bool>              | Store a string list                  | function | yes              |
| remove()        | Future<bool>              | Remove the stored value              | function | yes              |
| clear()         | Future<bool>              | Remove all stored values             | function | yes              |
| reload()        | Future<bool>              | Reload stored values from disk       | function | yes              |
| containsKey()   | bool                      | Check if a key exists in preferences | function | yes              |
| getKeys()       | Set<String>               | Return all keys in preferences       | function | yes              |

## 5. Known Issues

## 7.**License**

This project is licensed under [BSD-3-Clause](https://gitcode.com/openharmony-tpc/flutter_packages/blob/br_shared_preferences-v2.5.3_ohos/packages/shared_preferences/shared_preferences/LICENSE)

> Template version: v0.0.1
