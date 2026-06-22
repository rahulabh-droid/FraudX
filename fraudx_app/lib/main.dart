import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const FraudXApp());
}

class FraudXApp extends StatelessWidget {
  const FraudXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FraudX',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const FraudScreen(),
    );
  }
}

class FraudScreen extends StatefulWidget {
  const FraudScreen({super.key});

  @override
  State<FraudScreen> createState() => _FraudScreenState();
}

class _FraudScreenState extends State<FraudScreen> {
  final transactionController = TextEditingController();
  final senderController = TextEditingController();
  final receiverController = TextEditingController();
  final amountController = TextEditingController();

  String senderCountry = "India";
  String receiverCountry = "USA";
  String paymentMethod = "UPI";

  bool vpnUsage = false;
  bool ipChange = false;
  bool newDevice = false;
  bool newLocation = false;

  bool loading = false;

  double fraudScore = 0.0;
  double confidence = 0.0;
  double processingTime = 0.0;

  bool isSuspicious = false;

  String result = "";
  List<dynamic> riskFactors = [];

  int totalScans = 0;
  int fraudCount = 0;
  int safeCount = 0;

  List<double> scoreHistory = [];

  List<Map<String, dynamic>> transactionHistory = [];
  int csvTotal = 0;
  int csvFraud = 0;
  int csvSafe = 0;
  double csvFraudRate = 0;
  Future<void> pickCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.fraudx.tech/api/v1/upload-csv"),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', result.files.single.path!),
      );

      var response = await request.send();

      var responseData = await response.stream.bytesToString();

      final data = jsonDecode(responseData);

      setState(() {
        csvTotal = data["total_transactions"] ?? 0;
        csvFraud = data["suspicious_transactions"] ?? 0;
        csvSafe = data["safe_transactions"] ?? 0;
        csvFraudRate = (data["fraud_rate"] ?? 0).toDouble();
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> detectFraud() async {
    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse("https://api.fraudx.tech/api/v1/detect-fraud"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "transaction_id": transactionController.text,
          "amount": double.tryParse(amountController.text) ?? 0,
          "sender_id": senderController.text,
          "receiver_id": receiverController.text,
          "sender_country": senderCountry,
          "receiver_country": receiverCountry,
          "payment_method": paymentMethod,
          "vpn_usage": vpnUsage,
          "ip_address_change": ipChange,
          "is_new_device": newDevice,
          "is_new_location": newLocation,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      final data = jsonDecode(response.body);

      setState(() {
        fraudScore = (data["fraud_score"] ?? 0).toDouble();
        isSuspicious = data["is_suspicious"] ?? false;
        confidence = (data["confidence"] ?? 0).toDouble();
        processingTime = (data["processing_time"] ?? 0).toDouble();
        riskFactors = data["risk_factors"] ?? [];

        result = isSuspicious
            ? "🚨 Suspicious Transaction"
            : "✅ Safe Transaction";
        totalScans++;

        if (isSuspicious) {
          fraudCount++;
        } else {
          safeCount++;
        }

        scoreHistory.add(fraudScore * 100);

        if (scoreHistory.length > 10) {
          scoreHistory.removeAt(0);
        }

        transactionHistory.insert(0, {
          "id": transactionController.text,
          "score": (fraudScore * 100).toStringAsFixed(1),
          "status": isSuspicious ? "FRAUD" : "SAFE",
        });
      });
    } catch (e) {
      setState(() {
        result = "❌ Error: $e";
      });
    }

    setState(() => loading = false);
  }

  String get riskLevel {
    if (fraudScore < 0.3) return "LOW";
    if (fraudScore < 0.7) return "MEDIUM";
    return "HIGH";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FraudX 🛡️", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("AI Fraud Detection", style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: transactionController,
              decoration: const InputDecoration(
                labelText: "Transaction ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: senderController,
              decoration: const InputDecoration(
                labelText: "Sender ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: receiverController,
              decoration: const InputDecoration(
                labelText: "Receiver ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: senderCountry,
              decoration: const InputDecoration(
                labelText: "Sender Country",
                border: OutlineInputBorder(),
              ),
              items: [
                "India",
                "USA",
                "UK",
                "UAE",
                "Canada",
                "Australia",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => senderCountry = v!),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: receiverCountry,
              decoration: const InputDecoration(
                labelText: "Receiver Country",
                border: OutlineInputBorder(),
              ),
              items: [
                "India",
                "USA",
                "UK",
                "UAE",
                "Canada",
                "Australia",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => receiverCountry = v!),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: paymentMethod,
              decoration: const InputDecoration(
                labelText: "Payment Method",
                border: OutlineInputBorder(),
              ),
              items: [
                "UPI",
                "Credit Card",
                "Debit Card",
                "Wallet",
                "Bank Transfer",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => paymentMethod = v!),
            ),

            SwitchListTile(
              title: const Text("VPN Usage"),
              value: vpnUsage,
              onChanged: (v) => setState(() => vpnUsage = v),
            ),
            SwitchListTile(
              title: const Text("IP Address Changed"),
              value: ipChange,
              onChanged: (v) => setState(() => ipChange = v),
            ),
            SwitchListTile(
              title: const Text("New Device"),
              value: newDevice,
              onChanged: (v) => setState(() => newDevice = v),
            ),
            SwitchListTile(
              title: const Text("New Location"),
              value: newLocation,
              onChanged: (v) => setState(() => newLocation = v),
            ),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : detectFraud,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Detect Fraud"),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: pickCSV,
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload CSV"),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [Text("$totalScans"), const Text("Scans")],
                    ),
                    Column(
                      children: [Text("$fraudCount"), const Text("Frauds")],
                    ),
                    Column(children: [Text("$safeCount"), const Text("Safe")]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (result.isNotEmpty)
              Card(
                color: fraudScore > 0.7
                    ? Colors.red.shade900
                    : fraudScore > 0.3
                    ? Colors.orange.shade900
                    : Colors.green.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        result,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CircularPercentIndicator(
                        radius: 80,
                        lineWidth: 12,
                        animation: true,
                        percent: fraudScore.clamp(0.0, 1.0),
                        circularStrokeCap: CircularStrokeCap.round,
                        progressColor: fraudScore > 0.7
                            ? Colors.red
                            : fraudScore > 0.3
                            ? Colors.orange
                            : Colors.green,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${(fraudScore * 100).toStringAsFixed(1)}%",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(riskLevel),
                          ],
                        ),
                      ),
                      Text("Risk Level: $riskLevel"),
                      Text(
                        "Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
                      ),
                      Text(
                        "Processing Time: ${processingTime.toStringAsFixed(2)} sec",
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        "Risk Trend",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: 100,

                            gridData: FlGridData(show: true),

                            borderData: FlBorderData(show: false),

                            titlesData: FlTitlesData(show: false),

                            lineBarsData: [
                              LineChartBarData(
                                isCurved: true,
                                color: Colors.cyan,
                                barWidth: 4,
                                dotData: FlDotData(show: true),

                                spots: List.generate(
                                  scoreHistory.length,
                                  (i) => FlSpot(i.toDouble(), scoreHistory[i]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Risk Factors",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...riskFactors.map(
                        (e) => Padding(
                          padding: const EdgeInsets.all(2),
                          child: Text("• $e"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (csvTotal > 0)
              Card(
                color: Colors.blueGrey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "CSV ANALYSIS",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text("Total Transactions: $csvTotal"),
                      Text("Suspicious: $csvFraud"),
                      Text("Safe: $csvSafe"),

                      Text("Fraud Rate: ${csvFraudRate.toStringAsFixed(2)}%"),
                    ],
                  ),
                ),
              ),

            const Text(
              "Recent Transactions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            ...transactionHistory.map(
              (txn) => Card(
                child: ListTile(
                  leading: Icon(
                    txn["status"] == "FRAUD"
                        ? Icons.warning
                        : Icons.check_circle,
                  ),
                  title: Text(txn["id"]),
                  subtitle: Text("Risk: ${txn["score"]}%"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: txn["status"] == "FRAUD"
                          ? Colors.red
                          : Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(txn["status"]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
