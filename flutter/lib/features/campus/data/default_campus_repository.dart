import 'dart:typed_data';

import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:dio/dio.dart';

import '../models/campus_models.dart';
import 'campus_repository.dart';

class DefaultCampusRepository implements CampusRepository {
  DefaultCampusRepository(
    this._api, {
    Dio? dio,
    String baseUrl = const String.fromEnvironment(
      'RATINGS_API_BASE_URL',
      defaultValue: 'https://lehi.top',
    ),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 30),
               headers: const {'Accept': 'application/json'},
             ),
           );

  final ApiClient _api;
  final Dio _dio;
  String? _token;
  DateTime? _tokenExpiresAt;
  Future<String>? _tokenRequest;
  int _sessionGeneration = 0;
  CancelToken _cancelToken = CancelToken();
  final Map<String, Future<Uint8List?>> _assetCache = {};

  @override
  Future<CampusPageResult<CampusBoard>> listBoards({
    bool mine = false,
    String query = '',
    String sort = 'popular',
    String? cursor,
  }) async {
    final data = await _request(
      mine ? '/api/v1/ratings/me/content' : '/api/v1/ratings/boards',
      query: {
        if (mine) 'kind': 'boards',
        'q': query,
        'sort': sort,
        'cursor': cursor,
        'limit': 20,
      },
    );
    return CampusPageResult.fromJson(_asMap(data), CampusBoard.fromJson);
  }

  @override
  Future<CampusBoard> getBoard(String boardId) async {
    final data = await _request('/api/v1/ratings/boards/${_path(boardId)}');
    return CampusBoard.fromJson(_asMap(data));
  }

  @override
  Future<CampusBoard> createBoard({
    required String title,
    required String description,
    String? coverAssetId,
    String? requestId,
  }) async {
    final data = await _request(
      '/api/v1/ratings/boards',
      method: 'POST',
      body: {
        'title': title,
        'description': description,
        'cover_asset_id': ?coverAssetId,
        'create_request_id': requestId ?? createCampusRequestId(),
      },
    );
    return CampusBoard.fromJson(_asMap(data));
  }

  @override
  Future<CampusPageResult<CampusRatingItem>> listRatingItems({
    required String boardId,
    String query = '',
    String sort = 'popular',
    String? cursor,
  }) async {
    final data = await _request(
      '/api/v1/ratings/boards/${_path(boardId)}/items',
      query: {'q': query, 'sort': sort, 'cursor': cursor, 'limit': 20},
    );
    return CampusPageResult.fromJson(_asMap(data), CampusRatingItem.fromJson);
  }

  @override
  Future<CampusRatingItem> createRatingItem({
    required String boardId,
    required String name,
    required String description,
    String? imageAssetId,
    String? requestId,
  }) async {
    final data = await _request(
      '/api/v1/ratings/boards/${_path(boardId)}/items',
      method: 'POST',
      body: {
        'name': name,
        'description': description,
        'image_asset_id': ?imageAssetId,
        'create_request_id': requestId ?? createCampusRequestId(),
      },
    );
    return CampusRatingItem.fromJson(_asMap(data));
  }

  @override
  Future<CampusRatingItemDetail> getRatingItem(String itemId) async {
    final data = await _request('/api/v1/ratings/items/${_path(itemId)}');
    return CampusRatingItemDetail.fromJson(_asMap(data));
  }

  @override
  Future<CampusRatingMutation> submitRating({
    required String itemId,
    required int stars,
    required int expectedVersion,
  }) async {
    final data = _asMap(
      await _request(
        '/api/v1/ratings/items/${_path(itemId)}/rating',
        method: 'PUT',
        body: {'stars': stars, 'expected_version': expectedVersion},
      ),
    );
    return CampusRatingMutation(
      rating: CampusRatingSummary.fromJson(_map(data['rating'])),
      myRating: CampusUserRating.fromJson(_map(data['my_rating'])),
    );
  }

  @override
  Future<CampusRatingMutation> withdrawRating({
    required String itemId,
    required int expectedVersion,
  }) async {
    final data = _asMap(
      await _request(
        '/api/v1/ratings/items/${_path(itemId)}/rating',
        method: 'DELETE',
        body: {'expected_version': expectedVersion},
      ),
    );
    return CampusRatingMutation(
      rating: CampusRatingSummary.fromJson(_map(data['rating'])),
      myRating: null,
    );
  }

  @override
  Future<CampusPageResult<CampusComment>> listComments({
    required String itemId,
    String sort = 'newest',
    String? cursor,
  }) async {
    final data = await _request(
      '/api/v1/ratings/items/${_path(itemId)}/comments',
      query: {'sort': sort, 'cursor': cursor, 'limit': 20},
    );
    return CampusPageResult.fromJson(_asMap(data), CampusComment.fromJson);
  }

  @override
  Future<CampusPageResult<CampusComment>> listReplies({
    required String commentId,
    String? cursor,
  }) async {
    final data = await _request(
      '/api/v1/ratings/comments/${_path(commentId)}/replies',
      query: {'cursor': cursor, 'limit': 50},
    );
    return CampusPageResult.fromJson(_asMap(data), CampusComment.fromJson);
  }

  @override
  Future<CampusComment> createComment({
    required String itemId,
    required String body,
    String? parentId,
    String? requestId,
  }) async {
    final data = await _request(
      '/api/v1/ratings/items/${_path(itemId)}/comments',
      method: 'POST',
      body: {
        'body': body,
        'parent_id': ?parentId,
        'create_request_id': requestId ?? createCampusRequestId(),
      },
    );
    return CampusComment.fromJson(_asMap(data));
  }

  @override
  Future<void> deleteComment({
    required String commentId,
    required int expectedVersion,
  }) async {
    await _request(
      '/api/v1/ratings/comments/${_path(commentId)}',
      method: 'DELETE',
      body: {'expected_version': expectedVersion},
    );
  }

  @override
  Future<CampusPageResult<CampusMineEntry>> listMyRatingContent({
    required String kind,
    String? cursor,
  }) async {
    final data = await _request(
      '/api/v1/ratings/me/content',
      query: {'kind': kind, 'cursor': cursor, 'limit': 20},
    );
    return CampusPageResult.fromJson(
      _asMap(data),
      (json) => CampusMineEntry.fromJson(json, kind: kind),
    );
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    await _request(
      '/api/v1/ratings/reports',
      method: 'POST',
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
      },
    );
  }

  @override
  Future<String> uploadAsset({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final data = _asMap(
      await _request('/api/v1/ratings/assets', method: 'POST', body: form),
    );
    final id = _asMap(data)['id'];
    if (id is! String || id.isEmpty) {
      throw const CampusRepositoryException('图片上传结果无效。');
    }
    return id;
  }

  @override
  Future<CampusPageResult<CampusListing>> listListings({
    bool mine = false,
    String query = '',
    String type = 'sell',
    String? cursor,
  }) async {
    final data = await _request(
      mine ? '/api/v1/marketplace/me/items' : '/api/v1/marketplace/items',
      query: {'listing_type': type, 'q': query, 'cursor': cursor, 'limit': 20},
    );
    return CampusPageResult.fromJson(_asMap(data), CampusListing.fromJson);
  }

  @override
  Future<CampusPageResult<ForumThread>> listForumThreads({
    bool mine = false,
    String? categoryId,
    String query = '',
    String sort = 'latest',
    String? cursor,
  }) async {
    final data = await _request(
      mine ? '/api/v1/forum/me/threads' : '/api/v1/forum/threads',
      query: {
        'category_id': categoryId,
        'q': query,
        'sort': sort,
        'cursor': cursor,
        'limit': 20,
      },
    );
    return CampusPageResult.fromJson(_asMap(data), ForumThread.fromJson);
  }

  @override
  Future<List<ForumCategory>> listForumCategories() async {
    final data = await _request('/api/v1/forum/categories');
    final items = data is List
        ? data.whereType<Map<String, dynamic>>()
        : const Iterable<Map<String, dynamic>>.empty();
    return items.map(ForumCategory.fromJson).toList();
  }

  @override
  Future<ForumThreadDetail> getForumThread(String threadId) async {
    final data = await _request('/api/v1/forum/threads/${_path(threadId)}');
    return ForumThreadDetail.fromJson(_asMap(data));
  }

  @override
  Future<ForumThread> createForumThread({
    required String categoryId,
    required String title,
    required String body,
    List<String> imageAssetIds = const [],
    String? requestId,
  }) async {
    final data = await _request(
      '/api/v1/forum/threads',
      method: 'POST',
      body: {
        'category_id': categoryId,
        'title': title,
        'body': body,
        'image_asset_ids': imageAssetIds,
        'create_request_id': requestId ?? createCampusRequestId(),
      },
    );
    return ForumThread.fromJson(_asMap(data));
  }

  @override
  Future<ForumThread> updateForumThread({
    required String threadId,
    required String categoryId,
    required String title,
    required String body,
    required List<String> imageAssetIds,
    required int expectedVersion,
  }) async {
    final data = await _request(
      '/api/v1/forum/threads/${_path(threadId)}',
      method: 'PATCH',
      body: {
        'category_id': categoryId,
        'title': title,
        'body': body,
        'image_asset_ids': imageAssetIds,
        'expected_version': expectedVersion,
      },
    );
    return ForumThread.fromJson(_asMap(data));
  }

  @override
  Future<void> deleteForumThread({
    required String threadId,
    required int expectedVersion,
  }) async {
    await _request(
      '/api/v1/forum/threads/${_path(threadId)}',
      method: 'DELETE',
      body: {'expected_version': expectedVersion},
    );
  }

  @override
  Future<void> deleteForumReply({
    required String replyId,
    required int expectedVersion,
  }) async {
    await _request(
      '/api/v1/forum/replies/${_path(replyId)}',
      method: 'DELETE',
      body: {'expected_version': expectedVersion},
    );
  }

  @override
  Future<CampusPageResult<ForumReply>> listForumReplies({
    required String threadId,
    String? cursor,
  }) async {
    final data = await _request(
      '/api/v1/forum/threads/${_path(threadId)}/replies',
      query: {'cursor': cursor, 'limit': 20},
    );
    return CampusPageResult.fromJson(_asMap(data), ForumReply.fromJson);
  }

  @override
  Future<CampusPageResult<ForumReply>> listForumReplyChildren({
    required String replyId,
    String? cursor,
  }) async {
    final data = await _request(
      '/api/v1/forum/replies/${_path(replyId)}/replies',
      query: {'cursor': cursor, 'limit': 50},
    );
    return CampusPageResult.fromJson(_asMap(data), ForumReply.fromJson);
  }

  @override
  Future<ForumReply> createForumReply({
    required String threadId,
    required String body,
    String? parentId,
    String? requestId,
  }) async {
    final data = await _request(
      '/api/v1/forum/threads/${_path(threadId)}/replies',
      method: 'POST',
      body: {
        'body': body,
        'parent_id': ?parentId,
        'create_request_id': requestId ?? createCampusRequestId(),
      },
    );
    return ForumReply.fromJson(_asMap(data));
  }

  @override
  Future<ForumThreadLike> toggleForumThreadLike({
    required String threadId,
    required bool like,
  }) async {
    final data = await _request(
      '/api/v1/forum/threads/${_path(threadId)}/like',
      method: 'POST',
      body: {'like': like},
    );
    return ForumThreadLike.fromJson(_asMap(data));
  }

  @override
  Future<ForumThreadLike> toggleForumReplyLike({
    required String replyId,
    required bool like,
  }) async {
    final data = await _request(
      '/api/v1/forum/replies/${_path(replyId)}/like',
      method: 'POST',
      body: {'like': like},
    );
    return ForumThreadLike.fromJson(_asMap(data));
  }

  @override
  Future<CampusListing> getListing(String itemId) async {
    final data = await _request('/api/v1/marketplace/items/${_path(itemId)}');
    return CampusListing.fromJson(_asMap(data));
  }

  @override
  Future<CampusListing> updateListingStatus({
    required String itemId,
    required String status,
    required int expectedVersion,
  }) async {
    final data = await _request(
      '/api/v1/marketplace/items/${_path(itemId)}/status',
      method: 'PATCH',
      body: {'status': status, 'expected_version': expectedVersion},
    );
    return CampusListing.fromJson(_asMap(data));
  }

  @override
  Future<CampusContact> revealContact(String itemId) async {
    final data = _asMap(
      await _request(
        '/api/v1/marketplace/items/${_path(itemId)}/contact',
        method: 'POST',
      ),
    );
    return CampusContact(
      type: '${data['contact_type'] ?? ''}',
      value: '${data['contact_value'] ?? ''}',
    );
  }

  @override
  Future<CampusListing> createListing({
    required String title,
    required String description,
    required int priceCents,
    required String campus,
    required String type,
    required String contactType,
    required String contactValue,
    String? imageAssetId,
    String? requestId,
  }) async {
    final data = await _request(
      '/api/v1/marketplace/items',
      method: 'POST',
      body: {
        'listing_type': type,
        'title': title,
        'description': description,
        'price_cents': priceCents,
        'campus': campus,
        'contact_type': contactType,
        'contact_value': contactValue,
        'image_asset_id': ?imageAssetId,
        'create_request_id': requestId ?? createCampusRequestId(),
      },
    );
    return CampusListing.fromJson(_asMap(data));
  }

  @override
  Future<Uint8List?> loadAsset(String assetId) {
    final cached = _assetCache[assetId];
    if (cached != null) return cached;
    late final Future<Uint8List?> task;
    task = _loadAsset(assetId).then(
      (bytes) {
        if (bytes == null && identical(_assetCache[assetId], task)) {
          _assetCache.remove(assetId);
        }
        return bytes;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_assetCache[assetId], task)) _assetCache.remove(assetId);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _assetCache[assetId] = task;
    return task;
  }

  void _checkSession(int generation) {
    if (generation != _sessionGeneration) {
      throw const CampusRepositoryException('账号已切换，请重新操作。');
    }
  }

  Future<Object?> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? query,
    Object? body,
    bool retryAuthentication = true,
  }) async {
    final generation = _sessionGeneration;
    final token = await _getToken();
    _checkSession(generation);
    try {
      final response = await _dio.request<Object?>(
        path,
        queryParameters: _removeEmptyValues(query),
        data: body,
        cancelToken: _cancelToken,
        options: Options(
          method: method,
          headers: {
            'Authorization': 'Bearer $token',
            if (body is FormData) 'Content-Type': 'multipart/form-data',
          },
        ),
      );
      _checkSession(generation);
      if (response.statusCode == 401 && retryAuthentication) {
        _expireToken();
        return await _request(
          path,
          method: method,
          query: query,
          body: body is FormData ? body.clone() : body,
          retryAuthentication: false,
        );
      }
      final payload = _asMap(response.data);
      final code = payload['code'];
      if ((response.statusCode ?? 500) >= 400 || (code is num && code != 0)) {
        throw CampusRepositoryException(
          _errorMessage(payload),
          statusCode: response.statusCode,
        );
      }
      return payload['data'];
    } on DioException catch (error) {
      _checkSession(generation);
      if (error.response?.statusCode == 401 && retryAuthentication) {
        _expireToken();
        return _request(
          path,
          method: method,
          query: query,
          body: body is FormData ? body.clone() : body,
          retryAuthentication: false,
        );
      }
      final payload = _map(error.response?.data);
      throw CampusRepositoryException(
        payload == null ? '暂时无法连接校园服务，请检查网络后重试。' : _errorMessage(payload),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Uint8List?> _loadAsset(String assetId) async {
    final generation = _sessionGeneration;
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _getToken();
      _checkSession(generation);
      try {
        final response = await _dio.get<List<int>>(
          '/api/v1/ratings/assets/${_path(assetId)}/content',
          cancelToken: _cancelToken,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Accept': 'image/*', 'Authorization': 'Bearer $token'},
          ),
        );
        _checkSession(generation);
        if (response.statusCode == 401 && attempt == 0) {
          _expireToken();
          continue;
        }
        final bytes = response.data;
        return response.statusCode == 200 && bytes != null
            ? Uint8List.fromList(bytes)
            : null;
      } on DioException catch (error) {
        _checkSession(generation);
        if (error.response?.statusCode == 401 && attempt == 0) {
          _expireToken();
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<String> _getToken() async {
    final expiresAt = _tokenExpiresAt;
    if (_token != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return _token!;
    }
    final pending = _tokenRequest;
    if (pending != null) return pending;

    final request = _requestToken();
    _tokenRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_tokenRequest, request)) _tokenRequest = null;
    }
  }

  Future<String> _requestToken() async {
    final requestGeneration = _sessionGeneration;
    final data = _asMap(
      await _api.request('/api/v1/auth/ratings-token', method: 'POST'),
    );
    if (requestGeneration != _sessionGeneration) {
      throw const CampusRepositoryException('账号已切换，请重新操作。');
    }
    final token = data['access_token'];
    final expiresAt = DateTime.tryParse('${data['expires_at'] ?? ''}');
    if (token is! String || token.isEmpty || expiresAt == null) {
      throw const CampusRepositoryException('校园登录凭证无效，请重新登录。');
    }
    _token = token;
    _tokenExpiresAt = expiresAt;
    return token;
  }

  void _expireToken() {
    _token = null;
    _tokenExpiresAt = null;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const CampusRepositoryException('校园服务响应格式异常。');
  }

  Map<String, Object?>? _removeEmptyValues(Map<String, Object?>? values) {
    if (values == null) return null;
    return Map.fromEntries(
      values.entries.where((entry) => entry.value != null && entry.value != ''),
    );
  }

  String _path(String value) => Uri.encodeComponent(value);

  String _errorMessage(Map<String, dynamic> payload) {
    final message = payload['message'];
    return message is String && message.isNotEmpty ? message : '校园服务暂时不可用。';
  }

  @override
  void clearSession() {
    _sessionGeneration++;
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    _token = null;
    _tokenExpiresAt = null;
    _tokenRequest = null;
    _assetCache.clear();
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _cancelToken.cancel();
    _dio.close(force: true);
    _assetCache.clear();
    _token = null;
    _tokenExpiresAt = null;
  }
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;
