import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(COINIT_APARTMENTTHREADED);
  
  final str = '{7AB36653-1796-484B-BDFA-E74F1CEBA31D}'.toNativeUtf16();
  final clsid = CLSIDFromString(PCWSTR(str));
  
  print('Trying to instantiate SpellCheckerFactory using CLSIDFromString...');
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
