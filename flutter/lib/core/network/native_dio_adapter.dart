import 'package:dio/dio.dart';

import 'native_dio_adapter_stub.dart'
    if (dart.library.io) 'native_dio_adapter_io.dart';

void configureNativeDioAdapter(Dio dio) => configureNativeAdapter(dio);
