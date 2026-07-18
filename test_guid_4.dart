import 'dart:ffi';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(COINIT_APARTMENTTHREADED);
  final clsid = GUID('{7AB36653-1796-484B-BDFA-E74F1DB7C1DC}');
  
  print('Trying to instantiate SpellCheckerFactory with DB7C1DC...');
  try {
    final factory = CoCreateInstance<ISpellCheckerFactory>(
      clsid.toNative(),
      null,
      CLSCTX_INPROC_SERVER,
    );
    print('Success! Pointer: $factory');
  } catch (e) {
    print('Failed: $e');
  }
}
