enum DataSourceType { network, file, asset }

String DataSource({dynamic file, DataSourceType type, String source}) {
  return source;
}
