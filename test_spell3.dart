import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  
  final factoryPtr = calloc<COMObject>();
  final hr = CoCreateInstance(
    GUIDFromString('{7AB36653-1796-484B-BDFA-E74F1CEBA31D}'), // CLSID_SpellCheckerFactory
    nullptr,
    CLSCTX_INPROC_SERVER,
    IID_ISpellCheckerFactory,
    factoryPtr.cast(),
  );

  if (SUCCEEDED(hr)) {
    final factory = ISpellCheckerFactory(factoryPtr);
    final language = 'en-US'.toNativeUtf16();
    
    try {
      if (factory.isSupported(language)) {
        print('Language is supported!');
        final checker = factory.createSpellChecker(language);
        if (checker != null) {
          print('Checker created!');
          final text = 'teh quickk brown foxx'.toNativeUtf16();
          final errors = checker.check(text);
          if (errors != null) {
            print('Got errors!');
            // How do we iterate IEnumSpellingError in Dart?
            // errorPtr is an ISpellingError?
          }
          free(text);
          checker.release();
        }
      }
    } catch (e) {
      print(e);
    }
    
    free(language);
    factory.release();
  } else {
    print('Failed to create factory: $hr');
  }
  
  // free(factoryPtr); // Releasing factory frees it
  CoUninitialize();
}
