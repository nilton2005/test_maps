import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Properly initialize the controller
  final MapController _mapController = MapController();
  
  // Current user position
  LatLng? _currentPosition;
  
  // Selected destination
  LatLng? _selectedDestination;
  
  // Loading state
  bool _isLoading = true;
  
  // Flag to ensure map is ready before moving
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    // Delay getting location until after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied, please enable in Settings'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        
        // Only move the map if it's ready and we have a position
        if (_mapReady && _currentPosition != null) {
          _mapController.move(_currentPosition!, 15.0);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Send ride request to backend
  Future<void> _sendRideRequest() async {
    if (_currentPosition == null || _selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination')),
      );
      return;
    }

    try {
      // Replace with your actual backend URL
      final response = await http.post(
        Uri.parse('https://your-backend-url.com/api/ride-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pickupLocation': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          },
          'destinationLocation': {
            'latitude': _selectedDestination!.latitude,
            'longitude': _selectedDestination!.longitude,
          },
          'userId': 'user-id-here', // Replace with actual user ID
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride request sent successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default location (you can use a common place in your city)
    final defaultLocation = const LatLng(-12.0464, -77.0428); // Lima, Peru (as an example)
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MotoTaxi Map'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              // Map Widget
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition ?? defaultLocation,
                  initialZoom: 15.0,
                  onMapReady: () {
                    setState(() {
                      _mapReady = true;
                    });
                    // Move to current position if it's already available
                    if (_currentPosition != null) {
                      _mapController.move(_currentPosition!, 15.0);
                    }
                  },
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedDestination = point;
                    });
                  },
                ),
                children: [
                  // Tile Layer (OpenStreetMap)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.test_map_tiles',
                  ),
                  
                  // Current position marker
                  if (_currentPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                    
                  // Destination marker
                  if (_selectedDestination != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedDestination!,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.place,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              // Bottom sheet with request button
              if (_selectedDestination != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Destination Selected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${_selectedDestination!.latitude.toStringAsFixed(6)}, ' 
                          'Lng: ${_selectedDestination!.longitude.toStringAsFixed(6)}',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _sendRideRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Request Mototaxi'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null && _mapReady) {
            _mapController.move(_currentPosition!, 15.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
  
  @override
  void dispose() {
    // Not needed with newer versions of flutter_map but good practice
    super.dispose();
  }
}