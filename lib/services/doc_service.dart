import '../models/petition_model.dart';
import 'doc_service_stub.dart'
    if (dart.library.html) 'doc_service_web.dart' as impl;

class PetitionDocService {
  Future<void> exportToDoc(PetitionModel data) async {
    await impl.exportToDocImpl(data);
  }
}
