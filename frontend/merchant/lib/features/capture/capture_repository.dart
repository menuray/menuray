import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

enum ParseRunStatus { pending, ocr, structuring, succeeded, failed }

ParseRunStatus _statusFrom(String? v) => switch (v) {
      'ocr' => ParseRunStatus.ocr,
      'structuring' => ParseRunStatus.structuring,
      'succeeded' => ParseRunStatus.succeeded,
      'failed' => ParseRunStatus.failed,
      _ => ParseRunStatus.pending,
    };

class ParseRunSnapshot {
  final String id;
  final ParseRunStatus status;
  final String? menuId;
  final String? errorStage;
  final String? errorMessage;
  const ParseRunSnapshot({
    required this.id,
    required this.status,
    this.menuId,
    this.errorStage,
    this.errorMessage,
  });
  factory ParseRunSnapshot.fromRow(Map<String, dynamic> row) => ParseRunSnapshot(
        id: row['id'] as String,
        status: _statusFrom(row['status'] as String?),
        menuId: row['menu_id'] as String?,
        errorStage: row['error_stage'] as String?,
        errorMessage: row['error_message'] as String?,
      );
}

class CaptureRepository {
  CaptureRepository(this._client);
  final SupabaseClient _client;

  Future<String> uploadPhoto({
    required XFile file,
    required String storeId,
    required String runId,
    required int index,
  }) async {
    final path = '$storeId/$runId/$index.jpg';
    final bytes = await file.readAsBytes();
    await _client.storage.from('menu-photos').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    return path;
  }

  Future<void> createParseRun({
    required String id,
    required String storeId,
    required List<String> paths,
  }) async {
    await _client.from('parse_runs').insert({
      'id': id,
      'store_id': storeId,
      'source_photo_paths': paths,
      'status': 'pending',
    });
  }

  Future<ParseRunStatus> invokeParseMenu({required String runId}) async {
    final res = await _client.functions.invoke(
      'parse-menu',
      body: {'run_id': runId},
    );
    final status = (res.data as Map?)?['status'] as String?;
    return _statusFrom(status);
  }

  Stream<ParseRunSnapshot> streamParseRun({required String runId}) {
    return _client
        .from('parse_runs')
        .stream(primaryKey: ['id'])
        .eq('id', runId)
        .map((rows) {
      if (rows.isEmpty) {
        return ParseRunSnapshot(id: runId, status: ParseRunStatus.pending);
      }
      return ParseRunSnapshot.fromRow(rows.first);
    });
  }
}
