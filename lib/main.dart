import 'package:flutter/material.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('scan_results');
  runApp(PortScannerApp());
}

class PortScannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Port Scanner',
      debugShowCheckedModeBanner: false,
      home: PortScannerScreen(),
    );
  }
}

class PortScannerScreen extends StatefulWidget {
  @override
  _PortScannerScreenState createState() => _PortScannerScreenState();
}

class _PortScannerScreenState extends State<PortScannerScreen> {
  final _hostController = TextEditingController();
  final _customPortsController = TextEditingController();
  List<int> _openPorts = [];
  bool _isScanning = false;

  final List<int> _popularPorts = [21, 22, 23, 25, 53, 80, 110, 443, 445, 993, 995, 3306, 3389, 8080, 10050];
  final Set<int> _selectedPorts = {};

  void togglePortSelection(int port) {
    setState(() {
      if (_selectedPorts.contains(port)) {
        _selectedPorts.remove(port);
      } else {
        _selectedPorts.add(port);
      }
    });
  }

  Future<void> scanPorts(String host, List<int> ports) async {
    final box = Hive.box('scan_results');
    final result = {'host': host, 'ports': ports};

    // Save the result
    box.add(result);

    // Keep only the last 10 results
    while (box.length > 10) {
      box.deleteAt(0);
    }

    setState(() {
      _openPorts.clear();
      _isScanning = true;
    });

    for (int port in ports) {
      try {
        final socket = await Socket.connect(host, port, timeout: Duration(milliseconds: 500));
        socket.destroy();
        setState(() {
          _openPorts.add(port);
        });
      } catch (_) {
        // Port is closed or not reachable
      }
    }

    setState(() {
      _isScanning = false;
    });
  }

  void clearResults() {
    final box = Hive.box('scan_results');
    box.clear();
    setState(() {});
  }

  void clearHostField() {
    _hostController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Port Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(labelText: 'Host (IP or Domain)'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: clearHostField,
                ),
              ],
            ),
            SizedBox(height: 16.0),
            Text('Popular Ports:'),
            Wrap(
              spacing: 8.0,
              children: _popularPorts.map((port) {
                return ChoiceChip(
                  label: Text(port.toString()),
                  selected: _selectedPorts.contains(port),
                  onSelected: (_) => togglePortSelection(port),
                );
              }).toList(),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _customPortsController,
              decoration: InputDecoration(labelText: 'Custom Ports (comma-separated)'),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: clearResults,
                  icon: Icon(Icons.delete),
                  label: Text('Clear All Results'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100], // Optional: change button color
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    disabledBackgroundColor: Colors.yellow[100],
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _isScanning
                      ? null
                      : () {
                    final host = _hostController.text;
                    final customPorts = _customPortsController.text
                        .split(',')
                        .map((port) => int.tryParse(port.trim()))
                        .where((port) => port != null)
                        .cast<int>()
                        .toList();
                    final ports = [..._selectedPorts, ...customPorts];

                    if (host.isNotEmpty && ports.isNotEmpty) {
                      scanPorts(host, ports);
                    }
                  },
                  child: Text(_isScanning ? 'Scanning...' : 'Scan Ports'),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box('scan_results').listenable(),
                builder: (context, Box box, _) {
                  final results = box.values.toList().reversed.take(10).toList();

                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text('Host: ${result['host']}'),
                          subtitle: Text('Ports: ${result['ports'].join(', ')}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
