import 'dart:io';

Future<String> persistAttachmentCopy({
  required String sourcePath,
  required String destinationDirPath,
  required String destinationFileName,
}) async {
  final dir = Directory(destinationDirPath);
  await dir.create(recursive: true);
  final sep = Platform.pathSeparator;
  final destPath = '$destinationDirPath$sep$destinationFileName';
  await File(sourcePath).copy(destPath);
  return destPath;
}
