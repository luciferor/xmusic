import 'package:get/get.dart';

class CoverController extends GetxController {
  final RxString fileId = ''.obs;

  void updateFileId(String newFileId) {
    fileId.value = newFileId;
  }
}