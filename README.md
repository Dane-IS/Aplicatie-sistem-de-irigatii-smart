# 🌿 Sistem Inteligent de Irigații 

Aceasta este aplicația mobilă dezvoltată în **Flutter** pentru lucrarea de licență. Aplicația servește drept interfață de control și monitorizare de la distanță pentru un sistem hardware distribuit, bazat pe microcontrolere **ESP32**, arhitectură Master-Slave.

📌 Descrierea Proiectului
Aplicația permite utilizatorului să monitorizeze în timp real starea plantelor umiditatea solului și nivelul apei din rezervor și să acționeze pompele de apă de la distanță, de oriunde din lume, prin intermediul protocolului **MQTT**. 

Sistemul este proiectat cu un accent puternic pe siguranță, prevenind automat erorile precum funcționarea pompei în gol.

## ✨ Funcționalități Principale
* **📊 Monitorizare în timp real:** Afișează procentul de umiditate din sol (0-100%) și nivelul apei din rezervor.
* **🎮 Control Dual:** * **Mod Manual:** Utilizatorul poate porni/opri pompele prin butoanele START/STOP.
  * **Mod Automat:** Sistemul hardware decide autonom irigarea (pornește la <30% umiditate, se oprește la >80%), iar butoanele manuale sunt blocate în aplicație pentru a preveni comenzile conflictuale.
* **🛡️ Funcții de Siguranță & Alerte:** * Notificare critică de tip *SnackBar* pe ecran dacă nivelul apei scade sub pragul de siguranță de 20%.
  * *Watchdog timer:* Detectează dacă un nod (ghiveci) își pierde conexiunea de mai mult de 10 secunde și îi schimbă starea în "OFFLINE", dezactivând comenzile.
* **📜 Istoric Udări:** Jurnal complet al acțiunilor de irigare, salvat direct în memoria telefonului.
* **✏️ Personalizare:** Posibilitatea de a redenumi zonele monitorizate (ex: "GRĂDINĂ", "BALCON").

## 🛠️ Tehnologii Utilizate
* **Frontend:** Flutter & Dart
* **Comunicație IoT:** Pachetul `mqtt_client` pentru conectarea la broker-ul public (`broker.emqx.io`).
* **Stocare Locală:** Pachetul `shared_preferences` pentru salvarea istoricului și a numelor zonelor.
* **Hardware Asociat:** ESP32 (Master Gateway & Slaves), Senzori analogici (sol și apă), Relee 3.3V, Pompe submersibile, protocol local ESP-NOW.

## 🚀 Cum să rulezi acest proiect
Pentru a compila și rula această aplicație pe emulator sau pe propriul telefon, urmează acești pași:

1. Asigură-te că ai instalat [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Clonează acest repository:
   ```bash
   git clone [https://github.com/Dane-IS/Aplicatie-sistem-de-irigatii-smart.git](https://github.com/Dane-IS/Aplicatie-sistem-de-irigatii-smart.git)
3. Conectează telefonul la calculator
4. Permite din telefon transferul de fisiere
5. Ruleaza codul
6. Dupa rulare se va instala aplicatia direct pe telefon
