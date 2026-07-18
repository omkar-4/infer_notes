import 'dart:ffi';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(COINIT_APARTMENTTHREADED);
  
  final clsid = calloc<GUID>();
  IIDFromString('{7AB36653-1796-484B-BDFA-E74F1CEBA31D}'.toNativeUtf16(), clsid);
  
  print('Trying to instantiate SpellCheckerFactory using IIDFromString...');
  try {
    final factory = CoCreateInstance<ISpellCheckerFactory>(
      clsid,
      null,
      CLSCTX_INPROC_SERVER,
    );
    print('Success! Pointer: $factory');
  } catch (e) {
    print('Failed: $e');
  }
}
