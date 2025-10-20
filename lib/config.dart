// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toml/toml.dart';

class KuksaConfig {
  final String hostname;
  final int port;
  final String authorizationFile;
  final String authorization;
  final bool useTls;
  final String caCertificateFile;
  final String readCaCertificateFile;
  final List<int> caCertificate;
  final String tlsServerName;

  static String globalConfigFilePath = '/etc/xdg/AGL/kuksa.toml';
  static String appConfigFilePath =
      '/etc/xdg/AGL/flutter-cluster-dashboard/kuksa.toml';
  static String defaultHostname = 'localhost';
  static int defaultPort = 55555;
  static String defaultCaCertPath = '/etc/kuksa-val/CA.pem';

  KuksaConfig(
      {required this.hostname,
      required this.port,
      required this.authorizationFile,
      required this.authorization,
      required this.useTls,
      required this.caCertificateFile,
      required this.readCaCertificateFile,
      required this.caCertificate,
      required this.tlsServerName});

  static KuksaConfig defaultConfig() {
    return KuksaConfig(
        hostname: KuksaConfig.defaultHostname,
        port: KuksaConfig.defaultPort,
        authorizationFile: "",
        authorization: "",
        useTls: false,
        caCertificateFile: KuksaConfig.defaultCaCertPath,
        readCaCertificateFile: "",
        caCertificate: [],
        tlsServerName: "");
  }
}

KuksaConfig readKuksaConfig(String configFilePath, KuksaConfig defaultConfig) {
  try {
    print("Reading KUKSA configuration ${configFilePath}");
    final configFile = File(configFilePath);
    String content = configFile.readAsStringSync();
    final configMap = TomlDocument.parse(content).toMap();

    String hostname = defaultConfig.hostname;
    if (configMap.containsKey('hostname')) {
      hostname = configMap['hostname'];
    }

    int port = defaultConfig.port;
    if (configMap.containsKey('port')) {
      port = configMap['port'];
    }

    String tokenFile = defaultConfig.authorizationFile;
    String token = defaultConfig.authorization;
    if (configMap.containsKey('authorization')) {
      String s = configMap['authorization'];
      if (s.isNotEmpty) {
        if (s.startsWith("/")) {
          tokenFile = s;
          debugPrint("Reading authorization token $tokenFile");
          try {
            token = File(tokenFile).readAsStringSync();
          } on Exception catch (_) {
            print("ERROR: Could not read authorization token file $tokenFile");
            token = "";
          }
        } else {
          token = s;
        }
      }
    }
    //debugPrint("authorization file = $tokenFile");
    //debugPrint("authorization = $token");

    bool useTls = defaultConfig.useTls;
    if (configMap.containsKey('use-tls')) {
      var value = configMap['use-tls'];
      if (value is bool) useTls = value;
    }
    //debugPrint("Use TLS = $useTls");

    String caCertFile = defaultConfig.caCertificateFile;
    String readCaCertFile = defaultConfig.readCaCertificateFile;
    List<int> caCert = defaultConfig.caCertificate;
    if (configMap.containsKey('ca-certificate')) {
      caCertFile = configMap['ca-certificate'];
    }
    if (caCertFile.isNotEmpty && caCertFile != readCaCertFile) {
      try {
        caCert = File(caCertFile).readAsBytesSync();
      } on Exception catch (_) {
        print("ERROR: Could not read CA certificate file $caCertFile");
        caCert = [];
      }
      readCaCertFile = caCertFile;
    }
    //debugPrint("CA cert file = $caCertFile");
    //debugPrint("CA cert = $caCert");

    String tlsServerName = defaultConfig.tlsServerName;
    if (configMap.containsKey('tls-server-name')) {
      tlsServerName = configMap['tls-server-name'];
    }

    return KuksaConfig(
        hostname: hostname,
        port: port,
        authorizationFile: tokenFile,
        authorization: token,
        useTls: useTls,
        caCertificateFile: caCertFile,
        readCaCertificateFile: readCaCertFile,
        caCertificate: caCert,
        tlsServerName: tlsServerName);
  } on Exception catch (_) {
    return defaultConfig;
  }
}

// NOTE: This may need to be changed to a FutureProvider to avoid slowing
//       down the top-level widget initState...

final kuksaConfigProvider = Provider((ref) {
  final KuksaConfig defaultConfig = KuksaConfig.defaultConfig();
  try {
    final Map<String, String> envVars = Platform.environment;
    final configHome = envVars['XDG_CONFIG_HOME'];

    // Read global configuration
    var configFilePath = KuksaConfig.globalConfigFilePath;
    if (configHome != null) {
      configFilePath = configHome + "/AGL/kuksa.toml";
    }
    var config = defaultConfig;
    config = readKuksaConfig(configFilePath, config);

    // Read app-specific configuration
    configFilePath = KuksaConfig.appConfigFilePath;
    if (configHome != null) {
      configFilePath = configHome + "/AGL/flutter-cluster-dashboard/kuksa.toml";
    }
    config = readKuksaConfig(configFilePath, config);
    return config;
  } on Exception catch (_) {
    return defaultConfig;
  }
});
