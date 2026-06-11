import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const MQTTPage(),
    );
  }
}

class MQTTPage extends StatefulWidget {
  const MQTTPage({super.key});
  @override
  State<MQTTPage> createState() => _MQTTPageState();
}

class _MQTTPageState extends State<MQTTPage> {
  final String broker = 'broker.emqx.io';
  final String topicDate1 = 'esp32/slave1/date';
  final String topicDate2 = 'esp32/slave2/date';
  final String topicCmd1 = 'esp32/slave1/comenzi';
  final String topicCmd2 = 'esp32/slave2/comenzi';
  final String topicAuto1 = 'esp32/slave1/auto';
  final String topicAuto2 = 'esp32/slave2/auto';
  final String topicIstoric = 'esp32/istoric';

  late MqttServerClient client;
  
  String dataSlave1 = "---";
  String dataSlave2 = "---";
  
  bool pompa1Activa = false;
  bool pompa2Activa = false;

  DateTime? lastSeenSlave1;
  DateTime? lastSeenSlave2;
  bool esteConectatMQTT = false;

  // Variabile salvate
  String numeSenzor1 = "GRĂDINĂ";
  String numeSenzor2 = "BALCON";
  bool autoSenzor1 = false;
  bool autoSenzor2 = false;
  
  //  LISTA PENTRU ISTORIC 
  List<String> istoricUdari = [];

  bool alertaAfisata2 = false;

