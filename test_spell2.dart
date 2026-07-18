import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(COINIT_APARTMENTTHREADED);
  
  try {
    final factory = SpellCheckerFactory.createInstance();
    final language = 'en-US'.toNativeUtf16();
    
    // In win32 package 5+, methods that return an HRESULT and output a value often return that value directly or throw WindowsException.
    try {
      final isSupported = factory.isSupported(language.toDartString()); // Wait, how is isSupported defined?
      print('isSupported: $isSupported');
    } catch (e) {
      print(e);
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
