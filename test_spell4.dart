import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  
  try {
    final factory = CoCreateInstance<ISpellCheckerFactory>(
      '{7AB36653-1796-484B-BDFA-E74F1CEBA31D}',
      iid: '{8e018a9d-2415-4677-bf08-794ea61f94bb}',
    );

    final language = 'en-US'.toNativeUtf16();
    final pcwstrLanguage = PCWSTR(language);
    
    if (factory.isSupported(pcwstrLanguage)) {
      print('Language is supported!');
      final checker = factory.createSpellChecker(pcwstrLanguage);
      if (checker != null) {
        print('Checker created!');
        final text = 'teh quickk brown foxx'.toNativeUtf16();
        final errors = checker.check(PCWSTR(text));
        
        if (errors != null) {
          print('Got errors!');
          
          final errorPtr = calloc<COMObject>();
          while (errors.next(errorPtr.cast()) == S_OK) {
            final error = ISpellingError(errorPtr);
            print('Error at ${error.startIndex}, length ${error.length}');
          }
          errors.release();
        }
        free(text);
        checker.release();
      }
    }
    
    free(language);
    factory.release();
  } catch (e) {
    print('Error: $e');
  }
  
  CoUninitialize();
}