  @override
  void initState() {
    super.initState();
    incarcaSetariSalvate();
    setupMqtt();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> incarcaSetariSalvate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      numeSenzor1 = prefs.getString('nume1') ?? "GRĂDINĂ";
      numeSenzor2 = prefs.getString('nume2') ?? "BALCON";
      autoSenzor1 = prefs.getBool('auto1') ?? false;
      autoSenzor2 = prefs.getBool('auto2') ?? false;
      // Încărcăm istoricul salvat
      istoricUdari = prefs.getStringList('istoric') ?? [];
    });
  }

  // --- FUNCȚIE PENTRU SALVAREA ÎN ISTORIC ---
  Future<void> inregistreazaUdare(String numeZona) async {
    final now = DateTime.now();
    
    // Formatăm data și ora frumos (Ex: 15/08/2026 14:05)
    String zi = now.day.toString().padLeft(2, '0');
    String luna = now.month.toString().padLeft(2, '0');
    String an = now.year.toString();
    String ora = now.hour.toString().padLeft(2, '0');
    String minut = now.minute.toString().padLeft(2, '0');
    
    String inregistrareNoua = "$numeZona - Data: $zi/$luna/$an | Ora: $ora:$minut";

    setState(() {
      istoricUdari.insert(0, inregistrareNoua); // Adaugăm mereu la începutul listei
      
      if (istoricUdari.length > 50) istoricUdari.removeLast();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('istoric', istoricUdari);
  }

  // Funcție pentru a curăța istoricul
  Future<void> stergeIstoric() async {
    setState(() => istoricUdari.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('istoric');
  }

  Future<void> schimbaModAuto(int nr, bool valoare) async {
    setState(() {
      if (nr == 1) autoSenzor1 = valoare;
      if (nr == 2) autoSenzor2 = valoare;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(nr == 1 ? 'auto1' : 'auto2', valoare);

    if (esteConectatMQTT) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(valoare ? "1" : "0");
      client.publishMessage(nr == 1 ? topicAuto1 : topicAuto2, MqttQos.atMostOnce, builder.payload!);
    }
  }

  Future<void> setupMqtt() async {
    String clientId = 'alex_client_${Random().nextInt(1000)}';
    client = MqttServerClient(broker, clientId);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.onDisconnected = () => setState(() => esteConectatMQTT = false);

    try {
      await client.connect();
      setState(() => esteConectatMQTT = true);
      
      client.subscribe(topicDate1, MqttQos.atMostOnce);
      client.subscribe(topicDate2, MqttQos.atMostOnce);
      client.subscribe('esp32/istoric', MqttQos.atMostOnce); // ABONARE ISTORIC
      
    } catch (e) {
      debugPrint('Eroare MQTT: $e');
    }

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String mesaj = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topicVenit = c[0].topic;

      setState(() {
        if (topicVenit == topicDate1) {
          dataSlave1 = mesaj;
          lastSeenSlave1 = DateTime.now(); 
        } 
        else if (topicVenit == topicDate2) {
          dataSlave2 = mesaj;
          lastSeenSlave2 = DateTime.now(); 
        }
        if (mesaj.contains("L:")) {
          int nivel = int.tryParse(mesaj.split(',')[0].replaceAll("L:", "")) ?? 100;
          if (nivel < 20 && !alertaAfisata2) {
            
            _arataNotificareCritica("Rezervorul plantei este gol!"); 
            
            alertaAfisata2 = true;
          } else if (nivel >= 20) {
            alertaAfisata2 = false; 
          }
        }
        //  ÎNREGISTRAREA AUTOMATĂ 
        else if (topicVenit == 'esp32/istoric') {
          if (mesaj == "START_1") {
            inregistreazaUdare("$numeSenzor1 (Auto)");
          } else if (mesaj == "START_2") {
            inregistreazaUdare("$numeSenzor2 (Auto)");
          }
        }
      });
    });
  }

  void _arataNotificareCritica(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(mesaj, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void trimiteComandaManual(String topic, String comanda, bool stareNoua, int nr) {
    if (!esteConectatMQTT) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(comanda);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    
    setState(() {
      if (nr == 1) pompa1Activa = stareNoua;
      if (nr == 2) pompa2Activa = stareNoua;
    });

    if (stareNoua == true) {
      String nume = (nr == 1) ? numeSenzor1 : numeSenzor2;
      inregistreazaUdare(nume);
    }
  }

  Future<void> editeazaNume(int nr, String numeCurent) async {
    TextEditingController controller = TextEditingController(text: numeCurent);
    String? numeNou = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Redenumește"),
        content: TextField(controller: controller, textCapitalization: TextCapitalization.characters),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANULEAZĂ")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("SALVEAZĂ")),
        ],
      ),
    );
    if (numeNou != null && numeNou.isNotEmpty) {
      String finalNume = numeNou.toUpperCase();
      setState(() {
        if (nr == 1) numeSenzor1 = finalNume;
        if (nr == 2) numeSenzor2 = finalNume;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(nr == 1 ? 'nume1' : 'nume2', finalNume);
    }
  }

  bool isSlaveOnline(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen).inSeconds < 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Control Irigații"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Icon(Icons.circle, color: esteConectatMQTT ? Colors.green : Colors.red, size: 15),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            buildSensorCard(numeSenzor1, dataSlave1, pompa1Activa, topicCmd1, 1, lastSeenSlave1, autoSenzor1),
            const SizedBox(height: 20),
            buildSensorCard(numeSenzor2, dataSlave2, pompa2Activa, topicCmd2, 2, lastSeenSlave2, autoSenzor2),
            const SizedBox(height: 30),
            
            // --- BUTONUL CARE DESCHIDE FEREASTRA DE ISTORIC ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigăm către fereastra nouă
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaginaIstoric(
                        istoric: istoricUdari, 
                        onSterge: stergeIstoric,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history, color: Colors.teal),
                label: const Text("VEZI ISTORIC UDARE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.teal, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

   Widget buildSensorCard(String titlu, String valoare, bool status, String topic, int nr, DateTime? last, bool isAuto) {
    bool online = isSlaveOnline(last);
    String niv = "--", umid = "--", txt = "";

    if (valoare.contains("L:") && valoare.contains("U:")) {
      List<String> p = valoare.split(',');
      niv = p[0].replaceAll("L:", "");
      umid = p[1].replaceAll("U:", "");
      int u = int.tryParse(umid) ?? 0;
      if (u <= 5) {
        txt = "(Nu este în sol)";
      } else if (u <= 50) {
        txt = "(Uscat)";
      } else if (u <= 90) {
        txt = "(Umed)";
      } else {
        txt = "(În apă)";
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => editeazaNume(nr, titlu),
                child: Row(children: [Text(titlu, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(width: 5), const Icon(Icons.edit, size: 14, color: Colors.grey)]),
              ),
              Text(online ? "ONLINE" : "OFFLINE", style: TextStyle(color: online ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoTile(Icons.yard, "Sol:", "$umid% $txt", Colors.brown),
              _infoTile(Icons.water_drop, "Apă:", "$niv%", Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              title: const Text("MOD AUTOMAT", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(isAuto ? "Master decide udarea" : "Control manual"),
              value: isAuto,
              onChanged: online ? (val) => schimbaModAuto(nr, val) : null,
              activeColor: Colors.teal,
            ),
          ),

          const SizedBox(height: 20),
          Text("Pompă: ${status ? 'PORNITĂ' : 'OPRITĂ'}", style: TextStyle(fontWeight: FontWeight.bold, color: status ? Colors.green : Colors.grey)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: (online && !isAuto) ? () => trimiteComandaManual(topic, "PORNESTE_UDARE", true, nr) : null, 
                icon: const Icon(Icons.play_arrow), 
                label: const Text("START"), 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)
              ),
              ElevatedButton.icon(
                onPressed: (online && !isAuto) ? () => trimiteComandaManual(topic, "OPRESTE_UDARE", false, nr) : null, 
                icon: const Icon(Icons.stop), 
                label: const Text("STOP"), 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String val, Color col) {
    return Column(children: [Icon(icon, color: col), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(val, style: const TextStyle(fontWeight: FontWeight.bold))]);
  }
}

// FEREASTRA NOUĂ PENTRU ISTORIC 

class PaginaIstoric extends StatelessWidget {
  final List<String> istoric;
  final VoidCallback onSterge;

  const PaginaIstoric({super.key, required this.istoric, required this.onSterge});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Istoric Udare"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Șterge Istoric',
            onPressed: () {
              onSterge();
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Istoricul a fost șters!"), backgroundColor: Colors.teal),
              );
            },
          )
        ],
      ),
      // Listview creează o listă scrollabilă automată
      body: istoric.isEmpty 
          ? const Center(
              child: Text(
                "Nicio udare manuală înregistrată.", 
                style: TextStyle(fontSize: 18, color: Colors.grey)
              )
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: istoric.length,
              itemBuilder: (context, index) {
                // Sparge string-ul ca să stilizăm textul
                List<String> parts = istoric[index].split(' - ');
                String numeZone = parts[0];
                String dataSiOra = parts.length > 1 ? parts[1] : "";

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.water_drop, color: Colors.white),
                    ),
                    title: Text(numeZone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(dataSiOra, style: const TextStyle(color: Colors.grey)),
                  ),
                );
              },
            ),
    );
  }
}