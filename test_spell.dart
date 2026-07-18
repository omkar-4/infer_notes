import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  
  final factoryPtr = calloc<COMObject>();
  var hr = CoCreateInstance(
    CLSID_SpellCheckerFactory,
    nullptr,
    CLSCTX_INPROC_SERVER,
    IID_ISpellCheckerFactory,
    factoryPtr.cast(),
  );

  if (SUCCEEDED(hr)) {
    final factory = ISpellCheckerFactory(factoryPtr);
    final language = 'en-US'.toNativeUtf16();
    
    final supportedPtr = calloc<Int32>();
    hr = factory.isSupported(language.cast(), supportedPtr);
    
    print('isSupported HR: $hr, supported: ${supportedPtr.value}');
    
    if (supportedPtr.value == 1) {
      final checkerPtr = calloc<COMObject>();
      hr = factory.createSpellChecker(language.cast(), checkerPtr.cast());
      
      print('createSpellChecker HR: $hr');
      
      if (SUCCEEDED(hr)) {
        final checker = ISpellChecker(checkerPtr);
        final text = 'teh quickk brown foxx'.toNativeUtf16();
        final errorsPtr = calloc<COMObject>();
        
        hr = checker.check(text.cast(), errorsPtr.cast());
        print('check HR: $hr');
        
        if (SUCCEEDED(hr)) {
          final errors = IEnumSpellingError(errorsPtr);
          final errorPtr = calloc<COMObject>();
          
          while (errors.next(errorPtr.cast()) == S_OK) {
            final error = ISpellingError(errorPtr);
            final startIndexPtr = calloc<Uint32>();
            final lengthPtr = calloc<Uint32>();
            
            error.get_StartIndex(startIndexPtr);
            error.get_Length(lengthPtr);
            
            print('Error at ${startIndexPtr.value}, length ${lengthPtr.value}');
            
            free(startIndexPtr);
            free(lengthPtr);
          }
          errors.release();
        }
        free(errorsPtr);
        checker.release();
        free(text);
      }
      free(checkerPtr);
    }
    
    free(language);
    free(supportedPtr);
    factory.release();
  } else {
    print('Failed to create factory: $hr');
  }
  
  free(factoryPtr);
  CoUninitialize();
}
