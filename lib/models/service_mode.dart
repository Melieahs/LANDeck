/// The two ways an existing service can be presented.
///
/// A service is always a Web service unless the user explicitly links an
/// installed native module to it. The mode is a presentation preference; it
/// never creates a second service record.
enum ServiceMode { web, native }

extension ServiceModeLabels on ServiceMode {
  String get label => switch (this) {
    ServiceMode.web => 'Web',
    ServiceMode.native => '原生',
  };
}
