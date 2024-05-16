import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main(List<String> args) {
  runApp(MaterialApp(
    home: Home(),
  ));
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController _cepController = TextEditingController();
  TextEditingController _logradouroController = TextEditingController();
  TextEditingController _complementoController = TextEditingController();
  TextEditingController _bairroController = TextEditingController();
  TextEditingController _localidadeController = TextEditingController();
  TextEditingController _ufController = TextEditingController();
  TextEditingController _ibgeController = TextEditingController();
  TextEditingController _dddController = TextEditingController();

  FocusNode _cepFocusNode = FocusNode();
  LatLng _latLng = LatLng(0, 0); // Inicialize com um valor padrão
  final MapController _mapController = MapController();
  String _enderecoCompleto = '';

  @override
  void initState() {
    super.initState();
    _cepFocusNode.addListener(() {
      if (!_cepFocusNode.hasFocus) {
        _buscarCep();
      }
    });
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _cepFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Serviço de localização desativado. Por favor, ative o serviço.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Permissão de localização negada.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Permissão de localização negada permanentemente. Não podemos solicitar permissões.')));
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _latLng = LatLng(position.latitude, position.longitude);
      _mapController.move(_latLng, 15.0);
    });
  }

  void _buscarCep() async {
    String cep = _cepController.text;

    String _url = "https://viacep.com.br/ws/$cep/json/";
    var _urlCall = Uri.parse(_url);

    try {
      http.Response resposta = await http.get(_urlCall);

      if (resposta.statusCode == 200) {
        Map<String, dynamic> dadosCep = json.decode(resposta.body);

        setState(() {
          _logradouroController.text = dadosCep['logradouro'] ?? '';
          _complementoController.text = dadosCep['complemento'] ?? '';
          _bairroController.text = dadosCep['bairro'] ?? '';
          _localidadeController.text = dadosCep['localidade'] ?? '';
          _ufController.text = dadosCep['uf'] ?? '';
          _ibgeController.text = dadosCep['ibge'] ?? '';
          _dddController.text = dadosCep['ddd'] ?? '';

          _enderecoCompleto =
              '${dadosCep['logradouro'] ?? ''}, ${dadosCep['bairro'] ?? ''}, ${dadosCep['localidade'] ?? ''}, ${dadosCep['uf'] ?? ''}';

          // Atualiza a localização no mapa usando a API do OpenStreetMap Nominatim
          _buscarCoordenadas(dadosCep['logradouro'], dadosCep['localidade'],
              dadosCep['bairro'], dadosCep['uf']);
        });
      } else {
        setState(() {
          _logradouroController.text = '';
          _complementoController.text = '';
          _bairroController.text = '';
          _localidadeController.text = '';
          _ufController.text = '';
          _ibgeController.text = '';
          _dddController.text = '';
          _latLng = LatLng(0, 0); // Coordenadas do centro de São Paulo
          _enderecoCompleto = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cep informado incorretamente ou não encontrado.')));
      }
    } catch (e) {
      setState(() {
        _logradouroController.text = '';
        _complementoController.text = '';
        _bairroController.text = '';
        _localidadeController.text = '';
        _ufController.text = '';
        _ibgeController.text = '';
        _dddController.text = '';
        _latLng = LatLng(0, 0); // Coordenadas do centro de São Paulo
        _enderecoCompleto = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao buscar o CEP. Por favor, tente novamente.')));
    }
  }

  void _buscarCoordenadas(String? logradouro, String? localidade,
      String? bairro, String? uf) async {
    if (logradouro != null &&
        localidade != null &&
        bairro != null &&
        uf != null) {
      String endereco = '$logradouro, $bairro, $localidade, $uf, Brasil';
      String _url =
          'https://nominatim.openstreetmap.org/search?q=$endereco&format=json&addressdetails=1';

      var _urlCall = Uri.parse(_url);
      http.Response resposta = await http.get(_urlCall);

      if (resposta.statusCode == 200) {
        List<dynamic> dadosGeocode = json.decode(resposta.body);
        if (dadosGeocode.isNotEmpty) {
          var location = dadosGeocode[0];
          setState(() {
            _latLng = LatLng(
                double.parse(location['lat']), double.parse(location['lon']));
            _mapController.move(_latLng, 15.0);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _latLng,
              zoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: _latLng,
                    builder: (ctx) => Container(
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 40.0,
            left: 15.0,
            right: 15.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.location_pin, color: Colors.black),
                    SizedBox(width: 10.0),
                    Expanded(
                      child: TextField(
                        controller: _cepController,
                        focusNode: _cepFocusNode,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Digite o cep para pesquisar a localização',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: _buscarCep,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_enderecoCompleto.isNotEmpty)
            Positioned(
              bottom: 40.0,
              left: 15.0,
              right: 15.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16.0),
                child: Text(
                  _enderecoCompleto,
                  style: TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
