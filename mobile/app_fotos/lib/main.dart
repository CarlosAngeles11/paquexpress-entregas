import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

// CAMBIA ESTA URL POR TU IP
const String API_URL = "http://localhost:8000";

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paquexpress - Sistema de Entregas',
      theme: ThemeData(
        primaryColor: const Color(0xFF1976D2),
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ==================== MODELOS ====================
class User {
  final int userId;
  final String username;
  final String fullName;
  final String role;

  User({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      username: json['username'],
      fullName: json['full_name'],
      role: json['role'],
    );
  }

  bool get isAdmin => role == 'admin';
}

class Package {
  final int packageId;
  final String trackingNumber;
  final String destinationAddress;
  final String recipientName;
  final String status;

  Package({
    required this.packageId,
    required this.trackingNumber,
    required this.destinationAddress,
    required this.recipientName,
    required this.status,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      packageId: json['package_id'],
      trackingNumber: json['tracking_number'],
      destinationAddress: json['destination_address'],
      recipientName: json['recipient_name'],
      status: json['status'],
    );
  }
}

class Delivery {
  final int deliveryId;
  final String trackingNumber;
  final String agentName;
  final double latitude;
  final double longitude;
  final String address;
  final String photoPath;
  final String deliveredAt;

  Delivery({
    required this.deliveryId,
    required this.trackingNumber,
    required this.agentName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.photoPath,
    required this.deliveredAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      deliveryId: json['delivery_id'],
      trackingNumber: json['tracking_number'],
      agentName: json['agent_name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      address: json['address'],
      photoPath: json['photo_path'],
      deliveredAt: json['delivered_at'],
    );
  }
}

// ==================== LOGIN PAGE ====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Por favor completa todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      var response = await http.post(
        Uri.parse("$API_URL/login"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": _usernameController.text,
          "password": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        User user = User.fromJson(data);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(user: user),
          ),
        );
      } else {
        _showError("Credenciales inválidas");
      }
    } catch (e) {
      _showError("Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[700]!, Colors.blue[300]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping, size: 80, color: Color(0xFF1976D2)),
                    const SizedBox(height: 16),
                    const Text(
                      "PAQUEXPRESS",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const Text("Sistema de Entregas"),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: "Usuario",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Contraseña",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Iniciar Sesión", style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== HOME PAGE ====================
class HomePage extends StatelessWidget {
  final User user;

  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hola, ${user.fullName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuCard(
              context,
              "Paquetes Pendientes",
              Icons.inventory_2,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PendingPackagesPage(user: user),
                ),
              ),
            ),
            _buildMenuCard(
              context,
              "Mis Entregas",
              Icons.history,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeliveriesHistoryPage(user: user),
                ),
              ),
            ),
            if (user.isAdmin) ...[
              _buildMenuCard(
                context,
                "Gestionar Paquetes",
                Icons.add_box,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagePackagesPage(user: user),
                  ),
                ),
              ),
              _buildMenuCard(
                context,  
                "Todas las Entregas",
                Icons.admin_panel_settings,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllDeliveriesPage(user: user),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MANAGE PACKAGES PAGE (ADMIN) ====================
class ManagePackagesPage extends StatefulWidget {
  final User user;

  const ManagePackagesPage({super.key, required this.user});

  @override
  State<ManagePackagesPage> createState() => _ManagePackagesPageState();
}

class _ManagePackagesPageState extends State<ManagePackagesPage> {
  List<Package> packages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      var response = await http.get(
        Uri.parse("$API_URL/packages/all?requesting_user_id=${widget.user.userId}"),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          packages = data.map((e) => Package.fromJson(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _deletePackage(int packageId) async {
    try {
      var response = await http.delete(
        Uri.parse("$API_URL/packages/$packageId?requesting_user_id=${widget.user.userId}"),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paquete eliminado ✅")),
        );
        _loadPackages();
      } else {
        var data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? "Error al eliminar")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showDeleteDialog(Package package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: Text("¿Eliminar el paquete ${package.trackingNumber}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePackage(package.packageId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Paquetes"),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : packages.isEmpty
              ? const Center(child: Text("No hay paquetes"))
              : ListView.builder(
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final pkg = packages[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: pkg.status == "pending"
                              ? Colors.orange
                              : Colors.green,
                          child: Icon(
                            pkg.status == "pending"
                                ? Icons.pending
                                : Icons.check_circle,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(pkg.trackingNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Para: ${pkg.recipientName}"),
                            Text("Estado: ${pkg.status == "pending" ? "Pendiente" : "Entregado"}"),
                          ],
                        ),
                        trailing: pkg.status == "pending"
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteDialog(pkg),
                              )
                            : null,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePackagePage(user: widget.user),
            ),
          ).then((_) => _loadPackages());
        },
        icon: const Icon(Icons.add),
        label: const Text("Nuevo Paquete"),
      ),
    );
  }
}

// ==================== CREATE PACKAGE PAGE ====================
class CreatePackagePage extends StatefulWidget {
  final User user;

  const CreatePackagePage({super.key, required this.user});

  @override
  State<CreatePackagePage> createState() => _CreatePackagePageState();
}

class _CreatePackagePageState extends State<CreatePackagePage> {
  final trackingController = TextEditingController();
  final addressController = TextEditingController();
  final recipientController = TextEditingController();
  bool isLoading = false;

  Future<void> _createPackage() async {
    if (trackingController.text.isEmpty ||
        addressController.text.isEmpty ||
        recipientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor completa todos los campos")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var response = await http.post(
        Uri.parse("$API_URL/packages?requesting_user_id=${widget.user.userId}"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tracking_number": trackingController.text,
          "destination_address": addressController.text,
          "recipient_name": recipientController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Paquete creado exitosamente ✅"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        var data = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? "Error al crear paquete"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear Nuevo Paquete")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: trackingController,
              decoration: const InputDecoration(
                labelText: "Número de Rastreo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
                hintText: "Ej: PKG-001-2025",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: recipientController,
              decoration: const InputDecoration(
                labelText: "Nombre del Destinatario",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: "Ej: Juan Pérez",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: "Dirección de Entrega",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: "Ej: Av. Constituyentes 123, Querétaro",
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("CREAR PAQUETE", style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: isLoading ? null : _createPackage,
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== PENDING PACKAGES PAGE ====================
class PendingPackagesPage extends StatefulWidget {
  final User user;

  const PendingPackagesPage({super.key, required this.user});

  @override
  State<PendingPackagesPage> createState() => _PendingPackagesPageState();
}

class _PendingPackagesPageState extends State<PendingPackagesPage> {
  List<Package> packages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      var response = await http.get(Uri.parse("$API_URL/packages/pending"));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          packages = data.map((e) => Package.fromJson(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paquetes Pendientes")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : packages.isEmpty
              ? const Center(child: Text("No hay paquetes pendientes"))
              : ListView.builder(
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final pkg = packages[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2),
                        ),
                        title: Text(pkg.trackingNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Para: ${pkg.recipientName}"),
                            Text("Dirección: ${pkg.destinationAddress}",
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeliveryPage(
                                  user: widget.user,
                                  package: pkg,
                                ),
                              ),
                            );
                          },
                          child: const Text("Entregar"),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== DELIVERY PAGE ====================
class DeliveryPage extends StatefulWidget {
  final User user;
  final Package package;

  const DeliveryPage({super.key, required this.user, required this.package});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  Uint8List? _imageBytes;
  XFile? _pickedFile;
  final picker = ImagePicker();
  final notesController = TextEditingController();
  bool isLoading = false;
  double? latitude;
  double? longitude;

  Future<void> _takePhoto() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _pickedFile = pickedFile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foto tomada correctamente ✅")),
      );
    }
  }

  Future<void> _registerDelivery() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primero toma una foto ❗")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position pos = await Geolocator.getCurrentPosition();
      latitude = pos.latitude;
      longitude = pos.longitude;

      var request = http.MultipartRequest('POST', Uri.parse("$API_URL/deliveries"));
      request.fields['package_id'] = widget.package.packageId.toString();
      request.fields['agent_id'] = widget.user.userId.toString();
      request.fields['latitude'] = pos.latitude.toString();
      request.fields['longitude'] = pos.longitude.toString();
      request.fields['notes'] = notesController.text;
      request.files.add(
        http.MultipartFile.fromBytes('file', _imageBytes!, filename: _pickedFile!.name),
      );

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Entrega registrada exitosamente ✅"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $respStr"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Entrega")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Paquete: ${widget.package.trackingNumber}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text("Destinatario: ${widget.package.recipientName}"),
                    Text("Dirección: ${widget.package.destinationAddress}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_imageBytes != null)
              Image.memory(_imageBytes!, height: 200)
            else
              Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(child: Text("No hay foto")),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Tomar Foto"),
              onPressed: _takePhoto,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: "Notas (opcional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text("PAQUETE ENTREGADO", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: isLoading ? null : _registerDelivery,
            ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

// ==================== DELIVERIES HISTORY PAGE ====================
class DeliveriesHistoryPage extends StatefulWidget {
  final User user;

  const DeliveriesHistoryPage({super.key, required this.user});

  @override
  State<DeliveriesHistoryPage> createState() => _DeliveriesHistoryPageState();
}

class _DeliveriesHistoryPageState extends State<DeliveriesHistoryPage> {
  List<Delivery> deliveries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    try {
      var response = await http.get(
        Uri.parse("$API_URL/deliveries/agent/${widget.user.userId}"),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          deliveries = data.map((e) => Delivery.fromJson(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Entregas")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : deliveries.isEmpty
              ? const Center(child: Text("No hay entregas registradas"))
              : ListView.builder(
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final d = deliveries[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(d.trackingNumber),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.address),
                            Text(DateTime.parse(d.deliveredAt).toLocal().toString()),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeliveryDetailPage(delivery: d),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== ALL DELIVERIES PAGE (ADMIN) ====================
class AllDeliveriesPage extends StatefulWidget {
  final User user;

  const AllDeliveriesPage({super.key, required this.user});

  @override
  State<AllDeliveriesPage> createState() => _AllDeliveriesPageState();
}

class _AllDeliveriesPageState extends State<AllDeliveriesPage> {
  List<Delivery> deliveries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    try {
      var response = await http.get(
        Uri.parse("$API_URL/deliveries/all?requesting_user_id=${widget.user.userId}"),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          deliveries = data.map((e) => Delivery.fromJson(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Todas las Entregas"),
        backgroundColor: Colors.purple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : deliveries.isEmpty
              ? const Center(child: Text("No hay entregas"))
              : ListView.builder(
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final d = deliveries[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(d.agentName[0])),
                        title: Text(d.trackingNumber),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Agente: ${d.agentName}"),
                            Text(d.address),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeliveryDetailPage(delivery: d),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== DELIVERY DETAIL PAGE (con mapa y foto) ====================
class DeliveryDetailPage extends StatelessWidget {
  final Delivery delivery;

  const DeliveryDetailPage({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(delivery.trackingNumber)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(delivery.latitude, delivery.longitude),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.paquexpress.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(delivery.latitude, delivery.longitude),
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.location_on, size: 50, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Dirección:", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(delivery.address),
                  const SizedBox(height: 16),
                  Text("Evidencia fotográfica:", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Image.network(
                    "$API_URL/${delivery.photoPath}",
                    errorBuilder: (context, error, stackTrace) =>
                        const Text("Error al cargar imagen"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}